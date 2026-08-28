extends Area3D
## Fixture adapter mirroring the production PropControlArea pattern.


func interact_prompt() -> String:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("control_prompt"):
		return str(owner_node.call("control_prompt", "fixture"))
	return ""


func interact(player: Node) -> Variant:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("interact_control"):
		return owner_node.call("interact_control", "fixture", player)
	return null
