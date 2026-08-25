extends Node
## SR7-A — the service dumbwaiter's automatic holding brake.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/MaintenanceDumbwaiterTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things are proved here and kept apart on purpose:
##
##   the BOOK   the authored activity satisfies the shared schema, teaches one
##              transferable verb and stays inside the 3-12 second window;
##   the RUN    the shared run enforces the physical order, rejects the three
##              real mistakes and recovers immediately rather than restarting;
##   the PROP   the mechanism previews reversibly, publishes nothing before the
##              guarded commit, and owns no job, case or Dream fact.
##
## The production-root placement is proved separately in
## `maintenance_dumbwaiter_live_test.gd`, because building the whole Orison is
## a different kind of run from checking a data book.

const ACTIVITY := "dumbwaiter_brake_service"
const ORDER := ["take_strain", "ease_pawl", "prove_balance", "seat_band",
		"prove_bite"]

var checks := 0
var failures := 0


func _ready() -> void:
	_book()
	_run()
	_prop()
	_finish()


# --- the book ---------------------------------------------------------------

func _book() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check("the shared activity book still validates whole (%s)"
			% ", ".join(library.errors), library.is_valid())
	_check("the dumbwaiter brake is authored in the shared book",
			library.has_activity(ACTIVITY))
	if not library.has_activity(ACTIVITY):
		return
	var authored := library.activity(ACTIVITY)

	var ids: Array[String] = []
	var total := 0.0
	var verbs := {}
	for step in (authored.steps as Array):
		ids.append(str((step as Dictionary).id))
		total += float((step as Dictionary).expected_seconds)
		verbs[str((step as Dictionary).verb)] = true
	_check("the authored order is strain, pawl, movement, band, bite (%s)"
			% ", ".join(ids), ids == ORDER)
	_check("every verb is one the shared abstraction already speaks (%s)"
			% ", ".join(verbs.keys()),
			verbs.keys().all(func(v): return v in MaintenanceActivityLibrary.VERBS))
	# Each step is individually inside the WarioWare window; the chain is
	# allowed to be longer than one step, which is what a five-verb chain means.
	var each_ok := true
	for step in (authored.steps as Array):
		var seconds := float((step as Dictionary).expected_seconds)
		each_ok = each_ok and seconds >= 3.0 and seconds <= 12.0
	_check("every verb is a 3-12 second physical action (chain %.0f s)" % total,
			each_ok)
	_check("the transferable verb is regulation, and the source is the 1910 patent",
			str(authored.transferable_verb) == "regulation"
			and str(authored.historical_source).contains("950,828"))
	_check("the two held steps are the two that carry load",
			str((authored.steps[0] as Dictionary).verb) == "hold_release"
			and str((authored.steps[4] as Dictionary).verb) == "hold_release"
			and float((authored.steps[0] as Dictionary).hold_min_seconds) > 0.0
			and float((authored.steps[4] as Dictionary).hold_min_seconds) > 0.0)
	# The book must not have grown a job, case, resident or Dream fact.
	var forbidden := ["job", "job_id", "case", "case_id", "resident",
			"resident_id", "work_order", "dream", "stage", "save"]
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

	# THE HAPPY CHAIN, in order.
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
	_check("the committed result carries the mechanism patch and no job",
			completed.size() == 1
			and (completed[0].get("mechanism_patch", {}) as Dictionary).get(
					"band_seated", false) == true
			and not completed[0].has("job_id"))

	# THE THREE REAL MISTAKES. Each must be refused, must name itself, and must
	# leave the chain exactly where it was so the player simply tries again.
	for case in [
			{"label": "reaching for the pawl before taking the strain",
				"verb": "align", "reason": "wrong_verb"},
			{"label": "taking the strain outside the rope's detent",
				"verb": "hold_release", "reason": "outside_detent"},
			{"label": "letting the strain go early",
				"verb": "hold_release", "reason": "released_early"}]:
		var probe := MaintenanceActivityRun.new()
		var reasons: Array[String] = []
		probe.input_rejected.connect(
				func(reason: String, _s: Dictionary) -> void:
					reasons.append(reason))
		probe.start(ACTIVITY, authored)
		var first := authored.steps[0] as Dictionary
		var value := float(first.target)
		var hold := float(first.hold_min_seconds) + 0.4
		if str(case.reason) == "outside_detent":
			value = clampf(value + float(first.tolerance) + 0.25, 0.0, 1.0)
		if str(case.reason) == "released_early":
			hold = float(first.hold_min_seconds) * 0.25
		var accepted: bool = probe.submit(str(case.verb), value, hold)
		_check("%s is refused as %s and the chain does not move"
				% [str(case.label), str(case.reason)],
				not accepted and reasons.size() == 1
				and reasons[0] == str(case.reason)
				and probe.step_index == 0 and not probe.committed)

	# RECOVERY. After a refusal the very next correct verb still lands, so a
	# mistake costs the slip and nothing else.
	var recover := MaintenanceActivityRun.new()
	recover.start(ACTIVITY, authored)
	var first_step := authored.steps[0] as Dictionary
	recover.submit("align", 0.5, 0.0)
	var recovered := recover.submit(str(first_step.verb),
			float(first_step.target),
			float(first_step.hold_min_seconds) + 0.4)
	_check("a refused verb does not restart the chain: the next correct one lands",
			recovered and recover.step_index == 1 and not recover.committed)

	# ABORT stays reversible and publishes nothing.
	var abandoned := MaintenanceActivityRun.new()
	var closed: Array[String] = []
	abandoned.aborted.connect(
			func(id: String) -> void: closed.append(id))
	abandoned.start(ACTIVITY, authored)
	abandoned.submit(str(first_step.verb), float(first_step.target),
			float(first_step.hold_min_seconds) + 0.4)
	_check("abort is reversible and commits nothing",
			abandoned.abort() and closed.size() == 1
			and not abandoned.committed and abandoned.result.is_empty())

	# ACCESSIBILITY. Both demands this chain makes -- a fine detent and a held
	# release -- must have an alternative. `precision_scale` widens the detent;
	# `hold_assist` DIVIDES the required hold, so larger is more forgiving.
	var assisted := MaintenanceActivityRun.new()
	assisted.start(ACTIVITY, authored,
			{"precision_scale": 2.5, "hold_assist": 4.0})
	var wide := float(first_step.target) + float(first_step.tolerance) * 1.6
	var brief := float(first_step.hold_min_seconds) / assisted.hold_assist + 0.05
	_check("a wide detent and a short hold both still land the first verb",
			assisted.precision_scale > 1.0 and assisted.hold_assist > 1.0
			and assisted.submit(str(first_step.verb), wide, brief))
	# The assistance is a widening, not a removal: a value outside even the
	# widened detent is still refused, so the mechanism keeps its shape.
	var far := MaintenanceActivityRun.new()
	far.start(ACTIVITY, authored, {"precision_scale": 2.5})
	_check("and assistance widens the detent without abolishing it",
			not far.submit(str(first_step.verb),
					clampf(float(first_step.target) + float(first_step.tolerance)
							* 2.5 + 0.1, 0.0, 1.0),
					float(first_step.hold_min_seconds) + 0.4))


