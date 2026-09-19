extends Node
## Red/green contract using only APIs that already exist in the original build.
## Run against preserved original RealityState, then the proposed implementation.
## Assertions require protection, never the known destructive behavior.

const PATH := "user://tests/reality_invalid_load_control/save.json"
var failures := 0


func _ready() -> void:
	var previous_path := RealityState.save_path
	var previous_persistence := RealityState.persistence_enabled
	RealityState.save_path = PATH
	RealityState.persistence_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	for body in ["{", "[]", '{"version":4,"maintenance_jobs":[]}']:
		for suffix in ["", ".tmp", ".bak", ".txn"]:
			if FileAccess.file_exists(PATH + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		file.store_string(body)
		file.close()
		RealityState.load_game()
		_check(RealityState.save_write_blocked, "invalid load holds write latch: " + body)
		RealityState.data.intro_complete = true
		RealityState.commit()
		_check(FileAccess.get_file_as_string(PATH) == body, "ordinary commit preserves invalid original bytes")
	RealityState.save_path = previous_path
	RealityState.persistence_enabled = previous_persistence
	RealityState.reset_campaign_for_tests()
	for suffix in ["", ".tmp", ".bak", ".txn"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	print("[INVALID LOAD CONTROL] ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", label)
