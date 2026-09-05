extends BakedFurnitureInteraction
## V2 supplies the porcelain body separately; preserve the production flush owner.
func _exit_tree() -> void:
	for tween in [_flush_tween, _busy_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if _water != null:
		var stream := _water.stream
		_water.stop()
		_water.stream = null
		PropAudio.release_stream("sink_water", stream)