# --- the prop ---------------------------------------------------------------

func _prop() -> void:
	var prop := DumbwaiterProp.new()
	prop.name = "TestDumbwaiter"
	add_child(prop)

	var before := prop.maintenance_snapshot()
	_check("the mechanism starts with the fault the round exists to correct",
			not prop.band_seated)

	# Preview moves the visible mechanism and publishes nothing.
	prop.preview_maintenance_step({"id": "take_strain"}, 0.58)
	prop.preview_maintenance_step({"id": "ease_pawl"}, 0.71)
	prop.preview_maintenance_step({"id": "prove_balance"}, 0.34)
	prop.preview_maintenance_step({"id": "seat_band"}, 0.88)
	_check("working the visible mechanism publishes nothing before the commit",
			not prop.band_seated
			and prop.rope_strain > 0.0 and prop.pawl_lift > 0.0)
	_check("the counterweight answers the car in the opposite direction",
			prop.car_travel > 0.0)

	# The mechanical truth, enforced: the pawl will not come clear against a
	# slack rope, and it says so immediately.
	var slack := DumbwaiterProp.new()
	add_child(slack)
	slack.preview_maintenance_step({"id": "ease_pawl"}, 0.71)
	_check("easing the pawl against a slack rope slips instead of lifting",
			slack.pawl_lift == 0.0 and slack.slipping())
	slack.preview_maintenance_step({"id": "prove_balance"}, 0.34)
	_check("and nothing travels while the pawl is still doing the holding",
			slack.car_travel == 0.0)
	# Spending the strain before the band is home reads immediately.
	var early := DumbwaiterProp.new()
	add_child(early)
	early.preview_maintenance_step({"id": "prove_bite"}, 0.20)
	_check("letting go before the band bites slips readably", early.slipping())

	# Abort restores every mechanism fact.
	prop.restore_maintenance_snapshot(before)
	_check("abandonment restores every mechanism fact and clears the slip",
			not prop.band_seated and prop.rope_strain == 0.0
			and prop.pawl_lift == 0.0 and prop.car_travel == 0.0
			and not prop.slipping())

	# Only the guarded commit publishes.
	var reported: Array[Dictionary] = []
	prop.maintenance_completed.connect(
			func(r: Dictionary) -> void: reported.append(r))
	prop.apply_maintenance_result({
		"quality": "good",
		"note": "pawl freed; band reseated and proved under load",
		"mechanism_patch": {"band_seated": true, "pawl_lift": 0.0,
				"rope_strain": 0.0, "brake_bite": DumbwaiterProp.BAND_HOME},
	})
	_check("the guarded commit seats the band through the public setters",
			prop.band_seated
			and is_equal_approx(prop.brake_bite, DumbwaiterProp.BAND_HOME)
			and prop.pawl_lift == 0.0)
	_check("the mechanism reports completion without advancing a work order",
			reported.size() == 1 and str(reported[0].quality) == "good")
	_check("the brake is ray-reachable as a literal service point",
			prop.get_node_or_null("BrakeReach") is Area3D)
	_check("the prop owns no light and no collision body",
			prop.find_children("*", "Light3D", true, false).is_empty()
			and prop.find_children("*", "CollisionObject3D", true,
					false).size() == prop.find_children("*", "Area3D", true,
					false).size())


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[DUMBWAITER FAIL] " + label)
	else:
		print("[dumbwaiter ok] " + label)


func _finish() -> void:
	print("MAINTENANCE DUMBWAITER TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
