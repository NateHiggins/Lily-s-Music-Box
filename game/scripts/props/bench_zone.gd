class_name LobbyBenchZone
extends StaticBody3D
## The foyer bench, made sittable. The generated settle is batched
## geometry, so this zone stands in front of it and owns the verb: sit,
## and the player parks on the seat at crouch eye-height facing the
## lobby; sit again to stand and get your legs back. Teresa's haunt is
## this bench — the player is borrowing her favorite seat.

var seated := false
var _stored_position := Vector3.ZERO
var _stored_yaw := 0.0


func _ready() -> void:
	name = "LobbyBenchZone"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 0.9, 0.7)
	shape.shape = box
	shape.position.y = 0.45
	add_child(shape)


func interact_prompt() -> String:
	return "[E]  Stand up" if seated else "[E]  Sit on the bench"


func interact(player: Node) -> void:
	if player == null or not player is PlayerController:
		return
	var pc := player as PlayerController
	if seated:
		pc.global_position = _stored_position
		pc.rotation.y = _stored_yaw
		pc._set_crouched(false)
		pc.end_seated_interaction(self)
		seated = false
		return
	_stored_position = pc.global_position
	_stored_yaw = pc.rotation.y
	pc.global_position = global_position + Vector3(0, 0.02, -0.18)
	pc.rotation.y = 0.0  # face north, into the lobby, like Teresa does
	pc.velocity = Vector3.ZERO
	pc._set_crouched(true)
	pc.begin_seated_interaction(self)
	seated = true
