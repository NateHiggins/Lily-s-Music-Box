extends Node
## SR7-C — the roof house-tank ball cock.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/MaintenanceBallcockTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things are proved here and kept apart on purpose:
##
##   the BOOK   the authored activity satisfies the shared schema, teaches one
##              transferable verb and holds the 25-40 second window;
##   the RUN    the shared run enforces the order, names the real mistakes and
##              recovers without restarting;
##   the COCK   a float makes a force and not a reading; buoyancy and leverage
##              are each necessary and neither is sufficient; the witness is
##              the only honest report; and no data file can service a valve
##              that cannot hold.
##
## Production placement, the real tank and the ownership boundary against the
## boiler are proved separately in `maintenance_ballcock_live_test.gd`.

const ACTIVITY := "roof_tank_ballcock_service"
const ORDER := ["read_the_float", "shut_the_riser", "lift_the_float",
		"set_the_weight", "prove_the_hold"]

var checks := 0
var failures := 0


func _ready() -> void:
	_book()
	_run()
	_cock()
	_finish()


# --- the book ---------------------------------------------------------------

func _book() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check("the shared activity book still validates whole (%s)"
			% ", ".join(library.errors), library.is_valid())
	_check("the house-tank ball cock is authored in the shared book",
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
	_check("the authored order is read, shut, lift, weight, prove (%s)"
			% ", ".join(ids), ids == ORDER)
	_check("every verb is a 3-12 second physical action", each_ok)
	_check("the chain is %.0f seconds across %d verbs" % [total, ids.size()],
			total >= 25.0 and total <= 40.0 and ids.size() == 5)

	var verbs := {}
	for step in (authored.steps as Array):
		verbs[str((step as Dictionary).verb)] = true
	_check("every verb is one the shared abstraction already speaks (%s)"
			% ", ".join(verbs.keys()),
			verbs.keys().all(func(v): return v in MaintenanceActivityLibrary.VERBS))
	_check("the transferable verb is timing, the last one unclaimed",
			str(authored.transferable_verb) == "timing")
	# With this apparatus the ruled six-verb vocabulary is complete, and each
	# verb is spoken by exactly one machine.
	var spoken := {}
	for activity_id in library.activity_ids():
		spoken[str(library.activity(activity_id).transferable_verb)] = true
	_check("all six ruled transferable verbs are now spoken (%d/6)"
			% spoken.size(),
			spoken.size() == MaintenanceActivityLibrary.TRANSFERABLE_VERBS.size())
	_check("the source cites both the 1902 float cock and the 1910 ball cock",
			str(authored.historical_source).contains("190,216,359")
			and str(authored.historical_source).contains("951,172"))
	_check("the round is authored on the roof lane",
			str(authored.location_lane) == "roof")

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
	var patch: Dictionary = completed[0].get("mechanism_patch", {}) \
			if completed.size() == 1 else {}
	_check("the committed result drains the float and stops the overflow",
			patch.get("float_waterlogged", true) == false
			and patch.get("ballcock_serviced", false) == true
			and patch.get("overflow_running", true) == false
			and not completed[0].has("job_id"))

	var first := authored.steps[0] as Dictionary
	for probe in [
			{"label": "reaching for the riser before reading the float",
				"verb": "turn", "reason": "wrong_verb"},
			{"label": "setting the tell-tale outside its detent",
				"verb": "align", "reason": "outside_detent"}]:
		var run2 := MaintenanceActivityRun.new()
		var reasons: Array[String] = []
		run2.input_rejected.connect(
				func(reason: String, _s: Dictionary) -> void:
					reasons.append(reason))
		run2.start(ACTIVITY, authored)
		var value := float(first.target)
		if str(probe.reason) == "outside_detent":
			value = clampf(value - float(first.tolerance) - 0.25, 0.0, 1.0)
		var took: bool = run2.submit(str(probe.verb), value, 0.0)
		_check("%s is refused as %s and the chain does not move"
				% [str(probe.label), str(probe.reason)],
				not took and reasons == [str(probe.reason)]
				and run2.step_index == 0 and not run2.committed)

	# Letting the float back down before it has finished draining.
	var early := MaintenanceActivityRun.new()
	var early_reasons: Array[String] = []
	early.input_rejected.connect(
			func(reason: String, _s: Dictionary) -> void:
				early_reasons.append(reason))
	early.start(ACTIVITY, authored)
	early.submit(str(first.verb), float(first.target), 0.0)
	var riser := authored.steps[1] as Dictionary
	early.submit(str(riser.verb), float(riser.target), 0.0)
	var lift := authored.steps[2] as Dictionary
	var dropped: bool = early.submit("hold_release", float(lift.target),
			float(lift.hold_min_seconds) * 0.25)
	_check("letting the float back down early is refused as released_early",
			not dropped and early_reasons == ["released_early"]
			and early.step_index == 2)
	_check("and the very next correct attempt still lands",
			early.submit("hold_release", float(lift.target),
					float(lift.hold_min_seconds) + 0.4)
			and early.step_index == 3)

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


# --- the cock ---------------------------------------------------------------

func _cock() -> void:
	var cock := RoofTankBallcockProp.new()
	cock.name = "TestBallcock"
	add_child(cock)
	var before := cock.maintenance_snapshot()

	_check("the apparatus is found waterlogged with the overflow running",
			cock.float_waterlogged and cock.riser_open
			and cock.overflow_running() and not cock.ballcock_serviced)

	# THE DECEIT. The float rides at the full mark whether or not it is sound,
	# so nothing about its position can diagnose the fault.
	var drowned_ride := cock.float_ride()
	cock.float_waterlogged = false
	_check("a sound float and a waterlogged one ride at the same mark (%.2f)"
			% drowned_ride, is_equal_approx(cock.float_ride(), drowned_ride))
	cock.float_waterlogged = true

	# THE THESIS: closing force is buoyancy times leverage, and each is
	# necessary while neither is sufficient.
	cock.weight_set = RoofTankBallcockProp.WEIGHT_HOME
	_check("leverage alone will not close it while the float is drowned",
			not cock.valve_holds() and cock.overflow_running())
	cock.float_waterlogged = false
	cock.weight_set = 0.18
	_check("and a sound float alone will not close it without the leverage",
			not cock.valve_holds() and cock.overflow_running())
	cock.weight_set = RoofTankBallcockProp.WEIGHT_HOME
	_check("together they close it, and the overflow stops",
			cock.valve_holds() and not cock.overflow_running())
	_check("closing force really is the product, not a lookup (%.3f)"
			% cock.closing_force(),
			is_equal_approx(cock.closing_force(),
					cock.buoyancy() * cock.leverage()))

	# A SHUT RISER IS NOT A HOLDING VALVE.
	cock.float_waterlogged = true
	cock.weight_set = 0.18
	cock.riser_open = false
	_check("a dry witness under a shut stop proves nothing about the valve",
			not cock.overflow_running() and not cock.valve_holds())

	# THE ORDER, enforced physically.
	cock.restore_maintenance_snapshot(before)
	cock.preview_maintenance_step({"id": "lift_the_float"}, 0.55)
	_check("the float cannot be lifted against a live inlet",
			cock.float_waterlogged and cock.balking())
	cock.restore_maintenance_snapshot(before)
	cock.preview_maintenance_step({"id": "set_the_weight"}, 0.64)
	_check("THE BODGE: leverage cannot be bought to cover a drowned float",
			is_equal_approx(cock.weight_set, 0.18) and cock.balking())
	cock.restore_maintenance_snapshot(before)
	cock.preview_maintenance_step({"id": "prove_the_hold"}, 0.2)
	_check("and nothing can be proved with the riser left shut",
			not cock.riser_open and cock.balking())

	# THE HONEST FAILURE: opening the riser on a cock that cannot hold.
	cock.restore_maintenance_snapshot(before)
	cock.preview_maintenance_step({"id": "shut_the_riser"}, 0.0)
	cock.preview_maintenance_step({"id": "lift_the_float"}, 0.55)
	_check("held clear of a dead inlet, the float drains",
			not cock.float_waterlogged)
	cock.preview_maintenance_step({"id": "prove_the_hold"}, 0.91)
	_check("opened before the weight is set, it still pays out and balks",
			cock.overflow_running() and cock.balking())

	# PREVIEW PUBLISHES NOTHING.
	cock.restore_maintenance_snapshot(before)
	cock.preview_maintenance_step({"id": "read_the_float"}, 0.86)
	cock.preview_maintenance_step({"id": "shut_the_riser"}, 0.0)
	cock.preview_maintenance_step({"id": "lift_the_float"}, 0.55)
	cock.preview_maintenance_step({"id": "set_the_weight"}, 0.64)
	cock.preview_maintenance_step({"id": "prove_the_hold"}, 0.91)
	_check("working the visible apparatus publishes nothing before the commit",
			not cock.ballcock_serviced and not cock.float_waterlogged
			and cock.valve_holds())

	cock.restore_maintenance_snapshot(before)
	_check("abandonment restores every apparatus fact and clears the balk",
			cock.float_waterlogged and cock.riser_open
			and is_equal_approx(cock.weight_set, 0.18)
			and cock.tell_tale == 0.0 and cock.float_lift == 0.0
			and not cock.ballcock_serviced and not cock.balking()
			and cock.overflow_running())

	# ONLY THE COMMIT SERVICES, and even it cannot service a cock that will
	# not hold.
	var liar := RoofTankBallcockProp.new()
	add_child(liar)
	liar.apply_maintenance_result({
		"quality": "good", "note": "counterfeit",
		"mechanism_patch": {"ballcock_serviced": true},
	})
	_check("no patch can service a valve that still cannot hold",
			not liar.ballcock_serviced and liar.float_waterlogged)

	var reported: Array[Dictionary] = []
	cock.maintenance_completed.connect(
			func(r: Dictionary) -> void: reported.append(r))
	cock.apply_maintenance_result({
		"quality": "good",
		"note": "float drained and reseated; lever weight set to the riser pressure and the cock proved dry on the witness",
		"mechanism_patch": {"float_waterlogged": false,
				"weight_set": RoofTankBallcockProp.WEIGHT_HOME,
				"riser_open": true, "overflow_running": false,
				"ballcock_serviced": true},
	})
	_check("the guarded commit alone services the cock and stops the overflow",
			cock.ballcock_serviced and cock.valve_holds()
			and not cock.overflow_running() and not cock.float_waterlogged)
	_check("the apparatus reports completion without advancing a work order",
			reported.size() == 1 and str(reported[0].quality) == "good")
	_check("the prompt stops announcing an overflow once it is holding",
			not cock.control_prompt("ballcock").contains("overflowing"))

	_check("the ball cock is ray-reachable as a literal service point",
			cock.get_node_or_null("BallcockReach") is PropControlArea)
	for part in ["FloatColumn", "Float", "FloatRod", "LeverArm", "LeverWeight",
			"CockBody", "ValveSeat", "InletRiser", "RiserStop", "OverflowPipe",
			"OverflowWitness", "OverflowStream", "TellTale"]:
		_check("the apparatus shows its %s" % part,
				cock.get_node_or_null(NodePath(part)) is MeshInstance3D)
	_check("the apparatus owns no light and no collision body but its reach",
			cock.find_children("*", "Light3D", true, false).is_empty()
			and cock.find_children("*", "CollisionObject3D", true,
					false).size() == 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[BALLCOCK FAIL] " + label)
	else:
		print("[ballcock ok] " + label)


func _finish() -> void:
	print("MAINTENANCE BALLCOCK TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
