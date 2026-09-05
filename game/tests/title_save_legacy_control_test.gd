extends Node
## Negative controls over exact preserved title/boot source. Adapters only
## remove the duplicate class name and intercept the scene-operation boundary.
## No pass/fail result exists until a separately authorized Godot run.

var failures := 0
var scene_calls := 0


func _ready() -> void:
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	RealityState.save_path = "user://tests/title_legacy/campaign.json"
	RealityState.persistence_enabled = true
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			RealityState.save_path.get_base_dir())) != OK:
		get_tree().quit(2)
		return
	if FileAccess.file_exists(RealityState.save_path):
		push_error("Legacy control requires a new profile")
		get_tree().quit(2)
		return
	RealityState.load_game()
	RealityState.new_campaign_time_provider = func(): return {"hour": 13, "minute": 27}
	if not RealityState.start_new_campaign():
		get_tree().quit(2)
		return
	RealityState.data.maintenance_jobs = {"super_ticket": {"stage": "repaired"}}
	RealityState.save_game()
	RealityState.load_game()
	var original_bytes := FileAccess.get_file_as_bytes(RealityState.save_path)
	var base := OS.get_environment("TITLE_LEGACY_SOURCE_DIR")
	var control := OS.get_environment("TITLE_LEGACY_CONTROL")
	var title_source := FileAccess.get_file_as_string(base.path_join("game/scripts/ui/title_screen.gd"))
	title_source = title_source.replace("\r\n", "\n")
	title_source = title_source.replace("class_name OrisonTitleScreen\n", "")
	var legacy_boot: Node
	if control == "boot_failed_new":
		var boot_source := FileAccess.get_file_as_string(base.path_join("game/scripts/game_boot.gd"))
		boot_source = boot_source.replace("\r\n", "\n")
		boot_source = boot_source.replace("extends Node\n", "extends Node\nvar _scene_sink: Callable\n")
		boot_source = boot_source.replace("get_tree().change_scene_to_file(GAME_SCENE)",
				"_scene_sink.call(GAME_SCENE)")
		var boot_script := GDScript.new()
		boot_script.source_code = boot_source
		if boot_script.reload() != OK:
			get_tree().quit(2)
			return
		legacy_boot = Node.new()
		legacy_boot.set_script(boot_script)
		legacy_boot.set("_scene_sink", _scene_sink)
		add_child(legacy_boot)
		title_source = title_source.replace("extends Control\n", "extends Control\nvar _legacy_boot: Node\n")
		title_source = title_source.replace("GameBoot.begin_game(", "_legacy_boot.call(\"begin_game\", ")
	var title_script := GDScript.new()
	title_script.source_code = title_source
	if title_script.reload() != OK:
		get_tree().quit(2)
		return
	var screen := Control.new()
	screen.set_script(title_script)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if legacy_boot != null:
		screen.set("_legacy_boot", legacy_boot)
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TITLE LEGACY] preserved source compiled and constructed; control=" + control)
	if control == "title_primary":
		var primary: Button = screen.get("_first_menu_button")
		_check(primary.text == "CONTINUE", "existing campaign receives Continue as primary")
		_check(screen.find_child("NewCampaignAction", true, false) != null,
				"replacement is a separate explicit action")
	elif control == "boot_failed_new":
		RealityState.storage_operation_override = func(stage, _op, _args):
			return {"ok": false, "error": ERR_FILE_CANT_WRITE} if stage == "temp_write" else null
		var primary: Button = screen.get("_first_menu_button")
		primary.pressed.emit()
		await get_tree().create_timer(1.0).timeout
		_check(scene_calls == 0, "failed New must refuse scene change")
		_check(not bool(screen.get("_leaving")), "failed New restores title interaction")
		_check(FileAccess.get_file_as_bytes(RealityState.save_path) == original_bytes,
				"current storage authority retains original bytes in this isolated UI/boot control")
	else:
		push_error("Choose title_primary or boot_failed_new")
		get_tree().quit(2)
		return
	RealityState.storage_operation_override = Callable()
	RealityState.new_campaign_time_provider = Callable()
	for player in screen.get("_players"):
		player.stop()
	await get_tree().create_timer(0.20).timeout
	screen.queue_free()
	if legacy_boot != null:
		legacy_boot.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TITLE LEGACY] failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _scene_sink(_path: String) -> Error:
	scene_calls += 1
	return OK


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("[TITLE LEGACY] %s %s" % ["PASS" if ok else "FAIL", label])
