extends StaticBody3D


func interact_prompt() -> String:
	return "Open the little door"


func interact(player: Node) -> void:
	get_parent().interact(player)
