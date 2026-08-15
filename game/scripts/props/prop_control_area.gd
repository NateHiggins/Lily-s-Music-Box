class_name PropControlArea
extends Area3D
## A ray-facing handle for one control on a larger functional prop.
##
## The area owns no appliance state.  It names the physical control the ray
## reached, asks the parent mechanism for the current prompt, and returns the
## parent's authoritative interaction result to the telegram presenter.

var control_id := ""


func configure(id: String) -> void:
	control_id = id
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("functional_interaction_areas")


func interact_prompt() -> String:
	var owner := get_parent()
	if owner != null and owner.has_method("control_prompt"):
		return str(owner.call("control_prompt", control_id))
	return ""


func interact(player: Node) -> Variant:
	var owner := get_parent()
	if owner != null and owner.has_method("interact_control"):
		return owner.call("interact_control", control_id, player)
	return {}
