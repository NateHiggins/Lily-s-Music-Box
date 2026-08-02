extends StaticBody3D
## One live switch plate. See switch_system.gd.

var system: Node


func interact_prompt() -> String:
	return "[E]  Light switch"


func interact(_player: Node) -> void:
	if system:
		system.toggle_room(str(get_meta("room_id", "")))
