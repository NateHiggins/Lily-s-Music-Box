extends Node
## Focused duration/presence/owner proof. Optional legacy controls execute the
## preserved pre-repair source against the same duration or presence checks.

var failures := 0
var checks := 0
var minute := 100.0
var _saved_environment := {}
var _saved_persistence := false
var _saved_path := ""
const SAVE_PATH := "user://tests/world_time_coherence.json"

class ClockRoot extends Node3D:
	var startup_failed := false

class StaleEcosystem extends Node:
	func now_minutes() -> float:
		return 180.0


func _ready() -> void:
	_saved_persistence = RealityState.persistence_enabled
	_saved_path = RealityState.save_path
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for key in ["CAMPAIGN_TIME_FREEZE", "DAYNIGHT", "DAYNIGHT_FORCE",
			"SCHEDULE", "SCHEDULE_MINUTE", "SCHEDULE_DAY", "SCHEDULE_DOY"]:
		_saved_environment[key] = OS.get_environment(key)
		OS.set_environment(key, "")
	CampaignTime.set_process(false)
	CampaignTime.set_frozen_for_tests(false)
	var control := OS.get_environment("WORLD_TIME_LEGACY_CONTROL")
	if control == "duration":
		_test_durations(_legacy_script("game/scripts/game/open_shift_situation.gd",
				"OpenShiftSituation"))
	elif control == "presence":
		_test_presence(_legacy_script("game/scripts/building/orison_v2_runtime_root.gd",
				"OrisonV2RuntimeRoot"))
	else:
		_test_durations(preload("res://scripts/game/open_shift_situation.gd"))
		_test_presence(preload("res://scripts/building/orison_v2_runtime_root.gd"))
		_test_migration()
		_test_driver()
		_test_invalid_roots()
		await _test_v2_composition()
	_finish()


func _legacy_script(relative_path: String, declared_class: String) -> GDScript:
	var base := OS.get_environment("WORLD_TIME_LEGACY_SOURCE_DIR")
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(base.path_join(relative_path)) \
			.replace("class_name " + declared_class, "")
	_check(script.reload() == OK, "preserved legacy source compiles for control")
	return script


func _test_durations(script: GDScript) -> void:
	var situation = script.new()
	add_child(situation)
	minute = 100.0
	situation.setup("duration_fixture", func(): return minute)
	situation.offer("lena_ortiz")
	minute += 2885.0
	_check(absf(float(situation.elapsed_since("offered_at")) - 2885.0) < 0.00001,
			"two-day duration retains all 2885 minutes")
	minute = 1000000123.0
	situation.attend("inspection")
	_check(absf(float(situation.state().last_attended_at) - minute) < 0.00001,
			"absolute event timestamp retains its day")
	minute += 1446.0
	_check(absf(float(situation.elapsed_since("last_attended_at")) - 1446.0) < 0.00001,
			"attention duration does not wrap after midnight or a full day")
	situation.free()


func _test_presence(script: GDScript) -> void:
	var clock := CampaignClock.new()
	_check(clock.configure_date(1928, 11, 10, 1200), "Saturday20:00 campaign fixture configured")
	var timetable := ScheduleDirector.new()
	add_child(timetable)
	timetable.setup(null, {})
	var world = script.new()
	world.campaign_clock = clock
	world.resident_presence = timetable
	var stale := StaleEcosystem.new()
	world.open_shift_ecosystem = stale
	_check(not world.resident_is_home("lena_ortiz"),
			"V2 presence uses campaign Saturday20:00 bar visit, not stale03:00 ecosystem")
	clock.advance_to(1440.0)
	_check(world.resident_is_home("lena_ortiz"),
			"V2 presence distinguishes Sunday20:00 at home from Saturday bar visit")
	OS.set_environment("DAYNIGHT_FORCE", "03:00")
	_check(absf(ScheduleDirector.minute_now() - 1200.0) < 0.00001,
			"sky presentation override cannot change schedule minute")
	OS.set_environment("SCHEDULE_MINUTE", "05:20")
	_check(absf(ScheduleDirector.minute_now() - 320.0) < 0.00001,
			"explicit schedule test minute remains available")
	OS.set_environment("SCHEDULE_MINUTE", "")
	OS.set_environment("DAYNIGHT_FORCE", "")
	world.free()
	stale.free()
	timetable.free()


