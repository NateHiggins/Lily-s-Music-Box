class_name BarSeatZone
extends StaticBody3D
## A couch module made sittable, same pattern as the lobby bench: the
## zone stands at the seat and owns the verb. It is also a SOCKET — a
## scheduled resident arriving at the bar claims a free one (routines
## sets `occupied_by`) and settles into it, so the Friday crowd sits on
## the couches instead of standing in a knot at the anchor point.

var seated := false            # the player
var occupied_by := ""          # a resident's slug, set by routines
var _stored_position := Vector3.ZERO
var _stored_yaw := 0.0


func setup(size := Vector3(1.1, 0.9, 0.7)) -> void:
	add_to_group("bar_seats")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = 0.45
	add_child(shape)


func interact_prompt() -> String:
	if seated:
		return "[E]  Stand up"
	if occupied_by != "":
		return "Taken"
	return "[E]  Sit down"


func interact(player: Node) -> void:
	if player == null or not player is PlayerController:
		return
	if occupied_by != "" and not seated:
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
	pc.global_position = global_position + Vector3(0, 0.02, 0)
	pc.rotation.y = rotation.y
	pc.velocity = Vector3.ZERO
	pc._set_crouched(true)
	pc.begin_seated_interaction(self)
	seated = true
