class_name DeskZone
extends Area3D
## Interact target at the 4B workstation: E sits the player down into the
## support-call interface.

var call_interface: CallInterface


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 1.8)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)


func interact_prompt() -> String:
	return "[E]  Sit at the support desk"


func interact(player: Node) -> void:
	if call_interface:
		call_interface.enter(player)
