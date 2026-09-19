extends Node
## Calls the actual buttons, title handlers, GameBoot gates, and RealityState
## disk APIs. Only scene change is intercepted; this is not root traversal.

const TITLE := preload("res://scenes/ui/title_screen.tscn")
const ROOT := "user://tests/title_save_recovery"
var passes := 0
var failures := 0
var scene_calls := 0
var scene_result := OK
var samples := 0
var fail_temp := false
var fail_stage := ""
var screen: OrisonTitleScreen


func _ready() -> void:
	var previous_path := RealityState.save_path
	var previous_persistence := RealityState.persistence_enabled
	var previous_frozen := bool(CampaignTime.get("_frozen_for_tests"))
	var previous_silent := OS.get_environment("TITLE_SCREEN_SILENT")
	var previous_mode := GameBoot.launch_mode
	var previous_debug := OS.get_environment("ORISON_TITLE_DEBUG")
	OS.set_environment("ORISON_TITLE_DEBUG", "")
	get_tree().root.size = Vector2i(1280, 720)
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	RealityState.persistence_enabled = true
	RealityState.new_campaign_time_provider = _sample_time
	RealityState.storage_operation_override = _storage_operation
	GameBoot.set_scene_change_for_tests(_change_scene)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT)) != OK:
		push_error("Title recovery fixture directory could not be created")
		get_tree().quit(2)
		return
	await _continue_existing()
	await _cancel_replacement()
	await _failed_replacement(false)
	await _failed_replacement(true)
	await _protected_continue()
	await _recovered_continue()
	await _fresh_begin()
	await _failed_begin()
	await _failed_first_creation_artifacts()
	await _explicit_replacement()
	await _failed_scene_restores_title()
	await _new_saved_but_scene_failed()
	await _stale_begin_refused()
	await _developer_entry_opt_in()
	await _free_title()
	GameBoot.set_scene_change_for_tests(Callable())
	GameBoot.launch_mode = previous_mode
	GameBoot.apply_render_profile()
	RealityState.storage_operation_override = Callable()
	RealityState.new_campaign_time_provider = Callable()
	RealityState.save_path = previous_path
	RealityState.load_game()
	RealityState.persistence_enabled = previous_persistence
	CampaignTime.set_frozen_for_tests(previous_frozen)
	OS.set_environment("TITLE_SCREEN_SILENT", previous_silent)
	OS.set_environment("ORISON_TITLE_DEBUG", previous_debug)
	print("[TITLE SAVE RECOVERY] %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", passes, passes + failures])
	get_tree().quit(0 if failures == 0 else 1)


func _continue_existing() -> void:
	await _case("continue", true)
	var bytes := _read_primary()
	var facts := _facts()
	var count := samples
	_check(screen._primary_button.text == "CONTINUE" and screen._primary_button.has_focus(),
			"loaded campaign gets primary focused Continue")
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 1 and GameBoot.last_launch_result().ok,
			"actual Continue button reaches the checked scene operation once")
	_check(_read_primary() == bytes and _facts() == facts and samples == count,
			"Continue preserves job, spent item, Dream, first-shift and exact clock without sampling")


func _cancel_replacement() -> void:
	await _case("cancel", true)
	var bytes := _read_primary()
	var facts := _facts()
	var count := samples
	screen._new_campaign_button.pressed.emit()
	_check(screen._replacement_layer.visible and screen._replacement_cancel.has_focus(),
			"New opens the explicit replacement choice with Keep focused")
	_check(_inside_viewport(screen._replacement_cancel)
			and _inside_viewport(screen._replacement_confirm),
			"both replacement choices fit inside the launch viewport")
	_check(screen._replacement_copy.text.contains("replaced")
			and screen._replacement_copy.text.contains("archive"),
			"choice states replacement and archive limits")
	screen._replacement_cancel.pressed.emit()
	_check(not screen._replacement_layer.visible and screen._new_campaign_button.has_focus(),
			"cancel closes the choice and returns focus to New")
	_check(scene_calls == 0 and samples == count and _read_primary() == bytes and _facts() == facts,
			"cancel performs no sampling, save mutation, fact reset, or launch")


