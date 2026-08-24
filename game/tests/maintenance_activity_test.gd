extends Node
## First Service Round gate: data, transient hand-work and ownership seams.

var failures := 0


func _ready() -> void:
	var library := MaintenanceActivityLibrary.load_default()
	_check(library.is_valid(), "maintenance activity book validates")
	_check(library.activity_ids() == (["annunciator_flag_service",
			"boiler_water_column_test", "radiator_vent_service"] as Array[String]),
			"the first round is apartment, lobby and basement")
	_check({
		"radiator_vent_service": "flow",
		"annunciator_flag_service": "contact",
		"boiler_water_column_test": "pressure",
	} == _transferable_verbs(library),
			"each period mechanism names one transferable physical verb")
	for activity_id in library.activity_ids():
		var activity := library.activity(activity_id)
		var steps: Array = activity.steps
		_check(steps.size() >= 3, "%s is a chain, not one long dexterity test"
				% activity_id)
		for step in steps:
			_check(float(step.expected_seconds) >= 3.0
					and float(step.expected_seconds) <= 12.0,
					"%s.%s stays inside the ultra-short band"
					% [activity_id, str(step.id)])

	_prove_run_contract(library)
	_prove_temporal_boundary(library)
	_prove_accessibility(library)
	_prove_director_boundary(library)
	print("MAINTENANCE ACTIVITY TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _transferable_verbs(library: MaintenanceActivityLibrary) -> Dictionary:
	var mapped := {}
	for activity_id in library.activity_ids():
		mapped[activity_id] = str(library.activity(activity_id).get(
				"transferable_verb", ""))
	return mapped


func _prove_temporal_boundary(library: MaintenanceActivityLibrary) -> void:
	var invalid := MaintenanceActivityLibrary.new()
	var record := library.activity("radiator_vent_service")
	record.transferable_verb = "prophecy"
	invalid._validate_activity("bad_future_reading", record)
	_check(not invalid.is_valid(),
			"arbitrary future readings cannot enter the maintenance vocabulary")
	_check(not library.activity("radiator_vent_service").has("dream_owner")
			and not library.activity("radiator_vent_service").has("case_truth")
			and not library.activity("radiator_vent_service").has("save_fact"),
			"the waking tag creates no Dream, case or persistence owner")


func _prove_run_contract(library: MaintenanceActivityLibrary) -> void:
	var run := MaintenanceActivityRun.new()
	_check(run.start("radiator_vent_service",
			library.activity("radiator_vent_service")), "run starts from authored data")
	_check(not run.submit("align", 0.0) and run.step_index == 0,
			"wrong verb gives feedback without advancing")
	_check(run.submit("turn", 0.0), "closed detent accepts")
	_check(not run.submit("hold_release", 0.5, 0.4) and run.step_index == 1,
			"early release does not mutate the sequence")
	_check(run.submit("hold_release", 0.5, 1.4)
			and run.submit("align", 0.72)
			and run.submit("turn", 1.0), "the four physical verbs complete")
	_check(run.committed and not run.running
			and str(run.result.quality) == "fair"
			and float(run.result.mechanism_patch.supply_position) == 1.0,
			"completion proposes a patch and grades recoverable misses")
	_check(not run.submit("turn", 1.0) and not run.abort(),
			"a committed run cannot be replayed or rolled back")

	var abandoned := MaintenanceActivityRun.new()
	abandoned.start("boiler_water_column_test",
			library.activity("boiler_water_column_test"))
	abandoned.submit("turn", 0.0)
	_check(abandoned.abort() and not abandoned.committed
			and abandoned.result.is_empty(),
			"abort before the final commit leaves no world patch")


func _prove_accessibility(library: MaintenanceActivityLibrary) -> void:
	var standard := MaintenanceActivityRun.new()
	standard.start("annunciator_flag_service",
			library.activity("annunciator_flag_service"))
	_check(not standard.submit("hold_release", 0.44, 0.4),
			"standard hold keeps the authored resistance")
	var assisted := MaintenanceActivityRun.new()
	assisted.start("annunciator_flag_service",
			library.activity("annunciator_flag_service"),
			{"hold_assist": 3.0, "precision_scale": 2.0})
	_check(assisted.submit("hold_release", 0.60, 0.4),
			"hold and precision assists change access, not authored steps")


func _prove_director_boundary(library: MaintenanceActivityLibrary) -> void:
	var director := MaintenanceActivityDirector.new()
	director.bind_library(library)
	add_child(director)
	var completions: Array[Dictionary] = []
	director.activity_completed.connect(
			func(_id: String, result: Dictionary) -> void:
				completions.append(result))
	_check(director.begin("boiler_water_column_test"),
			"director admits one known activity")
	_check(not director.begin("radiator_vent_service"),
			"director refuses a second simultaneous mechanism")
	_check(director.submit("turn", 0.0)
			and director.submit("hold_release", 0.5, 1.8)
			and director.submit("align", 0.62)
			and director.submit("turn", 1.0),
			"director routes inputs without owning their meaning")
	_check(completions.size() == 1 and director.active_run == null
			and not director.has_method("record_job_repair")
			and not director.has_method("apply_mechanism_patch"),
			"completion is only a signal; job and mechanism owners stay separate")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [activity ok] ", label)
	else:
		failures += 1
		printerr("  [ACTIVITY FAIL] ", label)
