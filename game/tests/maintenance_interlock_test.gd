extends Node
## SR7-B — the passenger-elevator landing-door interlock.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/MaintenanceInterlockTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things are proved here and kept apart on purpose:
##
##   the BOOK   the authored activity satisfies the shared schema, teaches one
##              transferable verb and stays inside the 3-12 second window;
##   the RUN    the shared run enforces the order, names the three real
##              mistakes and recovers without restarting;
##   the LOCK   closed is not locked, a bridge counterfeits continuity without
##              creating safety, preview publishes nothing, and no data file
##              can talk the mechanism into calling itself proved.
##
## The production placement and the lift seam are proved separately in
## `maintenance_interlock_live_test.gd`.

const ACTIVITY := "elevator_interlock_proof"
const ORDER := ["gauge_keeper", "pull_jumper", "true_keeper", "bring_home",
		"prove_refusal"]

var checks := 0
var failures := 0


func _ready() -> void:
	_book()
	_run()
	_lock()
	_finish()


# --- the book ---------------------------------------------------------------

func _book() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check("the shared activity book still validates whole (%s)"
			% ", ".join(library.errors), library.is_valid())
	_check("the landing interlock is authored in the shared book",
			library.has_activity(ACTIVITY))
	if not library.has_activity(ACTIVITY):
		return
	var authored := library.activity(ACTIVITY)

	var ids: Array[String] = []
	var total := 0.0
	var each_ok := true
	for step in (authored.steps as Array):
		var record := step as Dictionary
		ids.append(str(record.id))
		var seconds := float(record.expected_seconds)
		total += seconds
		each_ok = each_ok and seconds >= 3.0 and seconds <= 12.0
	_check("the authored order is gauge, jumper, keeper, home, refusal (%s)"
			% ", ".join(ids), ids == ORDER)
	_check("every verb is a 3-12 second physical action", each_ok)
	# The brief asks for a 25-40 second chain of roughly five verbs.
	_check("the chain is %.0f seconds across %d verbs" % [total, ids.size()],
			total >= 25.0 and total <= 40.0 and ids.size() == 5)

	var verbs := {}
	for step in (authored.steps as Array):
		verbs[str((step as Dictionary).verb)] = true
	_check("every verb is one the shared abstraction already speaks (%s)"
			% ", ".join(verbs.keys()),
			verbs.keys().all(func(v): return v in MaintenanceActivityLibrary.VERBS))
	_check("the transferable verb is continuity, which nothing else had taken",
			str(authored.transferable_verb) == "continuity")
	_check("the source cites both the Otis interlock patent and the 1921 code",
			str(authored.historical_source).contains("1,493,069")
			and str(authored.historical_source).contains("1921"))
	# The final verb must NOT target a closed door. An interlock is proved by
	# refusal, and an activity that ends with everything shut proves nothing.
	var last := authored.steps[4] as Dictionary
	_check("the proving verb deliberately targets a cracked door (%.2f)"
			% float(last.target), float(last.target) < 0.5)

	var forbidden := ["job", "job_id", "case", "case_id", "resident",
			"resident_id", "work_order", "dream", "save"]
	var leaked: Array[String] = []
	for key in authored.keys():
		if str(key) in forbidden:
			leaked.append(str(key))
	_check("the book carries no job, case, resident or Dream ownership",
			leaked.is_empty())


# --- the run ----------------------------------------------------------------