func _failed_replacement(protected: bool) -> void:
	await _case("failed_new_protected" if protected else "failed_new_loaded", not protected)
	if protected:
		_write_primary('{"version":99,"future_fact":"keep exactly"}'.to_utf8_buffer())
		RealityState.load_game()
		screen._refresh_save_actions()
	var bytes := _read_primary()
	var facts := _facts()
	var status := RealityState.load_status()
	var notice := RealityState.player_notice()
	fail_temp = true
	screen._new_campaign_button.pressed.emit()
	if protected:
		_check(not get_node("/root/SaveStatusNotice").panel.visible
				and not RealityState.player_notice().is_empty() and screen._save_notice.visible,
				"title presents the real protected notice without clearing it or duplicating an overlay")
		await _modal_focus_controls()
	screen._replacement_confirm.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 0 and not screen._leaving and screen._save_notice.visible,
			"failed New returns to a visible usable title with a save notice")
	_check(_read_primary() == bytes and _facts() == facts
			and RealityState.load_status() == status and RealityState.player_notice() == notice,
			"failed New preserves original primary, runtime facts, load status and protection notice")
	_check(not screen._new_campaign_button.disabled and screen._new_campaign_button.has_focus(),
			"failed New restores focus to the New launcher")
	fail_temp = false
	if protected:
		await _free_title()
		_check(get_node("/root/SaveStatusNotice").panel.visible
				and RealityState.player_notice() == notice,
				"retiring the title restores the global notice without losing its protected facts")


func _protected_continue() -> void:
	await _case("protected", false)
	_write_primary('{"version":99,"future_fact":"preserve"}'.to_utf8_buffer())
	RealityState.load_game()
	screen._refresh_save_actions()
	var bytes := _read_primary()
	var count := samples
	_check(not screen._primary_button.visible and screen._new_campaign_button.visible
			and screen._save_notice.visible,
			"protected save exposes a notice and explicit New without a misleading Begin")
	screen._primary_button.pressed.emit()
	_check(scene_calls == 0 and samples == count and _read_primary() == bytes,
			"a stale hidden primary signal cannot replace protected facts")
	_check(not GameBoot.begin_game(GameBoot.LaunchMode.CINEMATIC, false)
			and scene_calls == 0 and _read_primary() == bytes,
			"GameBoot independently refuses invalid Continue without a scene request")


func _recovered_continue() -> void:
	await _case("recovered", true)
	var previous := _facts()
	RealityState.data.first_shift["filing"] = "later_generation"
	_check(RealityState.save_game(), "fixture commits second generation to create a real backup")
	_write_primary('{"version":4,'.to_utf8_buffer())
	RealityState.load_game()
	screen._refresh_save_actions()
	var bytes := _read_primary()
	var count := samples
	_check(RealityState.load_status().status == "recovered" and _facts() == previous,
			"storage reconstructs previous complete generation for the title")
	_check(screen._primary_button.text == "CONTINUE" and screen._save_notice.text.contains("recovered"),
			"recovered campaign offers Continue with an honest recovery notice")
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 1 and samples == count and _read_primary() == bytes and _facts() == previous,
			"recovered Continue launches without replacing or resampling recovered facts")


func _fresh_begin() -> void:
	await _case("missing", false)
	var count := samples
	_check(screen._primary_button.text == "BEGIN THE NIGHT" and not screen._new_campaign_button.visible,
			"only a truly missing profile gets Begin without a replacement choice")
	screen._primary_button.pressed.emit()
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 1 and samples == count + 1 and RealityState.can_continue(),
			"repeated Begin signals create one saved campaign, sample once, and launch once")
	_check(not _read_primary().is_empty() and int(RealityState.data.campaign_clock.start_minute_of_day) == 807,
			"fresh Begin persists the exact injected 13:27 start")


func _explicit_replacement() -> void:
	await _case("explicit_new", true)
	var old_bytes := _read_primary()
	var count := samples
	screen._new_campaign_button.pressed.emit()
	_check(_read_primary() == old_bytes and samples == count and scene_calls == 0,
			"opening New alone does not replace anything")
	screen._replacement_confirm.pressed.emit()
	screen._replacement_confirm.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 1 and samples == count + 1 and RealityState.can_continue(),
			"one explicit accepted replacement persists and launches once")
	_check(RealityState.data.maintenance_jobs.is_empty() and RealityState.data.maintenance_items.is_empty()
			and RealityState.data.dream.is_empty() and RealityState.data.first_shift.is_empty()
			and float(RealityState.data.campaign_clock.elapsed_minutes) == 0.0,
			"successful New adopts fresh job, inventory, Dream, first-shift and calendar facts")
	_check(_read_primary() != old_bytes and not _read_primary().is_empty(),
			"successful New has a different verified on-disk generation")