func _test_migration() -> void:
	minute = 210.0
	var situation := OpenShiftSituation.new()
	add_child(situation)
	situation.setup("legacy_fixture", func(): return minute)
	situation.offer("lena_ortiz")
	situation.accept()
	situation.attend("inspected_radiator")
	var raw: Dictionary = RealityState.data.open_shift_situations.legacy_fixture
	raw.erase("clock_schema_version")
	raw.erase("clock_basis")
	situation.free()
	minute = 1000000123.0
	situation = OpenShiftSituation.new()
	add_child(situation)
	situation.setup("legacy_fixture", func(): return minute, "campaign_absolute_minutes")
	var migrated := situation.state()
	_check(float(migrated.offered_at) == 210.0
			and float(migrated.clock_migration.original_timestamps.offered_at) == 210.0
			and "offered_at" in migrated.clock_migration.unresolved,
			"legacy facts and original timestamps survive with unresolved-day annotation")
	_check(situation.elapsed_since("offered_at") == 0.0,
			"ambiguous legacy offer cannot manufacture a neglect duration")
	situation.attend("returned")
	minute += 8.0
	_check(absf(situation.elapsed_since("last_attended_at") - 8.0) < 0.00001
			and "last_attended_at" not in situation.state().clock_migration.unresolved,
			"new attested attention establishes a valid deadline without resetting old facts")
	var ledger := NpcObservationLedger.new()
	add_child(ledger)
	RealityState.data.npc_observations = {"lena_ortiz": [{"learned": "old_fact",
			"channel": "in_home_sight", "where": "2B", "at_minutes": 210.0, "evidence": {}}]}
	ledger.setup([], func(): return minute, null, Callable(), "campaign_absolute_minutes")
	ledger.record_direct_observation("lena_ortiz", "new_fact", "in_home_sight", "2B", {})
	var beliefs := ledger.beliefs("lena_ortiz")
	_check(float(beliefs[0].at_minutes) == 210.0
			and str(beliefs[0].clock_basis) == "legacy_wrapped_minute_unknown_day"
			and absf(float(beliefs[1].at_minutes) - minute) < 0.00001,
			"observation history preserves unknown legacy days and dates new facts absolutely")
	var porter := PorterActor.new()
	add_child(porter)
	porter.setup(null, ledger)
	porter.consider("legacy_pending_visit", 1438.0)
	RealityState.data.porter_actor.erase("clock_schema_version")
	RealityState.data.porter_actor.erase("clock_basis")
	porter.free()
	porter = PorterActor.new()
	add_child(porter)
	porter.setup(null, ledger, Callable(), "campaign_absolute_minutes")
	porter.advance_to(minute)
	_check(float(porter.state().eligible_at) == 1438.0
			and float(porter.state().departed_at) == -1.0
			and str(porter.state().intent) == "legacy_pending_visit",
			"unknown legacy porter deadline retains intent without inventing departure")
	var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(SAVE_PATH).get_base_dir())
	_check(directory_error == OK, "migration save parent created by harness")
	RealityState.save_path = SAVE_PATH
	RealityState.persistence_enabled = true
	var saved := RealityState.save_game()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var back: Dictionary = RealityState.data.get("open_shift_situations", {}).get("legacy_fixture", {})
	_check(saved and float(back.get("offered_at", -1.0)) == 210.0
			and "offered_at" in back.get("clock_migration", {}).get("unresolved", []),
			"legacy timestamp ambiguity survives real save/load without reset")
	situation.free()
	porter.free()
	ledger.free()


func _test_driver() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 10, 180)
	var before := clock.elapsed_minutes()
	CampaignTime._process(60.0)
	_check(clock.elapsed_minutes() == before, "no waking root means no automatic campaign advance")
	var first := ClockRoot.new()
	add_child(first)
	first.add_to_group("building_root")
	var second := ClockRoot.new()
	add_child(second)
	second.add_to_group("building_root")
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("DAYNIGHT_FORCE", "day")
	CampaignTime._process(60.0)
	_check(absf(clock.elapsed_minutes() - before - 1.0) < 0.00001
			and get_tree().get_nodes_in_group("campaign_time_owner").size() == 1,
			"overlapping roots advance once despite presentation overrides")
	before = clock.elapsed_minutes()
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "1")
	CampaignTime._process(60.0)
	_check(clock.elapsed_minutes() == before, "explicit campaign freeze stops automatic advancement")
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "")
	get_tree().paused = true
	CampaignTime._process(60.0)
	get_tree().paused = false
	_check(clock.elapsed_minutes() == before, "game pause freezes campaign advancement")
	CampaignTime.set_frozen_for_tests(true)
	CampaignTime._process(60.0)
	_check(clock.elapsed_minutes() == before, "deterministic test freeze hook is independent of presentation")
	first.free()
	second.free()
	OS.set_environment("DAYNIGHT", "")
	OS.set_environment("DAYNIGHT_FORCE", "")


func _test_invalid_roots() -> void:
	for path in ["res://scenes/building/orison_root.tscn",
			"res://scenes/building/orison_v2_runtime.tscn"]:
		RealityState.reset_campaign_for_tests()
		RealityState.data.campaign_clock = {"schema_version": 999}
		var shell := CampaignShell.new()
		shell.waking_scene_path = path
		var announcements: Array = []
		shell.world_changed.connect(func(kind, _world): announcements.append(kind))
		add_child(shell)
		_check(shell.active_world == null and shell.world_child_count() == 0
				and announcements.is_empty(),
				"invalid calendar refuses active world publication: " + path.get_file())
		_check(RealityState.data.get("open_shift_situations", {}).is_empty()
				and RealityState.data.get("npc_observations", {}).is_empty(),
				"invalid calendar creates no ecosystem or knowledge: " + path.get_file())
		shell.free()


func _test_v2_composition() -> void:
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 10, 1200)
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	_check(not world.startup_failed and absf(float(world.open_shift_ecosystem.now_minutes())
			- clock.absolute_minutes()) < 0.00001,
			"real V2 root injects the absolute campaign clock into its ecosystem")
	_check(not world.resident_is_home("lena_ortiz"),
			"real V2 root resolves Saturday evening presence from campaign time")
	world.open_shift_ecosystem.situation.offer("lena_ortiz")
	clock.advance_to(2885.0)
	_check(absf(world.open_shift_ecosystem.situation.elapsed_since("offered_at")
			- 2885.0) < 0.00001,
			"real V2 situation retains multi-day duration on the shared provider")
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	PropAudio.clear_cache()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[WORLD TIME] %s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	RealityState.persistence_enabled = _saved_persistence
	RealityState.save_path = _saved_path
	RealityState.reset_campaign_for_tests()
	for key in _saved_environment:
		OS.set_environment(key, _saved_environment[key])
	CampaignTime.set_frozen_for_tests(false)
	CampaignTime.set_process(true)
	print("WORLD TIME COHERENCE: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
