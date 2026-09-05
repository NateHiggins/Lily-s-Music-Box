extends Node
## Windowed captures of actual title load states and button handlers.
## File failure and scene failure are explicit, separately recorded seams.

var screen: OrisonTitleScreen
var records: Array[Dictionary] = []
var failures := 0
var fail_temp := false
var fail_stage := ""
var scene_calls := 0
var samples := 0
var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty() or DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		get_tree().quit(2)
		return
	get_tree().root.size = Vector2i(1280, 720)
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	RealityState.persistence_enabled = true
	RealityState.new_campaign_time_provider = _sample
	RealityState.storage_operation_override = _operation
	GameBoot.set_scene_change_for_tests(_scene_failure)
	await _state("missing", false)
	await _capture("01_missing_begin", "missing load; real title ready")
	await _state("loaded", true)
	await _capture("02_loaded_continue", "supported primary loaded; real title ready")
	screen._new_campaign_button.pressed.emit()
	await _capture("05_loaded_replacement", "actual New button pressed; Keep focused")
	screen._replacement_cancel.pressed.emit()
	await _state("recovered", true)
	RealityState.data.first_shift.filing = "later_generation"
	RealityState.save_game()
	_write('{"version":4,'.to_utf8_buffer())
	RealityState.load_game()
	await _reload_title()
	await _capture("03_recovered_continue", "real backup recovered after deliberately truncated primary")
	await _state("protected", false)
	_write('{"version":99,"future_fact":"preserve"}'.to_utf8_buffer())
	RealityState.load_game()
	await _reload_title()
	await _capture("04_protected_save", "real future primary refused and protected")
	screen._new_campaign_button.pressed.emit()
	await _capture("06_protected_replacement", "actual New button pressed over global protection notice")
	fail_temp = true
	screen._replacement_confirm.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	await _capture("07_failed_new", "actual Replace button; disclosed temp_write failure; no scene operation")
	fail_temp = false
	await _state("scene_failure", false)
	screen._primary_button.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	await _capture("08_failed_scene_retry", "actual Begin button saved New; disclosed scene-operation error; Continue retry")
	await _state("artifacts_only", false)
	fail_stage = "journal_write"
	screen._primary_button.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	await _capture("09_first_creation_artifacts_retry", "actual Begin; disclosed journal_write failure leaves only uncommitted temp; no Continue")
	fail_stage = ""
	RealityState.load_game()
	await _reload_title()
	await _capture("10_artifacts_protected_after_reload", "actual reload protects uncommitted artifacts; explicit New, no Continue")
	await _free_title()
	GameBoot.set_scene_change_for_tests(Callable())
	RealityState.storage_operation_override = Callable()
	RealityState.new_campaign_time_provider = Callable()
	var receipt := {"scope": "actual title state and handler composition capture; not physical input, destination traversal, human acceptance or audio listening",
			"title_audio_silent": true, "frames": records, "failures": failures,
			"scene_requests_intercepted": scene_calls, "creation_samples": samples}
	var file := FileAccess.open(out_dir.path_join("capture_receipt.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
	else:
		file.store_string(JSON.stringify(receipt, "\t"))
		file.close()
	print("[TITLE RECOVERY SHOT] frames=%d failures=%d" % [records.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)


func _state(label: String, seeded: bool) -> void:
	await _free_title()
	RealityState.save_path = "user://tests/title_recovery_shot/%s.json" % label
	if FileAccess.file_exists(RealityState.save_path):
		failures += 1
		push_error("Capture requires a new profile: " + label)
		get_tree().quit(2)
		return
	RealityState.load_game()
	if seeded:
		if not RealityState.start_new_campaign():
			failures += 1
		RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE,
				"report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
		if not RealityState.save_game():
			failures += 1
		RealityState.load_game()
	await _reload_title()


func _reload_title() -> void:
	await _free_title()
	screen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame


func _free_title() -> void:
	if not is_instance_valid(screen):
		return
	for player in screen._players:
		player.stop()
	await get_tree().create_timer(0.2).timeout
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	screen = null


func _capture(label: String, action: String) -> void:
	await get_tree().create_timer(0.25).timeout
	var intended := {"01_missing_begin": "missing", "02_loaded_continue": "loaded",
			"03_recovered_continue": "recovered", "04_protected_save": "protected",
			"05_loaded_replacement": "loaded", "06_protected_replacement": "protected",
			"07_failed_new": "protected", "08_failed_scene_retry": "loaded",
			"09_first_creation_artifacts_retry": "missing", "10_artifacts_protected_after_reload": "protected"}
	var state_matches := str(RealityState.load_status().status) == intended[label]
	if label in ["05_loaded_replacement", "06_protected_replacement"]:
		state_matches = state_matches and screen._replacement_layer.visible \
				and screen._replacement_cancel.has_focus()
	elif label == "07_failed_new":
		state_matches = state_matches and scene_calls == 0 and not screen._leaving \
				and GameBoot.last_launch_result().get("code") == "new_campaign_failed"
	elif label == "08_failed_scene_retry":
		state_matches = state_matches and scene_calls == 1 and not screen._leaving \
				and screen._primary_button.text == "CONTINUE" \
				and GameBoot.last_launch_result().get("code") == "scene_change_failed"
	elif label in ["09_first_creation_artifacts_retry", "10_artifacts_protected_after_reload"]:
		state_matches = state_matches and not RealityState.can_continue() \
				and not FileAccess.file_exists(RealityState.save_path) \
				and FileAccess.file_exists(RealityState.save_path + ".tmp")
	if not state_matches:
		failures += 1
		push_error("Title capture state differs from its label: " + label)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
	var focus := get_viewport().gui_get_focus_owner()
	records.append({"frame": label, "path": path, "saved": error == OK,
			"declared_state_matches": state_matches,
			"viewport": [image.get_width(), image.get_height()], "action": action,
			"load_status": RealityState.load_status(), "can_continue": RealityState.can_continue(),
			"focus": str(focus.name) if focus != null else "", "selected_track": screen._current_track,
			"title_leaving": screen._leaving, "save_notice": screen._save_notice.text,
			"last_launch": GameBoot.last_launch_result(), "last_save": RealityState.last_save_result()})


func _sample() -> Dictionary:
	samples += 1
	return {"hour": 13, "minute": 27}


func _operation(stage: String, _op: String, _args: Dictionary) -> Variant:
	return {"ok": false, "error": ERR_FILE_CANT_WRITE} \
			if (fail_temp and stage == "temp_write") or stage == fail_stage else null


func _scene_failure(_path: String) -> Error:
	scene_calls += 1
	return ERR_CANT_OPEN


func _write(bytes: PackedByteArray) -> void:
	var parent := ProjectSettings.globalize_path(RealityState.save_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		failures += 1
		return
	var file := FileAccess.open(RealityState.save_path, FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_buffer(bytes)
	file.close()