func _failed_begin() -> void:
	await _case("missing_save_failure", false)
	fail_temp = true
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 0 and not screen._leaving and not RealityState.can_continue()
			and screen._primary_button.text == "BEGIN THE NIGHT" and screen._primary_button.has_focus(),
			"failed fresh Begin stays at an actionable title without claiming a saved campaign")
	_check(not FileAccess.file_exists(RealityState.save_path) and screen._save_notice.visible
			and not screen._save_notice.text.contains("previous save"),
			"failed fresh Begin does not claim a nonexistent previous save was kept")
	fail_temp = false


func _failed_scene_restores_title() -> void:
	OS.set_environment("TITLE_SCREEN_SILENT", "")
	await _case("scene_failure", true)
	scene_result = ERR_CANT_OPEN
	var bytes := _read_primary()
	var selected := screen._current_track
	var initial_position := screen._players[selected].get_playback_position()
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 1 and not screen._leaving and screen._primary_button.has_focus()
			and not screen._primary_button.disabled and screen._save_notice.visible,
			"failed scene operation restores title interaction, focus and notice")
	_check(screen._current_track == selected and screen._players[selected].playing
			and screen._players[selected].get_playback_position() > initial_position
			and absf(screen._players[selected].volume_db - screen._music_db(selected)) < 0.1,
			"failed scene operation restores the selected record volume without restarting it")
	_check(screen.modulate == Color.WHITE and _read_primary() == bytes,
			"failed launch leaves the title visible and saved facts intact")
	OS.set_environment("TITLE_SCREEN_SILENT", "1")


func _failed_first_creation_artifacts() -> void:
	await _case("missing_journal_failure", false)
	fail_stage = "journal_write"
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 0 and not FileAccess.file_exists(RealityState.save_path)
			and FileAccess.file_exists(RealityState.save_path + ".tmp"),
			"failed first creation leaves only an uncommitted candidate and no primary")
	_check(not RealityState.can_continue() and screen._primary_button.text == "BEGIN THE NIGHT"
			and not screen._leaving and screen._save_notice.visible,
			"failed first creation offers an honest retry without claiming Continue")
	fail_stage = ""
	RealityState.load_game()
	await _free_title()
	screen = TITLE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(RealityState.load_status().status == "protected"
			and RealityState.load_status().has_saved_campaign and not RealityState.can_continue(),
			"reload classifies lone candidate artifacts as protected, never a saved campaign to Continue")
	_check(not screen._primary_button.visible and screen._new_campaign_button.visible
			and screen._save_notice.visible and screen._services_button.has_focus(),
			"artifact-only restart exposes explicit New and safe Services focus")
	screen._new_campaign_button.pressed.emit()
	screen._replacement_cancel.pressed.emit()
	_check(not FileAccess.file_exists(RealityState.save_path)
			and FileAccess.file_exists(RealityState.save_path + ".tmp") and scene_calls == 0,
			"cancelling artifact-only New retains the uncommitted file without promoting it")


func _stale_begin_refused() -> void:
	await _case("stale_begin", true)
	var bytes := _read_primary()
	var count := samples
	_check(not GameBoot.begin_game(GameBoot.LaunchMode.CINEMATIC, true)
			and scene_calls == 0 and samples == count and _read_primary() == bytes,
			"a direct Begin call cannot replace existing facts without the explicit choice flag")


func _new_saved_but_scene_failed() -> void:
	await _case("new_scene_failure", false)
	scene_result = ERR_CANT_OPEN
	var count := samples
	screen._primary_button.pressed.emit()
	await _launch_wait()
	var bytes := _read_primary()
	_check(scene_calls == 1 and samples == count + 1 and RealityState.can_continue()
			and not screen._leaving and screen._primary_button.text == "CONTINUE",
			"saved New plus scene failure returns to Continue for that same new campaign")
	scene_result = OK
	screen._primary_button.pressed.emit()
	await _launch_wait()
	_check(scene_calls == 2 and samples == count + 1 and _read_primary() == bytes,
			"retry after scene failure continues without creating or sampling another campaign")


