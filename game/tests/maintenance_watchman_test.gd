extends Node
## SR7-F — the watchman's time detector.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/MaintenanceWatchmanTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things are proved here and kept apart on purpose:
##
##   the BOOK    the authored activity satisfies the shared schema, holds the
##               25-40 second window, and REUSES a ruled verb;
##   the RUN     the shared run enforces the order, names the real mistakes and
##               recovers without restarting;
##   the DIAL    a running movement proves nothing; a dial off its drive pin
##               records a whole night at one instant; the datum must agree
##               with the house; and no data file can call the detector honest.
##
## The prop is reached through a PRELOADED SCRIPT rather than its global class
## name, so this runs on a clean checkout whose class cache has not been built.

const ACTIVITY := "watchman_detector_dial"
const WatchmanScript := preload("res://scripts/props/watchman_clock_prop.gd")
const ORDER := ["read_the_dial", "stop_the_movement", "seat_the_dial",
		"set_the_datum", "prove_the_round"]

var checks := 0
var failures := 0


func _ready() -> void:
	_book()
	_run()
	_dial()
	_finish()


# --- the book ---------------------------------------------------------------

func _book() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check("the shared activity book still validates whole (%s)"
			% ", ".join(library.errors), library.is_valid())
	_check("the watchman's detector is authored in the shared book",
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
	_check("the authored order is read, stop, seat, datum, prove (%s)"
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
	_check("it REUSES the ruled verb `timing` rather than widening the six",
			str(authored.transferable_verb) == "timing"
			and "timing" in MaintenanceActivityLibrary.TRANSFERABLE_VERBS)
	var sharing: Array[String] = []
	for activity_id in library.activity_ids():
		if str(library.activity(activity_id).transferable_verb) == "timing":
			sharing.append(activity_id)
	_check("and `timing` is now spoken by exactly two machines (%s)"
			% ", ".join(sharing), sharing.size() == 2)
	_check("the source names both the Newman dial and the Moosmann detector",
			str(authored.historical_source).contains("676,764")
			and str(authored.historical_source).contains("1,351,056"))

	var forbidden := ["job", "job_id", "case", "case_id", "resident",
			"resident_id", "work_order", "dream", "save", "route", "patrol"]
	var leaked: Array[String] = []
	for key in authored.keys():
		if str(key) in forbidden:
			leaked.append(str(key))
	_check("the book carries no job, case, resident, route or Dream ownership",
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
	_check("the committed result seats the dial and records it honest",
			patch.get("dial_seated", false) == true
			and patch.get("detector_honest", false) == true
			and not completed[0].has("job_id"))

	var first := authored.steps[0] as Dictionary
	for probe in [
			{"label": "throwing the stop before reading the dial",
				"verb": "turn", "reason": "wrong_verb"},
			{"label": "running the index outside its detent",
				"verb": "align", "reason": "outside_detent"}]:
		var run2 := MaintenanceActivityRun.new()
		var reasons: Array[String] = []
		run2.input_rejected.connect(
				func(reason: String, _s: Dictionary) -> void:
					reasons.append(reason))
		run2.start(ACTIVITY, authored)
		var value := float(first.target)
		if str(probe.reason) == "outside_detent":
			value = clampf(value - float(first.tolerance) - 0.30, 0.0, 1.0)
		var took: bool = run2.submit(str(probe.verb), value, 0.0)
		_check("%s is refused as %s and the chain does not move"
				% [str(probe.label), str(probe.reason)],
				not took and reasons == [str(probe.reason)]
				and run2.step_index == 0 and not run2.committed)

	# Letting the key go before the dial has carried the first mark away.
	var early := MaintenanceActivityRun.new()
	var early_reasons: Array[String] = []
	early.input_rejected.connect(
			func(reason: String, _s: Dictionary) -> void:
				early_reasons.append(reason))
	early.start(ACTIVITY, authored)
	for i in 4:
		var record := authored.steps[i] as Dictionary
		early.submit(str(record.verb), float(record.target),
				float(record.get("hold_min_seconds", 0.0)) + 0.4)
	var prove := authored.steps[4] as Dictionary
	var dropped: bool = early.submit("hold_release", float(prove.target),
			float(prove.hold_min_seconds) * 0.25)
	_check("letting the key go early is refused as released_early",
			not dropped and early_reasons == ["released_early"]
			and early.step_index == 4)
	_check("and the very next correct attempt still lands",
			early.submit("hold_release", float(prove.target),
					float(prove.hold_min_seconds) + 0.4)
			and early.committed)

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


# --- the dial ---------------------------------------------------------------

func _dial() -> void:
	var det := WatchmanScript.new()
	det.name = "TestDetector"
	add_child(det)
	var before := det.maintenance_snapshot()

	# AS FOUND: the movement is RUNNING. Nothing is broken. The paper is simply
	# not on the pin, so it never moved and never will.
	_check("the detector is found running, unseated and dishonest",
			det.movement_running and not det.dial_seated
			and not det.dial_turns() and not det.detector_honest)
	_check("a running movement is not the same question as a turning dial",
			det.movement_running and not det.dial_turns())
	_check("and the record cannot be honest while the paper stands still",
			not det.record_is_honest())

	# THE DATUM IS READ FROM THE HOUSE, NOT INVENTED. With no director in the
	# tree the apparatus falls back to the canonical 03:00 the tests run at.
	_check("the correct datum is derived from the house hour (%.3f)"
			% det.correct_datum(),
			is_equal_approx(det.correct_datum(),
					fposmod(WatchmanScript.CANONICAL_MINUTE / 1440.0
							+ WatchmanScript.FRESH_DIAL_OFFSET, 1.0)))

	# REFUSAL 1: you cannot seat a dial against a turning spindle.
	det.restore_maintenance_snapshot(before)
	det.preview_maintenance_step({"id": "seat_the_dial"}, 0.44)
	_check("REFUSAL: the dial will not seat against a running movement",
			not det.dial_seated and det.balking())

	# REFUSAL 2: a loose dial has no datum to set.
	det.restore_maintenance_snapshot(before)
	det.preview_maintenance_step({"id": "stop_the_movement"}, 0.0)
	_check("throwing the stop lever stills the movement",
			not det.movement_running)
	det.preview_maintenance_step({"id": "set_the_datum"}, 0.71)
	_check("REFUSAL: a dial that is not seated has no datum",
			not det.datum_set and det.balking())

	# REFUSAL 3: the datum must agree with the house, or the record is a
	# careful and wholly false account of the night.
	det.preview_maintenance_step({"id": "seat_the_dial"}, 0.44)
	_check("with the movement stopped the dial seats on its pin",
			det.dial_seated)
	det.preview_maintenance_step({"id": "set_the_datum"},
			fposmod(det.correct_datum() + 0.30, 1.0))
	_check("REFUSAL: a datum set to the wrong hour is refused",
			not det.datum_set and det.balking()
			and det.datum_error() > WatchmanScript.DATUM_TOLERANCE)
	det.preview_maintenance_step({"id": "set_the_datum"}, det.correct_datum())
	_check("and the house hour is accepted",
			det.datum_set and det.datum_error() <= WatchmanScript.DATUM_TOLERANCE)

	# REFUSAL 4 -- THE FAULT ITSELF: proving with the movement stopped would
	# put both marks in the same place, which is the record we came to throw
	# away.
	det.preview_maintenance_step({"id": "prove_the_round"}, 0.83)
	_check("REFUSAL: nothing can be proved while the spindle is stopped",
			not det.marks_prove_movement() and det.balking())

	# REFUSAL 5: and nothing can be proved on a dial that is not seated.
	det.restore_maintenance_snapshot(before)
	det.preview_maintenance_step({"id": "prove_the_round"}, 0.83)
	_check("REFUSAL: nor on a dial that is still loose",
			not det.marks_prove_movement() and det.balking())

	# THE HONEST ORDER, and the proof itself.
	det.restore_maintenance_snapshot(before)
	det.preview_maintenance_step({"id": "read_the_dial"}, 0.58)
	det.preview_maintenance_step({"id": "stop_the_movement"}, 0.0)
	det.preview_maintenance_step({"id": "seat_the_dial"}, 0.44)
	det.preview_maintenance_step({"id": "set_the_datum"}, det.correct_datum())
	det.movement_running = true
	det.preview_maintenance_step({"id": "prove_the_round"}, 0.83)
	_check("two marks, at different angles, are what proves the paper moved",
			det.marks_prove_movement() and det.proof_first >= 0.0
			and det.proof_second >= 0.0
			and not is_equal_approx(det.proof_first, det.proof_second))
	_check("and only then is the record honest", det.record_is_honest())

	# PREVIEW PUBLISHES NOTHING.
	_check("working the visible detector publishes nothing before the commit",
			not det.detector_honest)

	det.restore_maintenance_snapshot(before)
	_check("abandonment restores every apparatus fact and clears the balk",
			not det.dial_seated and det.movement_running
			and not det.datum_set and det.reading == 0.0
			and det.proof_first < 0.0 and det.proof_second < 0.0
			and not det.detector_honest and not det.balking())

	# ONLY THE COMMIT RECORDS, and even it cannot bless a dishonest detector.
	var liar = WatchmanScript.new()
	add_child(liar)
	liar.apply_maintenance_result({
		"quality": "good", "note": "counterfeit",
		"mechanism_patch": {"detector_honest": true},
	})
	_check("no patch can call an unseated detector honest",
			not liar.detector_honest and not liar.dial_seated)

	var reported: Array[Dictionary] = []
	det.maintenance_completed.connect(
			func(r: Dictionary) -> void: reported.append(r))
	det.apply_maintenance_result({
		"quality": "good",
		"note": "dial seated on its drive pin, datum set to the house hour and the movement proved by two separated marks",
		"mechanism_patch": {"dial_seated": true, "movement_running": true,
				"datum_set": true, "detector_honest": true},
	})
	_check("the guarded commit alone records the detector honest",
			det.detector_honest and det.record_is_honest()
			and det.dial_turns())
	_check("the apparatus reports completion without advancing a work order",
			reported.size() == 1 and str(reported[0].quality) == "good")
	_check("the prompt stops asking to be read once it is honest",
			not det.control_prompt("detector").contains("Read"))

	_check("the detector is ray-reachable as a literal service point",
			det.get_node_or_null("DetectorReach") is PropControlArea)
	for part in ["DetectorCase", "GlassLid", "PaperDial", "DriveSpindle",
			"DrivePin", "IndexHole", "StopLever", "StationKey",
			"ReadingIndex", "MovementHand", "ProofMarkFirst",
			"ProofMarkSecond"]:
		_check("the apparatus shows its %s" % part,
				det.find_child(part, true, false) is MeshInstance3D)
	_check("last night's six station marks are all present on the dial",
			det.find_child("NightMark0", true, false) is MeshInstance3D
			and det.find_child("NightMark5", true, false) is MeshInstance3D)

	# THE TWO PIVOTS, asserted as a structure rather than as decoration. The
	# sheet and the spindle are separate nodes because they are separate
	# things, and the whole fault is the angle between them. Anything printed
	# or punched on the paper has to hang off the paper: a graduation that
	# stayed put while the dial turned would make the datum a lie.
	var arbor := det.get_node_or_null("SpindlePivot") as Node3D
	var sheet := det.get_node_or_null("PaperPivot") as Node3D
	_check("the spindle and the sheet are two separate pivots",
			arbor != null and sheet != null)
	_check("the drive pin turns with the spindle",
			arbor != null and arbor.get_node_or_null("DrivePin") != null)
	_check("the index hole is punched in the paper, not fixed to the case",
			sheet != null and sheet.get_node_or_null("IndexHole") != null)
	_check("every station mark rides on the paper",
			sheet != null and sheet.get_node_or_null("NightMark0") != null
			and sheet.get_node_or_null("NightMark5") != null
			and sheet.get_node_or_null("ProofMarkFirst") != null)
	_check("the hand and the reading index belong to the case, not the sheet",
			det.get_node_or_null("MovementHand") != null
			and det.get_node_or_null("ReadingIndex") != null)

	# An unseated dial does not turn, whatever the spindle is doing, and a
	# seated one is at the spindle's own angle. Two assertions, one thesis.
	det.dial_seated = false
	det.datum = 0.31
	det._refresh_mechanism()
	_check("an unseated sheet lies where it was dropped while the arbor runs",
			absf(sheet.rotation.z) < 0.0001
			and absf(arbor.rotation.z) > 0.0001)
	det.dial_seated = true
	det._refresh_mechanism()
	_check("a seated sheet is at its spindle angle, so the pin is in the hole",
			absf(sheet.rotation.z - arbor.rotation.z) < 0.0001
			and absf(sheet.rotation.z + TAU * 0.31) < 0.0001)
	_check("the apparatus owns no light and no collision body but its reach",
			det.find_children("*", "Light3D", true, false).is_empty()
			and det.find_children("*", "CollisionObject3D", true,
					false).size() == 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[WATCHMAN FAIL] " + label)
	else:
		print("[watchman ok] " + label)


func _finish() -> void:
	print("MAINTENANCE WATCHMAN TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
