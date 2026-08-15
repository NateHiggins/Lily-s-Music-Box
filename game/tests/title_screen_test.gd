extends Node
## Exact title contract: both full masters, returned-first alternation, and the
## two visual records remain independently selectable without touching boot.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	var screen = load(
			"res://scenes/ui/title_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	_check("the real title replaces the maintenance placeholder",
			screen.find_child("GameTitle", true, false).text \
			== "PLEASE\nREMAIN ON\nTHE LINE")
	_check("two complete title masters are installed", screen._tracks.size() == 2)
	_check("Escapement Failure retains its full 112.58 second form",
			is_equal_approx(screen._tracks[0].get_length(), 112.576875))
	_check("the untouched waltz retains its full 158.73 second form",
			is_equal_approx(screen._tracks[1].get_length(), 158.731625))
	_check("neither imported master hides an internal loop",
			not screen._tracks[0].loop and not screen._tracks[1].loop)
	_check("the returned reconstruction is the opening theme",
			screen._current_track == 0
			and screen._record_label.text == "ESCAPEMENT FAILURE"
			and screen._returned_art.modulate.a > 0.99)
	_check("the opening title exposes the original-record choice",
			screen._record_button.text == "HEAR THE 1928 ORIGINAL")
	_check("the decorative mechanism exists beneath interactive UI",
			screen._veil.get_script().resource_path \
			== "res://scripts/ui/title_clockwork_veil.gd"
			and screen._veil.mouse_filter == Control.MOUSE_FILTER_IGNORE)

	screen._start_track(1, true)
	await get_tree().process_frame
	_check("the original record selects the sales-plate face",
			screen._current_track == 1
			and screen._record_label.text == "THE CLOCKWORK WALTZ"
			and screen._returned_art.modulate.a < 0.01)
	_check("the original face offers the authored return",
			screen._record_button.text == "RETURN IT TOO FAST")
	screen._on_track_finished(1)
	await get_tree().process_frame
	_check("a completed original alternates to the full returned master",
			screen._current_track == 0)
	_check("silent proof starts no hidden audio players",
			screen._players.all(func(player): return not player.playing))

	print("[TITLE SCREEN] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
