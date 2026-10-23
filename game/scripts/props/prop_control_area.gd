class_name PropControlArea
extends Area3D
## A ray-facing handle for one control on a larger functional prop.
##
## The area owns no appliance state.  It names the physical control the ray
## reached, asks the parent mechanism for the current prompt, and returns the
## parent's authoritative interaction result to the telegram presenter.

var control_id := ""

func manipulation_target(_hit: Dictionary) -> Dictionary:
	var mechanism := _mechanism("control_grip")
	if mechanism != null:
		return mechanism.call("control_grip",control_id,self)
	return {"legacy":true}


## The mechanism is the nearest ancestor that answers for this control. A
## control may sit on a moving part of it (a knock panel on a door leaf) and
## that part is not the authority.
func _mechanism(method: String) -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method(method):
			return node
		node = node.get_parent()
	return null


func configure(id: String) -> void:
	control_id = id
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("functional_interaction_areas")


func interact_prompt() -> String:
	var owner := _mechanism("control_prompt")
	if owner != null:
		return str(owner.call("control_prompt", control_id))
	return ""


func interact(player: Node) -> Variant:
	var owner := _mechanism("interact_control")
	if owner != null:
		return owner.call("interact_control", control_id, player)
	return {}
