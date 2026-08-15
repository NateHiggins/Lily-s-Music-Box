class_name DeskZone
extends Area3D
## Interact target at the 4B workstation: E sits the player down into
## whichever case is currently on the line. The prompt is the only place the
## queue is visible from the room, so it names what is waiting.

var call_interface: CallInterface
var seated_player: PlayerController


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 1.8)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)


func interact_prompt() -> String:
	if seated_player:
		return "[E]  Stand up from the support desk"
	if call_interface == null:
		return "[E]  Sit at the support desk"
	if call_interface.flags.has("desk_double"):
		# Case 03's price, collected at the player's own chair.
		return "[E]  Someone is already taking a call in your voice"
	if call_interface.case_index >= CaseLibrary.count():
		return "[E]  The line is quiet"
	return "[E]  %s" % CaseLibrary.desk_prompt(call_interface.case_index)


func interact(player: Node) -> void:
	if call_interface == null or not player is PlayerController:
		return
	var controller := player as PlayerController
	if seated_player == controller:
		call_interface.leave()
		return
	if seated_player != null:
		return
	seated_player = controller
	controller.begin_seated_interaction(self)
	call_interface.enter(controller, self)


## Called by CallInterface for both E and Esc exits, so its modal state and the
## physical chair can never disagree about whether the player has stood up.
func release_player(player: PlayerController) -> void:
	if seated_player != player:
		return
	seated_player = null
	player.end_seated_interaction(self)