func _developer_entry_opt_in() -> void:
	await _case("developer_opt_in", false)
	await _free_title()
	OS.set_environment("ORISON_TITLE_DEBUG", "1")
	screen = TITLE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(screen._debug_button.visible, "explicit developer opt-in exposes the separate debug action")
	OS.set_environment("ORISON_TITLE_DEBUG", "")


func _case(label: String, seeded: bool) -> void:
	await _free_title()
	scene_calls = 0
	scene_result = OK
	fail_temp = false
	fail_stage = ""
	RealityState.save_path = ROOT.path_join(label + ".json")
	# Runs require a new APPDATA profile before autoload startup. Existing
	# fixture files are an invocation error, never silently erased for a green.
	_check(not FileAccess.file_exists(RealityState.save_path), label + " starts with an unused file path")
	RealityState.load_game()
	if seeded:
		_check(RealityState.start_new_campaign(), label + " creates a real saved fixture")
		var clock := CampaignClock.new()
		_check(clock.configure_date(1928, 11, 10, 1439) and clock.advance_to(181.5),
				label + " seeds exact next-day clock facts")
		RealityState.data.maintenance_jobs = {"super_ticket": {"stage": "repaired",
				"repair_result": "pressure_restored", "resident_id": "resident_a"}}
		RealityState.data.maintenance_items = {"packing": {"state": "spent", "quantity": 0}}
		RealityState.data.dream = {"phase": "armed", "context_id": "super_ticket"}
		RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE,
				"report_id": ChirpHunt.JOB_ID, "filing": "fault_corrected"}
		_check(RealityState.save_game(), label + " saves semantic fixture facts")
		RealityState.load_game()
	screen = TITLE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_inside_viewport(screen._first_menu_button),
			label + " focused primary action fits the 1280x720 title viewport")
	_check(not screen._debug_button.visible and not screen.find_child("Eyebrow", true, false).text.contains("3:00"),
			label + " ordinary title has no debug action or fabricated opening time")


func _free_title() -> void:
	if not is_instance_valid(screen):
		return
	for player in screen._players:
		player.stop()
	await get_tree().create_timer(0.20).timeout
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	screen = null


func _launch_wait() -> void:
	await get_tree().create_timer(1.1).timeout


func _modal_focus_controls() -> void:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		get_viewport().push_input(event)
		await get_tree().process_frame
		var owner := get_viewport().gui_get_focus_owner()
		_check(owner in [screen._replacement_cancel, screen._replacement_confirm],
				"modal contains actual %s focus input while protected title notice is present" % action)
		event.pressed = false
		get_viewport().push_input(event)
		await get_tree().process_frame


func _inside_viewport(control: Control) -> bool:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(control.get_global_rect())


func _sample_time() -> Dictionary:
	samples += 1
	return {"hour": 13, "minute": 27}


func _storage_operation(stage: String, _operation: String, _arguments: Dictionary) -> Variant:
	if (fail_temp and stage == "temp_write") or stage == fail_stage:
		return {"ok": false, "error": ERR_FILE_CANT_WRITE}
	return null


func _change_scene(path: String) -> Error:
	scene_calls += 1
	_check(path == GameBoot.GAME_SCENE, "launch targets the actual CampaignShell scene")
	return scene_result


func _facts() -> Dictionary:
	var selected := {}
	for key in ["campaign_clock", "maintenance_jobs", "maintenance_items", "dream", "first_shift"]:
		selected[key] = RealityState.data.get(key, {})
	return JSON.parse_string(JSON.stringify(selected))


func _read_primary() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(RealityState.save_path) \
			if FileAccess.file_exists(RealityState.save_path) else PackedByteArray()


func _write_primary(bytes: PackedByteArray) -> void:
	var file := FileAccess.open(RealityState.save_path, FileAccess.WRITE)
	_check(file != null, "fixture raw primary can be opened")
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
	print("[TITLE RECOVERY] %s %s" % ["PASS" if ok else "FAIL", label])
