extends Node
## Exact title contract: one waking-world hero, both full masters, original
## first, and returned/original alternation without touching boot.

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
			== "PLEASE\nREMAIN ON\nTHE LINE")
	_check("title establishes keyboard and controller focus",
			screen._first_menu_button.has_focus())
	screen._open_settings()
	_check("building services takes focus when opened",
			screen._quality.has_focus())
	screen._close_settings()
	_check("closing services returns focus to its launcher",
			screen._services_button.has_focus())
	_check("two complete title masters are installed", screen._tracks.size() == 2)
	_check("Escapement Failure retains its full 112.58 second form",
			is_equal_approx(screen._tracks[0].get_length(), 112.576875))
	_check("the untouched waltz retains its full 158.73 second form",
			is_equal_approx(screen._tracks[1].get_length(), 158.731625))
	_check("neither imported master hides an internal loop",
			not screen._tracks[0].loop and not screen._tracks[1].loop)
	_check("the untouched original is the opening theme",
			screen._current_track == 1
			and screen._record_label.text == "THE CLOCKWORK WALTZ")
	_check("the opening title exposes the returned-record choice",
			screen._record_button.text == "HEAR THE RETURN")
	_check("one waking-world hero contains the complete three-zone scope",
			screen._hero_art.texture.resource_path.ends_with(
				"orison_grand_mundane_title_v1.png"))
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
	_check("the optional return never replaces the waking-world hero",
			screen._current_track == 0
			and screen._record_label.text == "ESCAPEMENT FAILURE"
			and screen._hero_art.visible)
	_check("the returned record offers the original master",
			screen._record_button.text == "PLAY THE ORIGINAL MASTER")
	screen._on_track_finished(0)
	await get_tree().process_frame
	_check("a completed return alternates to the full original master",
			screen._current_track == 1)
	_check("silent proof starts no hidden audio players",
			screen._players.all(func(player): return not player.playing))

	print("[TITLE SCREEN] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
