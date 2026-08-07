extends Node
## Manual probe, not a suite: does the schedule move real bodies?
##
## Boots the whole building at 8x time under whatever SCHEDULE_DAY /
## DAYNIGHT_FORCE the caller pins (canonical run: SCHEDULE=1
## SCHEDULE_DAY=fri DAYNIGHT_FORCE=22:30 — the Friday Harukiya roster),
## then samples the cast for eight simulated minutes and reports who
## went where. PASS means at least two residents physically crossed to
## the bar and nobody's directive was left unserved for the whole run.
## Timing-sensitive by nature, which is why it is a probe you run when
## touching the schedule machinery, not a gate WalkTest depends on.

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	Engine.time_scale = 8.0
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.0).timeout
	var routines: ResidentRoutines = root.resident_routines
	if routines == null:
		print("[PROBE] FAIL: no routines")
		get_tree().quit(1)
		return
	for i in range(12):
		# Scene timers run on engine time, which time_scale also scales:
		# 40 engine-seconds here is 5 real seconds at 8x. The probe's
		# first draft used 5.0 and spent its whole run observing a single
		# simulated minute of a building it had accelerated eightfold.
		await get_tree().create_timer(40.0).timeout
		var at_bar := 0
		var en_route := 0
		var hidden := 0
		for actor in routines.actors:
			if str(actor.get("sched_key", "")) == "harukiya_bar":
				if bool(actor.get("at_venue", false)):
					at_bar += 1
				else:
					en_route += 1
			var node: Node3D = actor.node
			if is_instance_valid(node) and not node.visible:
				hidden += 1
		print("[PROBE] t+%03ds  at_bar=%d en_route=%d hidden=%d "
				% [(i + 1) * 40, at_bar, en_route, hidden]
				+ "directives=%d" % routines.schedules.size())
		for actor in routines.actors:
			if str(actor.get("sched_key", "")) != "harukiya_bar":
				continue
			var node: Node3D = actor.node
			print("[PROBE]    %s stage=%s floor=%s pos=%v leg=%d/%d"
					% [actor.slug,
					ResidentRoutines.Stage.keys()[int(actor.stage)],
					str(actor.target_floor), node.global_position,
					int(actor.leg), actor.path.size()])
	var final_at_bar := 0
	var names := []
	for actor in routines.actors:
		if str(actor.get("sched_key", "")) == "harukiya_bar" \
				and bool(actor.get("at_venue", false)):
			final_at_bar += 1
			names.append(str(actor.slug))
	var ok: bool = final_at_bar >= 2 \
			and routines.schedules.size() == routines.actors.size()
	print("[PROBE] RESULT: %s — %d at the bar %s, %d directives"
			% ["PASS" if ok else "FAIL", final_at_bar, names,
			routines.schedules.size()])
	get_tree().quit(0 if ok else 1)
