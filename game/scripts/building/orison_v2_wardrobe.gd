extends BakedFurnitureInteraction
## Reuse the household wardrobe mechanism and release its scene-owned audio.
var native_ready := false

func _ready() -> void:
	super._ready()
	var factory: RefCounted = get_meta("v2_wardrobe_factory",null)
	if factory != null:
		native_ready = factory.mount_on(self,record_id)
		remove_meta("v2_wardrobe_factory")

func _exit_tree() -> void:
	if _wardrobe_tween != null and _wardrobe_tween.is_valid():
		_wardrobe_tween.kill()
	if _wardrobe_rattle != null:
		var stream := _wardrobe_rattle.stream
		_wardrobe_rattle.stop()
		_wardrobe_rattle.stream = null
		PropAudio.release_stream("creak", stream)
