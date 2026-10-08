extends BakedFurnitureInteraction
## Existing specialist valve-radio controls with scene-owned decoder cleanup.
var native_ready := false
func _ready() -> void:
	super._ready()
	var factory: RefCounted = get_meta("v2_radio_factory",null)
	if factory != null:
		native_ready = factory.mount_on(self,record_id)
		remove_meta("v2_radio_factory")

func _exit_tree() -> void:
	if _control_tween != null and _control_tween.is_valid(): _control_tween.kill()
	for item in [{"emitter":_radio_bed,"key":"murmur_loop"}, {"emitter":_control_click,"key":"tick"}]:
		var emitter := item.emitter as AudioStreamPlayer3D
		if emitter == null: continue
		var stream := emitter.stream
		emitter.stop()
		emitter.stream = null
		if stream != null: PropAudio.release_stream(str(item.key), stream)
