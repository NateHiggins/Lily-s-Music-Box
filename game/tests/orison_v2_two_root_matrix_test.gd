extends Node

const Selector := preload("res://scripts/building/building_root_selector.gd")
const PROD_LAYOUT := "res://data/building_layout.json"
var failures := 0
var passes := 0
var direction_totals := {"v1_to_v1": 0, "v2_to_v2": 0,
		"v1_to_v2": 0, "v2_to_v1": 0}

func _ready() -> void:
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
	print("ORISON V2 TWO-ROOT MATRIX: %s totals=%s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures,
			direction_totals, passes + failures])
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
	var key := "%s_to_%s" % [from_id, to_id]
	var old_path := RealityState.save_path
	var old_persistence := RealityState.persistence_enabled
	var save_path := "user://tests/m08d_%s.json" % key
	RealityState.save_path = save_path
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()
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
	remove_child(shell)
	shell.free()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = old_persistence

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
