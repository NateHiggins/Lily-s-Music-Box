extends Node

const Selector := preload("res://scripts/building/building_root_selector.gd")
const RUNTIME := preload("res://scenes/building/orison_v2_runtime.tscn")
const PROD_LAYOUT := "res://data/building_layout.json"
var failures := 0

func _ready() -> void:
	var layout_hash := FileAccess.get_sha256(PROD_LAYOUT)
	var saved_nodes := AcousticGraphData.nodes.duplicate(true)
	Selector.reset_for_tests("v2")
	_check(Selector.scene_path().ends_with("orison_v2_runtime.tscn"), "explicit v2 selection")
	Selector.reset_for_tests("v1")
	_check(Selector.scene_path().ends_with("orison_root.tscn"), "explicit v1 selection")
	Selector.reset_for_tests()
	_check(Selector.DEFAULT_ID == "v1", "absent selector committed default is v1")
	_check(Selector.path_for("invalid") == Selector.PATHS.v1, "invalid selector safely resolves v1")
	Selector.reset_for_tests("v2")
	var world := RUNTIME.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
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
	_check(FileAccess.get_sha256(PROD_LAYOUT) == layout_hash, "production layout remains byte-stable")
	Selector.reset_for_tests()
	print("ORISON V2 TWO-ROOT MATRIX: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)

func _one(root: Node, named: String) -> bool:
	return root.find_children(named, "", true, false).size() == 1

func _check(ok: bool, label: String) -> void:
	if ok: print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
