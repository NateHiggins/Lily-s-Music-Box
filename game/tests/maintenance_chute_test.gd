extends Node
## SR7-D — the lobby mail chute and its choke.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/MaintenanceChuteTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things are proved here and kept apart on purpose:
##
##   the BOOK   the authored activity satisfies the shared schema, holds the
##              25-40 second window, and REUSES a ruled verb rather than
##              inventing one;
##   the RUN    the shared run enforces the order, names the real mistakes and
##              recovers without restarting;
##   the CHUTE  an empty collection box is not evidence; the arch stands on
##              friction and has to be found, unloaded and broken in that
##              order; and no data file can call a choked chute clear.

const ACTIVITY := "mail_chute_choke_clearing"
const MailChutePropScript := preload("res://scripts/props/mail_chute_prop.gd")
const ORDER := ["read_the_glass", "unlock_the_cover", "take_the_load",
		"break_the_arch", "prove_the_drop"]

var checks := 0
var failures := 0


func _ready() -> void:
	_book()
	_run()
	_chute()
	_finish()


# --- the book ---------------------------------------------------------------

func _book() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check("the shared activity book still validates whole (%s)"
			% ", ".join(library.errors), library.is_valid())
	_check("the mail chute is authored in the shared book",
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
	_check("the authored order is read, unlock, unload, break, prove (%s)"
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
	# The six ruled verbs were exhausted at SR7-C. This apparatus had to reuse
	# one, and the test records that it did so rather than widening the ruling.
	_check("it REUSES the ruled verb `flow` instead of inventing a seventh",
			str(authored.transferable_verb) == "flow"
			and "flow" in MaintenanceActivityLibrary.TRANSFERABLE_VERBS)
	var sharing: Array[String] = []
	for activity_id in library.activity_ids():
		if str(library.activity(activity_id).transferable_verb) == "flow":
			sharing.append(activity_id)
	_check("and `flow` is now spoken by exactly two machines (%s)"
			% ", ".join(sharing), sharing.size() == 2)
	_check("the source cites both the 1883 Cutler chute and the 1923 choke",
			str(authored.historical_source).contains("284,951")
			and str(authored.historical_source).contains("1,450,139"))

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
	_check("the committed result drops the arch and records the chute clear",
			patch.get("arch_standing", true) == false
			and patch.get("chute_clear", false) == true
			and patch.get("load_taken", false) == true
			and not completed[0].has("job_id"))

	var first := authored.steps[0] as Dictionary
	for probe in [
			{"label": "keying the cover before reading the glass",
				"verb": "turn", "reason": "wrong_verb"},
			{"label": "running the lamp outside its detent",
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

	# Letting the catch tray go before the load is off it.
	var early := MaintenanceActivityRun.new()
	var early_reasons: Array[String] = []
	early.input_rejected.connect(
			func(reason: String, _s: Dictionary) -> void:
				early_reasons.append(reason))
	early.start(ACTIVITY, authored)
	early.submit(str(first.verb), float(first.target), 0.0)
	var cover := authored.steps[1] as Dictionary
	early.submit(str(cover.verb), float(cover.target), 0.0)
	var load := authored.steps[2] as Dictionary
	var dropped: bool = early.submit("hold_release", float(load.target),
			float(load.hold_min_seconds) * 0.25)
	_check("letting the tray go early is refused as released_early",
			not dropped and early_reasons == ["released_early"]
			and early.step_index == 2)
	_check("and the very next correct attempt still lands",
			early.submit("hold_release", float(load.target),
					float(load.hold_min_seconds) + 0.4)
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


# --- the chute --------------------------------------------------------------

func _chute() -> void:
	var chute := MailChutePropScript.new()
	chute.name = "TestChute"
	add_child(chute)
	var before := chute.maintenance_snapshot()

	_check("the apparatus is found choked, locked and not clear",
			chute.arch_standing and chute.cover_locked
			and not chute.load_taken and not chute.chute_clear)

	# THE LIE. The collection box is empty with the arch standing and empty
	# after it falls. `box_appears_empty()` must not consult `arch_standing` at
	# all, or the apparatus would be quietly telling the player the answer.
	_check("the box appears empty while the chute is choked",
			chute.box_appears_empty() and not chute.passage_clear())
	chute.arch_standing = false
	_check("and it still appears empty once the chute is clear",
			chute.box_appears_empty() and chute.passage_clear())
	chute.arch_standing = true

	# THE ORDER, enforced physically.
	chute.restore_maintenance_snapshot(before)
	chute.preview_maintenance_step({"id": "take_the_load"}, 0.58)
	_check("the glass will not draw under a locked cover",
			chute.glass_drawn == 0.0 and not chute.load_taken
			and chute.balking())
	chute.restore_maintenance_snapshot(before)
	chute.preview_maintenance_step({"id": "break_the_arch"}, 0.41)
	_check("and the blade will not go in under a locked cover either",
			chute.arch_standing and chute.balking())

	# THE DANGEROUS ORDER: cutting the span with the column still on it.
	chute.restore_maintenance_snapshot(before)
	chute.preview_maintenance_step({"id": "unlock_the_cover"}, 1.0)
	_check("keying the cover frees the glass", not chute.cover_locked)
	chute.preview_maintenance_step({"id": "break_the_arch"}, 0.41)
	_check("THE AVALANCHE: the arch cannot be broken with its load still on",
			chute.arch_standing and not chute.load_taken and chute.balking())

	# The honest order.
	chute.preview_maintenance_step({"id": "take_the_load"}, 0.58)
	_check("drawing the glass takes the load off the arch",
			chute.load_taken and chute.glass_drawn > 0.0
			and chute.arch_standing)
	chute.preview_maintenance_step({"id": "break_the_arch"}, 0.41)
	_check("and only then does the span go",
			not chute.arch_standing and chute.passage_clear())

	# PROVING. A test piece is the only evidence there is, and it needs the
	# glass shut to reach the box at all.
	chute.restore_maintenance_snapshot(before)
	chute.preview_maintenance_step({"id": "prove_the_drop"}, 0.88)
	_check("a test piece posted into a choked chute never arrives",
			not chute.test_piece_landed and chute.balking())
	chute.restore_maintenance_snapshot(before)
	chute.preview_maintenance_step({"id": "unlock_the_cover"}, 1.0)
	chute.preview_maintenance_step({"id": "take_the_load"}, 0.58)
	chute.preview_maintenance_step({"id": "break_the_arch"}, 0.41)
	_check("with the glass still drawn a drop would not reach the box",
			chute.glass_drawn > 0.12 and not chute.drop_reaches_box())
	chute.preview_maintenance_step({"id": "prove_the_drop"}, 0.88)
	_check("posting shuts the glass and the piece lands in the box",
			chute.glass_drawn == 0.0 and chute.drop_reaches_box()
			and chute.test_piece_landed and not chute.box_appears_empty())

	# PREVIEW PUBLISHES NOTHING.
	_check("working the visible apparatus publishes nothing before the commit",
			not chute.chute_clear)

	chute.restore_maintenance_snapshot(before)
	_check("abandonment restores every apparatus fact and clears the balk",
			chute.arch_standing and chute.cover_locked
			and not chute.load_taken and chute.glass_drawn == 0.0
			and chute.lamp_scan == 0.0 and chute.blade_set == 0.0
			and not chute.test_piece_landed and not chute.chute_clear
			and not chute.balking())

	# ONLY THE COMMIT RECORDS, and even it cannot record a choked chute clear.
	var liar := MailChutePropScript.new()
	add_child(liar)
	liar.apply_maintenance_result({
		"quality": "good", "note": "counterfeit",
		"mechanism_patch": {"chute_clear": true},
	})
	_check("no patch can call a chute clear while the arch still stands",
			not liar.chute_clear and liar.arch_standing)

	var reported: Array[Dictionary] = []
	chute.maintenance_completed.connect(
			func(r: Dictionary) -> void: reported.append(r))
	chute.apply_maintenance_result({
		"quality": "good",
		"note": "arch broken at the choke, load recovered and the chute proved by a test piece to the box",
		"mechanism_patch": {"arch_standing": false, "load_taken": true,
				"cover_locked": true, "glass_drawn": 0.0,
				"chute_clear": true},
	})
	_check("the guarded commit alone records the chute clear and locks up",
			chute.chute_clear and chute.passage_clear()
			and chute.cover_locked and chute.glass_drawn == 0.0)
	_check("the apparatus reports completion without advancing a work order",
			reported.size() == 1 and str(reported[0].quality) == "good")
	_check("the prompt stops announcing a choke once it is cleared",
			not chute.control_prompt("chute").contains("choked"))

	_check("the chute is ray-reachable as a literal service point",
			chute.get_node_or_null("ChuteReach") is PropControlArea)
	for part in ["ChuteBody", "GlassFront", "ExpansionChamber",
			"ChokeCheekWest", "ChokeCheekEast", "ArchLetterWest",
			"ArchLetterEast", "LoadStack", "LockCover", "KeyBarrel",
			"CatchTray", "ClearingBlade", "CollectionBox", "BoxDoor",
			"TestPiece", "LampIndex"]:
		_check("the apparatus shows its %s" % part,
				chute.get_node_or_null(NodePath(part)) is MeshInstance3D)
	_check("the apparatus owns no light and no collision body but its reach",
			chute.find_children("*", "Light3D", true, false).is_empty()
			and chute.find_children("*", "CollisionObject3D", true,
					false).size() == 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[CHUTE FAIL] " + label)
	else:
		print("[chute ok] " + label)


func _finish() -> void:
	print("MAINTENANCE CHUTE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
