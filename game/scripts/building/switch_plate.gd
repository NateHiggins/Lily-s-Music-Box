extends StaticBody3D
## One live switch plate. See switch_system.gd.

var system: Node


func interact_prompt() -> String:
	return "[E]  Light switch"


func interact(_player: Node) -> void:
	# The click first, and unconditionally. A toggle brake (an empty room,
	# a fixture already dead) must still feel like a switch under the
	# hand — a plate that answers silently reads as broken scenery.
	var click := get_node_or_null("Click")
	if click and click is AudioStreamPlayer3D:
		var player := click as AudioStreamPlayer3D
		# A real toggle is two different sounds: the throw and the return.
		player.pitch_scale = randf_range(0.94, 1.06)
		player.play()
	if system:
		system.toggle_room(str(get_meta("room_id", "")))
