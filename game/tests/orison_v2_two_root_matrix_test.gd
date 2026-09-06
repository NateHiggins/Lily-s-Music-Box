extends Node

const Selector := preload("res://scripts/building/building_root_selector.gd")
const PROD_LAYOUT := "res://data/building_layout.json"
var failures := 0
var passes := 0
var run_id := Crypto.new().generate_random_bytes(8).hex_encode()
var calendar_direction_totals := {"v1_to_v1": 0, "v2_to_v2": 0,
		"v1_to_v2": 0, "v2_to_v1": 0}
var direction_totals := {"v1_to_v1": 0, "v2_to_v2": 0,
		"v1_to_v2": 0, "v2_to_v1": 0}
var inventory_direction_totals := {"v1_to_v1": 0, "v2_to_v2": 0,
		"v1_to_v2": 0, "v2_to_v1": 0}
var case_direction_totals := {"v1_to_v1": 0, "v2_to_v2": 0,
		"v1_to_v2": 0, "v2_to_v1": 0}

func _ready() -> void:
	var save_directory := ProjectSettings.globalize_path("user://tests")
	var directory_error := DirAccess.make_dir_recursive_absolute(save_directory)
	if directory_error != OK:
		push_error("Two-root matrix test save directory could not be created: %s (error %d)" %
				[save_directory, directory_error])
		get_tree().quit(2)
		return
	var layout_hash := FileAccess.get_sha256(PROD_LAYOUT)
	var saved_nodes := AcousticGraphData.nodes.duplicate(true)
	var saved_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests("v2")
	_check(Selector.scene_path().ends_with("orison_v2_runtime.tscn"), "explicit v2 selection")
	Selector.reset_for_tests("v1")
	_check(Selector.scene_path().ends_with("orison_root.tscn"), "explicit v1 selection")
	Selector.reset_for_tests()
	_check(Selector.DEFAULT_ID == "v1", "absent selector committed default is v1")
	_check(Selector.path_for("invalid") == Selector.PATHS.v1, "invalid selector safely resolves v1")
	await _exercise_v1_root()
	Selector.reset_for_tests("v2")
	var selected_scene := load(Selector.scene_path()) as PackedScene
	var v2_started := Time.get_ticks_usec()
	var world := selected_scene.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	var v2_total_ms := float(Time.get_ticks_usec() - v2_started) / 1000.0
	var interaction_started := Time.get_ticks_usec()
	var porter_prompt := (world.find_child("LobbyPorterBoard", true, false) as OtisProp).interact_prompt()
	var interaction_ms := float(Time.get_ticks_usec() - interaction_started) / 1000.0
	print("[M08D V2 PERF] cold_total_ms=%.3f compose_ms=%.3f nodes=%d collisions=%d first_interaction_ms=%.3f cpu_ms=%.3f physics_ms=%.3f" % [
			v2_total_ms, world.startup_ms, _count_nodes(world),
			world.find_children("*", "CollisionObject3D", true, false).size(), interaction_ms,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_check(not porter_prompt.is_empty(), "first production interaction responds")
	_check(not world.startup_failed and world.is_in_group("orison_v2_runtime"), "v2 production root starts")
	_check(absf(float(world.open_shift_ecosystem.now_minutes())
			- world.campaign_clock.absolute_minutes()) < 0.00001
			and get_tree().get_nodes_in_group("campaign_time_owner").size() == 1,
			"v2 root consumes absolute campaign time with one automatic owner")
	_check(world.adapter.resolves_required_uniquely(), "all first-slice anchors resolve once")
	_check(world.player is PlayerController and world.player.get_node_or_null("PauseServices") != null,
			"production player and pause/accessibility surface composed")
	_check(world.find_child("LobbyMailBank", true, false) is MailBankProp
			and world.find_child("LobbyPorterBoard", true, false) is OtisProp
			and world.find_child("F01_HOUSE_TELEPHONE_BOARD", true, false) is HouseSwitchboardProp
			and world.find_child("LobbyServiceDumbwaiter", true, false) is DumbwaiterProp,
			"F01 production interaction implementations composed")
	_check(world.chirp_hunt != null and world.work_orders != null and world.mina_gameplay != null
			and AcousticGraphData.nodes.has("F02_A_MONITOR_01"), "F02 job/case/chirp/acoustic owners composed")
	_check(world.call_interface != null and world.virus_director != null
			and world.find_child("F04_B_MONITOR_01", true, false) is SignalTerminalProp
			and AcousticGraphData.nodes.has("F04_B_MONITOR_01"), "F04 call/audio owners composed")
	var wake := world.core_loop.resolve_return_anchor()
	_check(str(wake.get("id", "")) == "F04_B_BED", "v2 wake uses explicit bedside semantic stance")
	_check(_one(world, "WorkOrders") and _one(world, "CallInterface") and _one(world, "ChirpHunt"),
			"no duplicate gameplay authorities")
	var forced: bool = world.adapter.install_acoustic_overrides(["F04_B_MONITOR_01", "MISSING"])
	_check(not forced and AcousticGraphData.nodes == saved_nodes, "forced adapter failure restores global state")
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(AcousticGraphData.nodes == saved_nodes, "success teardown restores global state")
	for pair: Array in [["v1", "v1"], ["v2", "v2"],
			["v1", "v2"], ["v2", "v1"]]:
		await _cross_root_reconstruction(pair[0], pair[1])
	_check(FileAccess.get_sha256(PROD_LAYOUT) == layout_hash, "production layout remains byte-stable")
	RealityState.persistence_enabled = saved_persistence
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests()
	print("ORISON V2 TWO-ROOT MATRIX: %s totals=%s calendar_totals=%s inventory_totals=%s case_totals=%s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures,
			direction_totals, calendar_direction_totals, inventory_direction_totals, case_direction_totals, passes + failures])
	get_tree().quit(failures)

func _exercise_v1_root() -> void:
	Selector.reset_for_tests("v1")
	var started := Time.get_ticks_usec()
	var packed := load(Selector.scene_path()) as PackedScene
	var root := packed.instantiate()
	add_child(root)
	await get_tree().physics_frame
	print("[M08D V1 PERF] cold_total_ms=%.3f nodes=%d collisions=%d" % [
			float(Time.get_ticks_usec() - started) / 1000.0, _count_nodes(root),
			root.find_children("*", "CollisionObject3D", true, false).size()])
	_check(root.is_in_group("building_root"), "v1 selector instantiates complete production root")
	_check(absf(float(root.open_shift_ecosystem.now_minutes())
			- root.campaign_clock.absolute_minutes()) < 0.00001
			and get_tree().get_nodes_in_group("campaign_time_owner").size() == 1,
			"v1 root consumes absolute campaign time with one automatic owner")
	_check(root.get("player") is PlayerController, "v1 production player constructed")
	_check(_one(root, "FirstShiftDirector") and _one(root, "ServiceRoundDirector")
			and _one(root, "WorkOrders") and _one(root, "CoreLoopDirector"),
			"v1 authority census has one route owner each")
	var v1_wake: Dictionary = root.get("core_loop").resolve_return_anchor()
	_check(str(v1_wake.get("id", "")) == "F04_B_BED", "v1 anonymous-bed fallback remains reconstructable")
	remove_child(root)
	root.free()
	packed = null
	await get_tree().process_frame
	await get_tree().process_frame

func _cross_root_reconstruction(from_id: String, to_id: String) -> void:
	var old_clock_frozen := bool(CampaignTime.get("_frozen_for_tests"))
	CampaignTime.set_frozen_for_tests(true)
	var key := "%s_to_%s" % [from_id, to_id]
	var old_path := RealityState.save_path
	var old_persistence := RealityState.persistence_enabled
	# The crash-safe writer retains sidecars. Each run owns a fresh namespace;
	# deleting only the primary leaves a recovery set that must be protected.
	var save_path := "user://tests/m08d_%s_%s.json" % [run_id, key]
	RealityState.save_path = save_path
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	var clock_seeded := clock.configure_date(1928, 11, 10, 1439) \
			and clock.advance_to(181.5)
	var expected_clock: Dictionary = JSON.parse_string(JSON.stringify(
			RealityState.data.campaign_clock))
	var expected_absolute := clock.absolute_minutes()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE,
			"report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
	RealityState.data.core_loop = {"safe_return_anchor": "F04_B_BED",
			"boundary": "wake_complete"}
	Selector.reset_for_tests(from_id)
	var origin_shell := CampaignShell.new()
	add_child(origin_shell)
	await get_tree().process_frame
	var origin_ok := origin_shell.active_world != null and (
			origin_shell.active_world.is_in_group("orison_v2_runtime") == (from_id == "v2"))
	var origin_clock_ok := _calendar_record_matches(expected_clock) \
			and _bound_calendar_matches(origin_shell.active_world, expected_absolute)
	var orders: WorkOrders = origin_shell.active_world.get("work_orders")
	var service: MaintenanceShopService = origin_shell.active_world.get("shop_service")
	var job := "vantry_chirp_2a"
	var acquired := orders.issue_job(job, "reported") and orders.acknowledge_job(job) \
			and orders.diagnose_job(job) and orders.mark_job_awaiting_part(job) \
			and service.counter("hardware_paint") != null \
			and service.acquire("carbon_transmitter_capsule", "hardware_paint")
	var expected_item: Dictionary = JSON.parse_string(JSON.stringify(
			service.inventory.item_state("carbon_transmitter_capsule")))
	var case_owner: MinaCaseGameplay = origin_shell.active_world.get("mina_gameplay")
	var case_started := RealityCases.activate_case(MinaCaseGameplay.CASE_ID)
	for i in MinaCaseGameplay.EVIDENCE.size():
		var spec: Dictionary = MinaCaseGameplay.EVIDENCE[i]
		for choice in (spec.choices as Array).find(spec.fact)+1:
			case_owner.evidence_nodes[i].interact(origin_shell.active_world.get("player"))
	var expected_case_changes: Array = RealityState.case_state(MinaCaseGameplay.CASE_ID).apartment_changes.duplicate(true)
	var case_seeded := case_started and case_owner._inspection_count(RealityState.case_state(MinaCaseGameplay.CASE_ID)) == 3
	var save_started := Time.get_ticks_usec()
	var saved := RealityState.save_game()
	var save_ms := float(Time.get_ticks_usec() - save_started) / 1000.0
	remove_child(origin_shell)
	origin_shell.free()
	await get_tree().process_frame
	await get_tree().process_frame
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var loaded: bool = not RealityState.data.first_shift.is_empty()
	var loaded_clock_ok := _calendar_record_matches(expected_clock)
	Selector.reset_for_tests(to_id)
	var reconstruction_started := Time.get_ticks_usec()
	var shell := CampaignShell.new()
	add_child(shell)
	await get_tree().process_frame
	var reconstruction_ms := float(Time.get_ticks_usec() - reconstruction_started) / 1000.0
	print("[M08D SAVE PERF] %s save_ms=%.3f reconstruct_ms=%.3f" % [
			key, save_ms, reconstruction_ms])
	var selected_ok := shell.active_world != null and (
			shell.active_world.is_in_group("orison_v2_runtime") == (to_id == "v2"))
	var shift: Dictionary = RealityState.data.first_shift
	var loop: Dictionary = RealityState.data.core_loop
	var semantic_ok := str(shift.get("phase", "")) == FirstShiftDirector.PHASE_COMPLETE \
			and str(shift.get("report_id", "")) == ChirpHunt.JOB_ID \
			and str(shift.get("filing", "")) == "fault_corrected" \
			and str(loop.get("safe_return_anchor", "")) == "F04_B_BED" \
			and str(loop.get("boundary", "")) == "wake_complete"
	var ok: bool = origin_ok and saved and loaded and selected_ok and semantic_ok
	direction_totals[key] = 1 if ok else 0
	_check(ok, "%s save reconstructs semantic facts through CampaignShell" % key)
	var calendar_ok := clock_seeded and origin_clock_ok and loaded_clock_ok \
			and _calendar_record_matches(expected_clock) \
			and _bound_calendar_matches(shell.active_world, expected_absolute)
	calendar_direction_totals[key] = 1 if calendar_ok else 0
	_check(calendar_ok, "%s preserves exact calendar epoch/start/elapsed through real roots" % key)
	var restored_service: MaintenanceShopService = shell.active_world.get("shop_service")
	var restored_item: Dictionary = JSON.parse_string(JSON.stringify(
			restored_service.inventory.item_state("carbon_transmitter_capsule")))
	var inventory_ok := acquired and not expected_item.is_empty() and restored_item == expected_item \
			and restored_service.counter("hardware_paint") != null \
			and not restored_service.acquire("carbon_transmitter_capsule", "hardware_paint")
	inventory_direction_totals[key] = 1 if inventory_ok else 0
	_check(inventory_ok, "%s preserves acquired capsule provenance and rejects duplicate acquisition" % key)
	var restored_case: Dictionary = RealityState.case_state(MinaCaseGameplay.CASE_ID)
	var restored_case_owner: MinaCaseGameplay = shell.active_world.get("mina_gameplay")
	var case_ok: bool = case_seeded and restored_case.get("apartment_changes",[]) == expected_case_changes \
			and restored_case_owner._inspection_count(restored_case) == 3
	restored_case_owner.evidence_nodes[0].interact(shell.active_world.get("player"))
	case_ok = case_ok and restored_case_owner._selected_caption(
			RealityState.case_state(MinaCaseGameplay.CASE_ID),"caption_cards") == "FAILURE"
	case_direction_totals[key] = 1 if case_ok else 0
	_check(case_ok,"%s preserves factual captions and continues the saved choice cycle" % key)
	remove_child(shell)
	shell.free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[M08D SAVE EVIDENCE] ", ProjectSettings.globalize_path(save_path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = old_persistence
	CampaignTime.set_frozen_for_tests(old_clock_frozen)

func _calendar_record_matches(expected: Dictionary) -> bool:
	# JSON changes integer variants to floats; every persisted key/value must
	# otherwise match exactly, including epoch, start minute, elapsed and zone.
	var restored: Variant = JSON.parse_string(JSON.stringify(
			RealityState.data.get("campaign_clock", {})))
	return restored is Dictionary and restored == expected

func _bound_calendar_matches(world: Node, expected_absolute: float) -> bool:
	if world == null:
		return false
	var bound := world.get("campaign_clock") as CampaignClock
	if bound == null or not bound.bind_state():
		return false
	var info := bound.day_info()
	return absf(bound.absolute_minutes() - expected_absolute) < 0.00001 \
			and absf(bound.elapsed_minutes() - 181.5) < 0.00001 \
			and absf(bound.minute_of_day() - 180.5) < 0.00001 \
			and bool(info.get("valid", false)) \
			and int(info.get("year", -1)) == 1928 \
			and int(info.get("month", -1)) == 11 \
			and int(info.get("day_of_month", -1)) == 11 \
			and str(info.get("day", "")) == "sun"

func _one(root: Node, named: String) -> bool:
	return root.find_children(named, "", true, false).size() == 1

func _count_nodes(root: Node) -> int:
	var total := 1
	for child: Node in root.get_children():
		total += _count_nodes(child)
	return total

func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
