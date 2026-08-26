extends Node

const TEST_PATH := "user://tests/reality_future_save_test.json"
var passed := 0
var failed := 0
var old_path := ""
var old_persistence := true


func _ready() -> void:
	old_path = RealityState.save_path
	old_persistence = RealityState.persistence_enabled
	RealityState.save_path = TEST_PATH
	RealityState.persistence_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var future := '{"version":99,"intro_complete":true,"future_fact":"keep me"}'
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(future)
	file = null

	RealityState.load_game()
	_check(RealityState.save_write_blocked, "future save blocks writes")
	_check(RealityState.incompatible_save_version == 99, "future version is named")
	_check(not bool(RealityState.data.intro_complete), "future data is not merged")
	_check(not RealityState.data.has("future_fact"), "unknown future facts stay out of runtime")
	var before := FileAccess.get_file_as_string(TEST_PATH)
	RealityState.data.intro_complete = true
	RealityState.commit()
	_check(FileAccess.get_file_as_string(TEST_PATH) == before,
			"commit preserves future save byte for byte")

	RealityState.start_new_campaign()
	var replacement: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(not RealityState.save_write_blocked, "explicit new campaign releases latch")
	_check(replacement is Dictionary and int(replacement.get("version", 0)) ==
			RealityState.SAVE_VERSION, "explicit new campaign writes current version")

	RealityState.save_path = old_path
	RealityState.persistence_enabled = old_persistence
	RealityState.reset_campaign_for_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("[SAVE COMPAT] PASS %d/%d" % [passed, passed + failed] if failed == 0
			else "[SAVE COMPAT] FAIL %d/%d" % [failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("  PASS ", label)
	else:
		failed += 1
		print("  FAIL ", label)
