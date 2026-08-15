extends Node
## Short real-playback proof. Seeking near the end tests the same `finished`
## handoff a patient title-screen listener gets without waiting 112 seconds.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("TITLE_SCREEN_SILENT", "")
	var screen = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(0.25).timeout
	_check("Escapement Failure really starts, not merely labels itself",
			screen._players[0].playing and not screen._players[1].playing)
	screen._players[0].seek(screen._tracks[0].get_length() - 0.08)
	await get_tree().create_timer(0.35).timeout
	_check("the complete returned stream hands off to the original",
			screen._current_track == 1 and screen._players[1].playing)
	_check("the finished returned player is stopped",
			not screen._players[0].playing)
	for player in screen._players:
		player.stop()
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TITLE AUDIO] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
