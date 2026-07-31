class_name DeskZone
extends Area3D
## Interact target at the 4B workstation: E sits the player down into
## whichever case is currently on the line. The prompt is the only place the
## queue is visible from the room, so it names what is waiting.

var call_interface: CallInterface


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 1.8)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)


func interact_prompt() -> String:
	if call_interface == null:
		return "[E]  Sit at the support desk"
	if call_interface.flags.has("desk_double"):
		# Case 03's price, collected at the player's own chair.
		return "[E]  Someone is already taking a call in your voice"
	if call_interface.case_index >= CaseLibrary.count():
		return "[E]  The line is quiet"
	return "[E]  %s" % CaseLibrary.desk_prompt(call_interface.case_index)


func interact(player: Node) -> void:
	if call_interface:
		call_interface.enter(player)
