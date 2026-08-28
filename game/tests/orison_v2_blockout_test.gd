extends Node

const LAYOUT_PATH := "res://data/orison_v2_blockout.json"
const SCENE_PATH := "res://scenes/building/orison_v2_blockout.tscn"

var failures := 0

func _ready() -> void:
	var production_hash_before := FileAccess.get_sha256("res://data/building_layout.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_check(parsed is Dictionary, "v2 layout parses")
	if not parsed is Dictionary:
		_finish()
		return
	var layout: Dictionary = parsed
	_check(not bool(layout.get("production_default", true)), "v2 is development-only")
	_check(layout.get("layout_id", "") == "orison_v2_h_plan_blockout_01",
			"accepted H-plan identity is stable")
	_check(layout.levels.size() == 3, "first slice declares F01, F02 and F04")
	_check(layout.spaces.size() == 31, "31 programmed blockout spaces")
	_check(layout.doors.size() == 4, "four required first-slice leaves")
	_check(layout.anchors.size() == 16, "sixteen named gameplay/review anchors")
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "v2 scene loads independently")
	if packed != null:
		var root := packed.instantiate()
		add_child(root)
		await get_tree().process_frame
		_check(root.failures.is_empty(), "schema validation passes")
		_check(root.is_in_group("orison_v2_blockout"), "explicit v2 selector group")
		for ident in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
				"F02_A_MAIN_VANTRY_POINT", "F04_B_MONITOR_01", "F04_B_BED",
				"LobbyMailBank", "LobbyPorterBoard", "F01_HOUSE_TELEPHONE_BOARD",
				"LobbyServiceDumbwaiter"]:
			_check(root.get_node_or_null(ident) != null, "anchor/door resolves: " + ident)
		for ident in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03"]:
			var hinge := root.get_node("%s/Hinge" % ident) as Node3D
			_check(hinge != null and absf(hinge.rotation.y) > 1.5,
					"route leaf has a complete open hinge: " + ident)
		_check((root.get_node("F02_A_MAIN_VANTRY_POINT") as Node3D).global_position
				.is_equal_approx(Vector3(-10.1, 4.45, 1.4)), "2A Vantry transform derives from schema")
		_check((root.get_node("F04_B_BED") as Node3D).global_position
				.is_equal_approx(Vector3(-13.1, 10.15, 8.9)), "4B bed transform derives from schema")
		_check(root.get_node_or_null("WEST_WET_STACK") != null,
				"wet stack is continuous geometry")
		_check(root.get_node_or_null("SERVICE_LIFT_SHAFT") != null,
				"service lift is continuous geometry")
		root.queue_free()
	_check(FileAccess.get_sha256("res://data/building_layout.json") == production_hash_before,
			"production layout remains byte-stable")
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)

func _finish() -> void:
	print("ORISON V2 BLOCKOUT TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)
