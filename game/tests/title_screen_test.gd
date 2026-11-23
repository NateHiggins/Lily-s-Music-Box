extends Node
## Exact title contract: the Harukiya cover whole beside the menu, three full
## masters with the song first, and their cycle without touching boot.

var _fails := 0
const AccessibilityCopyText := preload("res://scripts/ui/accessibility_copy.gd")


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	get_tree().root.size = Vector2i(1280, 720)
	var screen = load(
			"res://scenes/ui/title_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	_check("the real title replaces the maintenance placeholder",
			screen.find_child("GameTitle", true, false).text \
			== "PLEASE\nSTAY ON\nTHE LINE")
	_check("title establishes keyboard and controller focus",
			screen._first_menu_button.has_focus())
	screen._open_settings()
	_check("building services takes focus when opened",
			screen._quality.has_focus())
	screen._close_settings()
	_check("closing services returns focus to its launcher",
			screen._services_button.has_focus())
	await _check_modal_settings(screen)
	_check("three complete title masters are installed", screen._tracks.size() == 3)
	_check("Escapement Failure retains its full 112.58 second form",
			is_equal_approx(screen._tracks[0].get_length(), 112.576875))
	_check("the untouched waltz retains its full 158.73 second form",
			is_equal_approx(screen._tracks[1].get_length(), 158.731625))
	_check("Pull Up a Chair retains its full 182.14 second form",
			absf(screen._tracks[2].get_length() - 182.137) < 0.05)
	_check("no imported master hides an internal loop",
			screen._tracks.all(func(track): return not track.loop))
	_check("Pull Up a Chair is the opening theme",
			screen._current_track == 2
			and screen._record_label.text == "PULL UP A CHAIR")
	_check("the opening title offers the waltz next",
			screen._record_button.text == "PLAY THE CLOCKWORK WALTZ")
	screen._on_track_finished(2)
	await get_tree().process_frame
	_check("the completed song hands on to the untouched waltz",
			screen._current_track == 1
			and screen._record_button.text == "HEAR THE RETURN")
	var viewport_rect_now := Rect2(Vector2.ZERO, screen.get_viewport_rect().size)
	var cover_rect: Rect2 = screen._hero_art.get_global_rect()
	_check("the Harukiya cover is the title art, whole on the left of the field",
			screen._hero_art.texture.resource_path.ends_with("pull_up_a_chair_cover_v1.png")
			and viewport_rect_now.encloses(cover_rect)
			and cover_rect.get_center().x < viewport_rect_now.size.x * 0.5
			and is_equal_approx(cover_rect.size.x / cover_rect.size.y, 1500.0 / 2250.0))
	var card: Control = screen.find_child("TitleCard", true, false)
	_check("the menu stands clear of the cover",
			card != null and card.get_global_rect().position.x >= cover_rect.end.x)
	_check("building services exposes the first-build sleep warning option",
			screen._always_warn != null
			and screen._always_warn.name == "AlwaysWarnBeforeSleep"
			and screen._always_warn.text == AccessibilityCopyText.SLEEP_WARNING_LABEL
			and screen._always_warn.tooltip_text == AccessibilityCopyText.SLEEP_WARNING_HELP
			and screen._always_warn.button_pressed == bool(
					GameBoot.settings.always_warn_before_sleep))
	_check("building services exposes opt-in semantic sound captions",
			screen._sound_captions != null
			and screen._sound_captions.name == "GameplaySoundCaptions"
			and screen._sound_captions.text == AccessibilityCopyText.SOUND_CAPTIONS_LABEL
			and screen._sound_captions.tooltip_text == AccessibilityCopyText.SOUND_CAPTIONS_HELP
			and GameBoot.settings.has("gameplay_sound_captions"))
	_check("building services exposes five independent mix categories",
			screen._gameplay_volume != null and screen._voice_volume != null
			and screen._world_volume != null and screen._music_volume != null
			and screen._ui_volume != null)
	var settings_rect: Rect2 = screen._settings_panel.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, screen.get_viewport_rect().size)
	_check("the expanded mix surface %s remains inside launch viewport %s" % [
			settings_rect, viewport_rect],
			viewport_rect.encloses(settings_rect))
	_check("all category levels are persistent settings rather than UI-only state",
			["gameplay_volume", "voice_volume", "world_volume", "music_volume",
					"ui_volume"].all(func(key): return GameBoot.settings.has(key)))

	screen._start_track(0, true)
	await get_tree().process_frame
	_check("the optional return never replaces the cover",
			screen._current_track == 0
			and screen._record_label.text == "ESCAPEMENT FAILURE"
			and screen._hero_art.visible)
	_check("the returned record offers the song again",
			screen._record_button.text == "PULL UP A CHAIR")
	screen._on_track_finished(0)
	await get_tree().process_frame
	_check("a completed return comes back round to the song",
			screen._current_track == 2)
	_check("silent proof starts no hidden audio players",
			screen._players.all(func(player): return not player.playing))

	print("[TITLE SCREEN] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _check_modal_settings(screen: OrisonTitleScreen) -> void:
	var window := get_tree().root
	var master := AudioServer.get_bus_index("Master")
	var saved: float = GameBoot.settings.master_volume
	var preview := 0.32 if saved > 0.6 else 0.73
	var retained_query: String = GameBoot.settings.weather_location_query
	var playing: int = screen._current_track
	var cover_button := screen._record_button.get_global_rect().get_center()
	screen._open_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the click target is outside the settings sheet", not screen._settings_panel.get_global_rect().has_point(cover_button))
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = cover_button
		click.pressed = pressed
		window.push_input(click, true)
	_check("clicks behind settings cannot switch the title record", screen._current_track == playing)
	await _settings_shot("BuildingServices1280")
	var focus_stayed := true
	for i in 27:
		_push_key(window, KEY_TAB)
		var focus := window.gui_get_focus_owner()
		focus_stayed = focus_stayed and focus != null and screen._settings_panel.is_ancestor_of(focus)
	_check("Tab stays inside Building Services through wraparound", focus_stayed)
	screen._volume.value = preview
	screen._weather_location.text = "unapplied"
	_check("the volume preview changes the live bus", absf(AudioServer.get_bus_volume_db(master) - linear_to_db(preview)) < 0.01)

	for pressed: bool in [true, false]:
		var back := InputEventJoypadButton.new()
		back.button_index = JOY_BUTTON_B
		back.pressed = pressed
		window.push_input(back, true)
	_check("controller Back closes settings and restores launcher focus",
			not screen._settings_panel.is_visible_in_tree() and screen._services_button.has_focus())
	_check("Back restores committed audio and the configured volume",
			absf(AudioServer.get_bus_volume_db(master) - GameBoot.audio_bus_db("Master")) < 0.01
			and is_equal_approx(GameBoot.settings.master_volume, saved))

	window.size = Vector2i(800, 600)
	screen._open_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check("the sheet fits the smaller viewport and scrolls with focus",
			Rect2(Vector2.ZERO, screen.get_viewport_rect().size).encloses(screen._settings_panel.get_global_rect())
			and screen.find_child("BuildingServicesScroll", true, false).follow_focus)
	var apply: Button = screen.find_child("ApplyTitleSettings", true, false)
	var back_button: Button = screen.find_child("CancelTitleSettings", true, false)
	var sheet_rect := screen._settings_panel.get_global_rect()
	_check("Apply and Back remain visible without scrolling the sheet",
			sheet_rect.encloses(apply.get_global_rect()) and sheet_rect.encloses(back_button.get_global_rect())
			and apply.get_global_rect().position.y >= screen._settings_scroll.get_global_rect().end.y)
	_check("reopening starts with the committed preferences",
			is_equal_approx(screen._volume.value, saved) and screen._weather_location.text == retained_query)
	await _settings_shot("BuildingServices800")
	_push_key(window, KEY_ESCAPE)
	_check("keyboard Escape closes settings",
			not screen._settings_panel.is_visible_in_tree() and screen._services_button.has_focus())
	screen._open_settings()
	screen._volume.value = preview
	apply.grab_focus()
	_push_key(window, KEY_ENTER)
	var saved_file := ConfigFile.new()
	_check("keyboard Apply commits the change through GameBoot",
			not screen._settings_panel.is_visible_in_tree() and screen._services_button.has_focus()
			and is_equal_approx(GameBoot.settings.master_volume, preview)
			and saved_file.load(GameBoot.SETTINGS_PATH) == OK
			and is_equal_approx(float(saved_file.get_value("display", "master_volume", -1.0)), preview))
	GameBoot.settings.master_volume = saved
	GameBoot.save_settings()
	window.size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame


func _settings_shot(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	_check("saved settings proof " + label, frame.save_png(directory.path_join(label + ".png")) == OK)


func _push_key(window: Window, key: Key) -> void:
	for pressed: bool in [true, false]:
		var input := InputEventKey.new()
		input.keycode = key
		input.pressed = pressed
		window.push_input(input, true)
