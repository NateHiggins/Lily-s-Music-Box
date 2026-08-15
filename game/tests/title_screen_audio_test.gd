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
	_check("the original waltz really starts, not merely labels itself",
			screen._players[1].playing and not screen._players[0].playing)
	screen._players[1].seek(screen._tracks[1].get_length() - 0.08)
	await get_tree().create_timer(0.35).timeout
	_check("the complete original stream hands off to the return",
			screen._current_track == 0 and screen._players[0].playing)
	_check("the finished original player is stopped",
			not screen._players[1].playing)
	for player in screen._players:
		player.stop()
	# Godot releases a freshly-created Vorbis playback object on the audio
	# thread, not synchronously with stop().  Give that thread one short turn
	# before freeing the title screen so a passing proof also exits cleanly.
	await get_tree().create_timer(0.20).timeout
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[TITLE AUDIO] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
