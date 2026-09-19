extends BakedFurnitureInteraction
## Existing specialist valve-radio controls with scene-owned decoder cleanup.
func _ready() -> void:
	super._ready()
	if _radio_knob != null:
		for mesh: MeshInstance3D in _radio_knob.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = MatLib.get_mat("bakelite_black")

func _exit_tree() -> void:
	if _control_tween != null and _control_tween.is_valid(): _control_tween.kill()
	for item in [{"emitter":_radio_bed,"key":"murmur_loop"}, {"emitter":_control_click,"key":"tick"}]:
		var emitter := item.emitter as AudioStreamPlayer3D
		if emitter == null: continue
		var stream := emitter.stream
		emitter.stop()
		emitter.stream = null
		if stream != null: PropAudio.release_stream(str(item.key), stream)
