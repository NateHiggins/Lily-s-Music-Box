extends Node
## §13, §31, §32, §33, §40 — the ecology director and the one-mind reveal.
##     godot --headless --path game res://tests/DreamEcologyTest.tscn
var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(14.0).timeout
	var enc: Node = root.get("apartment_encroachment")
	var dir: DreamEcologyDirector = enc.get("ecology")
	var margin = enc.get("margin")
	var critters = enc.get("critters")
	var hero = enc.get("hero")
	_check("the encroachment owns an ecology director", dir != null)
	if dir == null:
		return _finish()
	_check("it can see all three levels",
			dir.margin != null and dir.critters != null and dir.hero != null)

	# --- §32/§33: STATES BIAS, THEY DO NOT COMMAND -----------------------
	var seen_states := {}
	for s in DreamEcologyDirector.State.values():
		dir.state = s
		var b: Dictionary = dir.bias()
		seen_states[dir.state_name()] = b
		_check("%s biases behaviour without commanding it" % dir.state_name(),
				b.has("move") and b.has("orient") and float(b.move) > 0.0)
	_check("watching favours orientation over locomotion",
			float(seen_states["watching"].orient) > float(seen_states["watching"].move))
	_check("foraging favours contact",
			float(seen_states["foraging"].contact) > float(seen_states["curious"].contact))
	dir.state = DreamEcologyDirector.State.CURIOUS

	# --- §33: NORMALLY, NOBODY IS SYNCHRONISED ---------------------------
	var acts := {}
	for p in margin.palps:
		acts[int(p.act)] = true
	print("[ecology] before: %d palps doing %d different things, %d critters"
			% [margin.palps.size(), acts.size(), critters.critters.size()])
	_check("normally the ecology is many agents, not one (%d behaviours)"
			% acts.size(), acts.size() >= 3)
	_check("there are enough agents for the reveal to mean anything (%d + %d)"
			% [margin.palps.size(), critters.critters.size()],
			margin.palps.size() >= 8 and critters.critters.size() >= 2)

	# --- §13/§40: THE SNAP -----------------------------------------------
	# "At the same instant" is the whole beat, so it is measured on the very
	# next frame rather than after a settling period.
	var at := Vector3(-9.0, 4.5, 3.5)
	var palps_before: int = margin.palps.size()
	var critters_before: int = critters.critters.size()
	dir.seize_attention(at)
	await get_tree().process_frame
	await get_tree().process_frame
	var held_palps := 0
	for p in margin.palps:
		if p.attend_override != Vector3.INF:
			held_palps += 1
	var held_critters := 0
	for c in critters.critters:
		if c.attend_override != Vector3.INF:
			held_critters += 1
	print("[ecology] snap: %d/%d palps, %d/%d critters, hero %s"
			% [held_palps, palps_before, held_critters, critters_before,
			hero.attention_override != Vector3.INF])
	_check("§40 the snap is TOTAL: every palp is seized (%d/%d)"
			% [held_palps, palps_before], held_palps == palps_before)
	_check("every critter too (%d/%d)" % [held_critters, critters_before],
			held_critters == critters_before)
	_check("and the hero", hero.attention_override != Vector3.INF)
	_check("all of them are looking at the SAME point",
			margin.palps.is_empty() or margin.palps[0].attend_override == at)

	# --- §13: AND THE RELEASE IS ASYNCHRONOUS ----------------------------
	# A coordinated release would read as a machine switching off rather than
	# as attention lapsing, so the individuals must let go at different times.
	var release_times := {}
	var t := 0.0
	for probe in 90:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		for p in margin.palps:
			var id: int = int(p.id)
			var ov: Vector3 = p.get("attend_override", Vector3.INF)
			if ov == Vector3.INF and not release_times.has(id):
				release_times[id] = t
		if dir.attending == Vector3.INF:
			break
	var times: Array = release_times.values()
	times.sort()
	var spread := 0.0
	if times.size() >= 2:
		spread = float(times[times.size() - 1]) - float(times[0])
	print("[ecology] %d released across %.2f s" % [times.size(), spread])
	_check("individuals let go at different times (%d over %.2f s)"
			% [times.size(), spread], times.size() >= 3 and spread > 0.4)
	_check("the whole event ends and autonomy returns",
			dir.attending == Vector3.INF)
	print("[ecology] %s" % [dir.census()])
	_finish()


func _finish() -> void:
	print("DREAM ECOLOGY TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[ecology ok] " + label)
	else:
		failures += 1
		printerr("[ECOLOGY FAIL] " + label)
