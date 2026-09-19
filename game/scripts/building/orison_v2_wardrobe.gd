extends BakedFurnitureInteraction
## Reuse the household wardrobe mechanism and release its scene-owned audio.
func _exit_tree() -> void:
	if _wardrobe_tween != null and _wardrobe_tween.is_valid():
		_wardrobe_tween.kill()
	if _wardrobe_rattle != null:
		var stream := _wardrobe_rattle.stream
		_wardrobe_rattle.stop()
		_wardrobe_rattle.stream = null
		PropAudio.release_stream("creak", stream)
