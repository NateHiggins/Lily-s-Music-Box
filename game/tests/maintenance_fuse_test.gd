extends Node
## SR7-E — the house panelboard's fuse rating.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/MaintenanceFuseTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things are proved here and kept apart on purpose:
##
##   the BOOK   the authored activity satisfies the shared schema, holds the
##              25-40 second window, and REUSES a ruled verb;
##   the RUN    the shared run enforces the order, names the real mistakes and
##              recovers without restarting;
##   the PANEL  a whole link is not evidence; the holder is live whatever the
##              lamps are doing; a bigger plug is the fault and not a repair;
##              and no data file can call an over-fused panel safe.
##
## The prop is reached through a PRELOADED SCRIPT rather than its global class
## name, so this runs on a clean checkout whose class cache has not been built
## yet -- the portability lesson from SR7-D.

const ACTIVITY := "fuse_panel_rating_service"
const FusePanelScript := preload("res://scripts/props/fuse_panel_prop.gd")
const ORDER := ["read_the_stamp", "pull_the_main", "draw_the_plug",
		"match_the_wire", "prove_under_load"]

var checks := 0
var failures := 0


func _ready() -> void:
	_book()
	_run()
	_panel()
	_finish()


# --- the book ---------------------------------------------------------------

func _book() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check("the shared activity book still validates whole (%s)"
			% ", ".join(library.errors), library.is_valid())
	_check("the fuse panel is authored in the shared book",
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
	_check("the authored order is read, main, draw, match, prove (%s)"
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
	_check("it REUSES the ruled verb `regulation` rather than widening the six",
			str(authored.transferable_verb) == "regulation"
			and "regulation" in MaintenanceActivityLibrary.TRANSFERABLE_VERBS)
	var sharing: Array[String] = []
	for activity_id in library.activity_ids():
		if str(library.activity(activity_id).transferable_verb) == "regulation":
			sharing.append(activity_id)
	_check("and `regulation` is now spoken by exactly two machines (%s)"
			% ", ".join(sharing), sharing.size() == 2)
	_check("the source names Taylor's nontamperable plug fuse",
			str(authored.historical_source).contains("2,147,221"))
	_check("the round is authored on the basement lane",
			str(authored.location_lane) == "basement")

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
	_check("the committed result fits fifteen and records the panel safe",
			int(patch.get("fitted_rating", 0)) == 15
			and patch.get("panel_safe", false) == true
			and not completed[0].has("job_id"))

	var first := authored.steps[0] as Dictionary
	for probe in [
			{"label": "reaching for the main before reading the stamp",
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

	# Letting the plug go before it is clear of its base.
	var early := MaintenanceActivityRun.new()
	var early_reasons: Array[String] = []
	early.input_rejected.connect(
			func(reason: String, _s: Dictionary) -> void:
				early_reasons.append(reason))
	early.start(ACTIVITY, authored)
	early.submit(str(first.verb), float(first.target), 0.0)
	var main_step := authored.steps[1] as Dictionary
	early.submit(str(main_step.verb), float(main_step.target), 0.0)
	var draw := authored.steps[2] as Dictionary
	var dropped: bool = early.submit("hold_release", float(draw.target),
			float(draw.hold_min_seconds) * 0.25)
	_check("letting the plug go early is refused as released_early",
			not dropped and early_reasons == ["released_early"]
			and early.step_index == 2)
	_check("and the very next correct attempt still lands",
			early.submit("hold_release", float(draw.target),
					float(draw.hold_min_seconds) + 0.4)
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


# --- the panel --------------------------------------------------------------

func _panel() -> void:
	var panel := FusePanelScript.new()
	panel.name = "TestPanel"
	add_child(panel)
	var before := panel.maintenance_snapshot()

	_check("the panel is found over-fused, live and perfectly working",
			panel.over_fused() and panel.panel_live() and panel.link_whole()
			and not panel.panel_safe
			and panel.fitted_rating == FusePanelScript.FOUND_RATING)
	_check("thirty amperes stands on a fifteen-ampere conductor",
			panel.fitted_rating == 30
			and FusePanelScript.CONDUCTOR_RATING == 15
			and not panel.protects_conductor())

	# THE HAZARD ITSELF: every plug fits every hole. `rating_at` carries no gate
	# because an Edison base carries no gate, which is the whole period problem
	# and the reason Taylor's rejection base had to be invented at all.
	_check("a 10, 15, 20 and 30 are all selectable in the same holder",
			panel.rating_at(0.10) == 10 and panel.rating_at(0.34) == 15
			and panel.rating_at(0.55) == 20 and panel.rating_at(0.90) == 30)
	_check("and a whole link stays whole evidence at any rating",
			panel.link_whole())

	# THE SAFETY REFUSAL. A fuse is not a switch.
	panel.restore_maintenance_snapshot(before)
	panel.preview_maintenance_step({"id": "draw_the_plug"}, 0.55)
	_check("THE HOLDER IS LIVE: the plug will not be drawn under the main",
			not panel.plug_out and panel.balking())

	# THE FAULT OFFERED AS A REPAIR.
	panel.restore_maintenance_snapshot(before)
	panel.preview_maintenance_step({"id": "pull_the_main"}, 0.0)
	_check("opening the main kills the panel",
			panel.main_open and not panel.panel_live())
	panel.preview_maintenance_step({"id": "match_the_wire"}, 0.34)
	_check("the rating cannot be changed with the old plug still in its base",
			panel.fitted_rating == 30 and panel.balking())
	panel.preview_maintenance_step({"id": "draw_the_plug"}, 0.55)
	_check("with the main open the plug comes out", panel.plug_out)
	panel.preview_maintenance_step({"id": "match_the_wire"}, 0.90)
	_check("A BIGGER PLUG IS REFUSED: it is the fault, not the repair",
			panel.fitted_rating == 30 and panel.balking())
	# The refusal has to be VISIBLE while frozen, not a shudder that only
	# exists while the clock runs -- otherwise it cannot be photographed.
	_check("and the rejected plug is held at the base where it can be seen",
			panel.offered_rating == 30
			and (panel.get_node("RejectedPlug") as MeshInstance3D).visible)
	panel.preview_maintenance_step({"id": "match_the_wire"}, 0.55)
	_check("and so is a twenty on a fifteen-ampere conductor",
			panel.fitted_rating == 30 and panel.balking())
	panel.preview_maintenance_step({"id": "match_the_wire"}, 0.34)
	_check("a fifteen is accepted, because that is what the wire can carry",
			panel.fitted_rating == 15 and not panel.over_fused()
			and panel.offered_rating == 0
			and not (panel.get_node("RejectedPlug") as MeshInstance3D).visible)

	# PROVING.
	panel.preview_maintenance_step({"id": "prove_under_load"}, 0.88)
	_check("closing the main on a matched plug proves it under load",
			not panel.main_open and panel.load_proved
			and panel.protects_conductor())
	panel.restore_maintenance_snapshot(before)
	panel.preview_maintenance_step({"id": "prove_under_load"}, 0.88)
	_check("an over-fused panel carries the load perfectly and is still refused",
			panel.over_fused() and not panel.load_proved and panel.balking())
	panel.restore_maintenance_snapshot(before)
	panel.preview_maintenance_step({"id": "pull_the_main"}, 0.0)
	panel.preview_maintenance_step({"id": "draw_the_plug"}, 0.55)
	panel.preview_maintenance_step({"id": "prove_under_load"}, 0.88)
	_check("and an empty holder has nothing to prove",
			panel.plug_out and panel.balking())

	# PREVIEW PUBLISHES NOTHING.
	panel.restore_maintenance_snapshot(before)
	panel.preview_maintenance_step({"id": "read_the_stamp"}, 0.63)
	panel.preview_maintenance_step({"id": "pull_the_main"}, 0.0)
	panel.preview_maintenance_step({"id": "draw_the_plug"}, 0.55)
	panel.preview_maintenance_step({"id": "match_the_wire"}, 0.34)
	panel.preview_maintenance_step({"id": "prove_under_load"}, 0.88)
	_check("working the visible panel publishes nothing before the commit",
			not panel.panel_safe and panel.fitted_rating == 15)

	panel.restore_maintenance_snapshot(before)
	_check("abandonment restores every apparatus fact and clears the balk",
			panel.fitted_rating == 30 and not panel.main_open
			and not panel.plug_out and panel.stamp_read == 0.0
			and not panel.load_proved and not panel.panel_safe
			and not panel.balking() and panel.over_fused())

	# ONLY THE COMMIT RECORDS, and even it cannot bless an over-fused panel.
	var liar = FusePanelScript.new()
	add_child(liar)
	liar.apply_maintenance_result({
		"quality": "good", "note": "counterfeit",
		"mechanism_patch": {"panel_safe": true},
	})
	_check("no patch can call an over-fused panel safe",
			not liar.panel_safe and liar.over_fused())

	var reported: Array[Dictionary] = []
	panel.maintenance_completed.connect(
			func(r: Dictionary) -> void: reported.append(r))
	panel.apply_maintenance_result({
		"quality": "good",
		"note": "over-fused plug replaced with one rated to the conductor and proved under full load",
		"mechanism_patch": {"fitted_rating": 15, "main_open": false,
				"plug_out": false, "panel_safe": true},
	})
	_check("the guarded commit alone records the panel safe",
			panel.panel_safe and panel.protects_conductor()
			and not panel.over_fused() and not panel.plug_out)
	_check("the apparatus reports completion without advancing a work order",
			reported.size() == 1 and str(reported[0].quality) == "good")
	_check("the prompt stops asking to be read once it is right",
			not panel.control_prompt("panel").contains("Read"))

	_check("the panel is ray-reachable as a literal service point",
			panel.get_node_or_null("PanelReach") is PropControlArea)
	for part in ["SwitchJaws", "SwitchBlades", "SwitchHandle", "FuseBlock",
			"PlugFuse", "FuseWindow", "FuseLink", "RatingStamp",
			"CircuitCard", "ConductorTail", "SpareDrawer", "PanelDoor",
			"LampIndex", "RejectedPlug"]:
		_check("the apparatus shows its %s" % part,
				panel.get_node_or_null(NodePath(part)) is MeshInstance3D)
	_check("the apparatus owns no light and no collision body but its reach",
			panel.find_children("*", "Light3D", true, false).is_empty()
			and panel.find_children("*", "CollisionObject3D", true,
					false).size() == 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[FUSE FAIL] " + label)
	else:
		print("[fuse ok] " + label)


func _finish() -> void:
	print("MAINTENANCE FUSE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
