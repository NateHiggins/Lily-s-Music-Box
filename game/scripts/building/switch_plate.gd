extends StaticBody3D
## One live switch plate. See switch_system.gd.

var system: Node


func interact_prompt() -> String:
	return "[E]  Bathroom light" if get_meta("bathroom_switch", false) \
			else "[E]  Light switch"


func interact(_player: Node) -> void:
	# The click is unconditional. A toggle brake (an empty room,
	# a fixture already dead) must still feel like a switch under the
	# hand — a plate that answers silently reads as broken scenery.
	var now_on := false
	if system:
		now_on = system.toggle_room(str(get_meta("room_id", "")))
	# Unlike the old random pitch, throw and return now report the circuit
	# verdict consistently. The plate remains the physical source.
	if now_on:
		AudioPolicy.present_3d(&"interaction.switch_on", global_position,
				1.0, StringName(name))
	else:
		AudioPolicy.present_3d(&"interaction.switch_off", global_position,
				1.0, StringName(name))