func _run() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	if not library.has_activity(ACTIVITY):
		return
	var authored := library.activity(ACTIVITY)

	var run := MaintenanceActivityRun.new()
	var completed: Array[Dictionary] = []
	run.completed.connect(func(r: Dictionary) -> void: completed.append(r))
	run.start(ACTIVITY, authored)
	var advanced := true
	for step in (authored.steps as Array):
		var record := step as Dictionary
		advanced = advanced and run.submit(str(record.verb),
				float(record.target),
				float(record.get("hold_min_seconds", 0.0)) + 0.4)
	_check("the authored order completes the chain and commits once",
			advanced and completed.size() == 1 and run.committed)
	_check("the committed result pulls the bridge and proves the interlock",
			completed.size() == 1
			and (completed[0].get("mechanism_patch", {}) as Dictionary).get(
					"jumper_present", true) == false
			and (completed[0].get("mechanism_patch", {}) as Dictionary).get(
					"interlock_proved", false) == true
			and not completed[0].has("job_id"))

	var first := authored.steps[0] as Dictionary
	for probe_case in [
			{"label": "reaching past the gauge for the bridge",
				"verb": "hold_release", "reason": "wrong_verb"},
			{"label": "setting the gauge outside its detent",
				"verb": "align", "reason": "outside_detent"}]:
		var probe := MaintenanceActivityRun.new()
		var reasons: Array[String] = []
		probe.input_rejected.connect(
				func(reason: String, _s: Dictionary) -> void:
					reasons.append(reason))
		probe.start(ACTIVITY, authored)
		var value := float(first.target)
		if str(probe_case.reason) == "outside_detent":
			value = clampf(value + float(first.tolerance) + 0.25, 0.0, 1.0)
		var accepted: bool = probe.submit(str(probe_case.verb), value, 0.0)
		_check("%s is refused as %s and the chain does not move"
				% [str(probe_case.label), str(probe_case.reason)],
				not accepted and reasons.size() == 1
				and reasons[0] == str(probe_case.reason)
				and probe.step_index == 0 and not probe.committed)

	# Letting the bridging wire go before the terminal screw has backed off.
	var early := MaintenanceActivityRun.new()
	var early_reasons: Array[String] = []
	early.input_rejected.connect(
			func(reason: String, _s: Dictionary) -> void:
				early_reasons.append(reason))
	early.start(ACTIVITY, authored)
	early.submit(str(first.verb), float(first.target), 0.0)
	var jumper := authored.steps[1] as Dictionary
	var took: bool = early.submit("hold_release", float(jumper.target),
			float(jumper.hold_min_seconds) * 0.25)
	_check("letting the bridge go early is refused as released_early",
			not took and early_reasons == ["released_early"]
			and early.step_index == 1)
	_check("and the very next correct attempt still lands",
			early.submit("hold_release", float(jumper.target),
					float(jumper.hold_min_seconds) + 0.4)
			and early.step_index == 2)

	var abandoned := MaintenanceActivityRun.new()
	var closed: Array[String] = []
	abandoned.aborted.connect(func(id: String) -> void: closed.append(id))
	abandoned.start(ACTIVITY, authored)
	abandoned.submit(str(first.verb), float(first.target), 0.0)
	_check("abort is reversible and commits nothing",
			abandoned.abort() and closed.size() == 1
			and not abandoned.committed and abandoned.result.is_empty())

	var assisted := MaintenanceActivityRun.new()
	assisted.start(ACTIVITY, authored,
			{"precision_scale": 2.5, "hold_assist": 4.0})
	_check("a wide detent and a short hold both still land the first verb",
			assisted.precision_scale > 1.0 and assisted.hold_assist > 1.0
			and assisted.submit(str(first.verb),
					float(first.target) + float(first.tolerance) * 1.6, 0.0))


# --- the lock ---------------------------------------------------------------

