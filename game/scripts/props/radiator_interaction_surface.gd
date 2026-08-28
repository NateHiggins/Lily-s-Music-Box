class_name RadiatorInteractionSurface
extends Area3D
## A named physical surface on RadiatorProp. It owns no mechanism state.

var action_id := ""
var action_prompt := ""
var radiator: RadiatorProp


func setup(owner: RadiatorProp, id: String, prompt: String,
		size: Vector3, at: Vector3) -> void:
	radiator = owner
	action_id = id
	action_prompt = prompt
	name = "%sSurface" % id.to_pascal_case()
	position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func interact_prompt() -> String:
	return radiator.prompt_for_action(action_id, action_prompt) \
			if radiator else action_prompt


func interact(_player: Node) -> Variant:
	return radiator.perform_physical_action(action_id) if radiator else null