func _lock() -> void:
	var lock := ElevatorInterlockProp.new()
	lock.name = "TestInterlock"
	add_child(lock)

	var before := lock.maintenance_snapshot()
	_check("the mechanism starts with the fault the round exists to correct",
			lock.jumper_present and not lock.interlock_proved)

	# THE COUNTERFEIT, stated as plainly as the code states it. With the bridge
	# on and the door standing wide open, the circuit reads continuous and the
	# interlock holds nothing. These must be two different answers.
	lock.door_home = 0.0
	_check("a bridged circuit reads continuous with the door standing open",
			lock.circuit_continuous())
	_check("but the interlock does not hold, and the two are different questions",
			not lock.interlock_holds())

	# CLOSED IS NOT LOCKED. Door fully home, keeper still out of true.
	lock.jumper_present = false
	lock.door_home = 1.0
	lock.keeper_true = 0.34
	_check("a door brought fully home makes the shut contact",
			lock.shut_contact_made())
	_check("and with the keeper out of true the locked contact stays open",
			not lock.locked_contact_made() and lock.latch_depth() < 0.7)
	_check("so an honest circuit refuses: shut is not locked",
			not lock.circuit_continuous())
	lock.keeper_true = ElevatorInterlockProp.KEEPER_TRUE
	_check("truing the keeper alone closes the locked contact",
			lock.locked_contact_made() and lock.circuit_continuous()
			and lock.interlock_holds())

	# THE ORDER, enforced physically.
	lock.restore_maintenance_snapshot(before)
	lock.preview_maintenance_step({"id": "true_keeper"}, 0.78)
	_check("the keeper cannot be trued while the bridge is still on",
			is_equal_approx(lock.keeper_true, 0.34) and lock.balking())
	lock.restore_maintenance_snapshot(before)
	lock.preview_maintenance_step({"id": "pull_jumper"}, 0.63)
	lock.preview_maintenance_step({"id": "true_keeper"}, 0.78)
	_check("and it cannot be trued before the depth has been read",
			is_equal_approx(lock.keeper_true, 0.34) and lock.balking())

	# THE PROVING TEST refuses to be faked from either side.
	lock.restore_maintenance_snapshot(before)
	lock.preview_maintenance_step({"id": "prove_refusal"}, 0.22)
	_check("nothing can be proved through a bridge", lock.balking())
	lock.restore_maintenance_snapshot(before)
	lock.jumper_present = false
	lock.preview_maintenance_step({"id": "prove_refusal"}, 1.0)
	_check("and a door still home proves nothing either", lock.balking())

	# PREVIEW PUBLISHES NOTHING.
	lock.restore_maintenance_snapshot(before)
	lock.preview_maintenance_step({"id": "gauge_keeper"}, 0.42)
	lock.preview_maintenance_step({"id": "pull_jumper"}, 0.63)
	lock.preview_maintenance_step({"id": "true_keeper"}, 0.78)
	lock.preview_maintenance_step({"id": "bring_home"}, 1.0)
	_check("working the visible hardware publishes nothing before the commit",
			not lock.interlock_proved
			and not lock.jumper_present and lock.gauge_set > 0.0)
	_check("the car is still permitted, because nothing has been proved yet",
			lock.permits_car_start())

	lock.restore_maintenance_snapshot(before)
	_check("abandonment restores every mechanism fact and clears the balk",
			lock.jumper_present and is_equal_approx(lock.keeper_true, 0.34)
			and lock.gauge_set == 0.0 and not lock.interlock_proved
			and not lock.balking())

	# ONLY THE COMMIT PROVES, and even it cannot prove a bridged interlock.
	var liar := ElevatorInterlockProp.new()
	add_child(liar)
	liar.apply_maintenance_result({
		"quality": "good", "note": "counterfeit",
		"mechanism_patch": {"interlock_proved": true, "keeper_true": 0.78,
				"door_home": 1.0},
	})
	_check("no patch can prove an interlock that still carries its bridge",
			liar.jumper_present and not liar.interlock_proved)

	var reported: Array[Dictionary] = []
	lock.maintenance_completed.connect(
			func(r: Dictionary) -> void: reported.append(r))
	lock.apply_maintenance_result({
		"quality": "good",
		"note": "bridging wire removed; keeper trued and the landing interlock proved by refusal",
		"mechanism_patch": {"jumper_present": false,
				"keeper_true": ElevatorInterlockProp.KEEPER_TRUE,
				"door_home": 1.0, "interlock_proved": true},
	})
	_check("the guarded commit alone removes the bridge and proves the lock",
			not lock.jumper_present and lock.interlock_proved
			and lock.interlock_holds())
	_check("the mechanism reports completion without advancing a work order",
			reported.size() == 1 and str(reported[0].quality) == "good")

	# THE EARNED REFUSAL. Only now can the interlock say no.
	_check("a proved interlock permits the car while it is locked",
			lock.permits_car_start())
	lock.door_home = 0.22
	_check("and refuses the moment the door is cracked",
			not lock.permits_car_start() and not lock.circuit_continuous())
	_check("the prompt now reads as a check, because the bridge is gone",
			not lock.control_prompt("interlock").contains("Examine"))
	_check("the interlock is ray-reachable as a literal service point",
			lock.get_node_or_null("InterlockReach") is PropControlArea)
	_check("every named part of the interlock is present",
			lock.get_node_or_null("Keeper") is MeshInstance3D
			and lock.get_node_or_null("Latch") is MeshInstance3D
			and lock.get_node_or_null("RollerArm") is MeshInstance3D
			and lock.get_node_or_null("LockRoller") is MeshInstance3D
			and lock.get_node_or_null("RetiringCam") is MeshInstance3D
			and lock.get_node_or_null("ShutContact") is MeshInstance3D
			and lock.get_node_or_null("LockedContact") is MeshInstance3D)
	_check("the prop owns no light and no collision body but its reach",
			lock.find_children("*", "Light3D", true, false).is_empty()
			and lock.find_children("*", "CollisionObject3D", true,
					false).size() == 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[INTERLOCK FAIL] " + label)
	else:
		print("[interlock ok] " + label)


func _finish() -> void:
	print("MAINTENANCE INTERLOCK TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
