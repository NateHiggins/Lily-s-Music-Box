extends Node3D
## Installs the authored B08 lobby encounter using the normal resident body.
## The schedule owns attendance and the conversation owns any earned facts.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const PERSON := "adela_voss"
const LOBBY := "F01_LOBBY"
const LOBBY_DATE := "1929-07-19"
const CLOCK := "F01_LOBBY_CLOCK_01"
const STANCE_FROM_CLOCK := Vector3(-2.0, 0.0, 0.0)

var world: Node3D
var actor: AnimatedResident
var _binding_refused := false
var _poll_due := 0.0


func _physics_process(delta: float) -> void:
	if world.startup_ms <= 0.0 or _binding_refused:
		return
	_poll_due -= delta
	if _poll_due > 0.0 and not is_instance_valid(actor):
		return
	_poll_due = .2
	if _is_due():
		if not is_instance_valid(actor):
			_mount_resident()
	elif is_instance_valid(actor):
		if world.conversations._active_resident == PERSON:
			world.conversations.cancel_for_transition()
		actor.hide()
		(actor.get_node("Interaction") as Area3D).collision_layer = 0
		actor.queue_free()
		actor = null


func _is_due() -> bool:
	return world.conversations.today() == LOBBY_DATE \
			and str(world.resident_whereabouts(PERSON).get("place", "")) == "lobby"


func _mount_resident() -> void:
	var clocks := world.witness_clocks.get("node") as Node3D
	var clock := clocks.get_node_or_null(CLOCK) as Node3D if is_instance_valid(clocks) else null
	if not is_instance_valid(clock):
		_refuse("the installed lobby clock is missing")
		return
	var origin: Vector3 = clock.global_position + world.adapter.root.global_basis * STANCE_FROM_CLOCK
	var space := get_world_3d().direct_space_state
	var floor := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,
			origin - Vector3.UP * 3.0, 1, [world.player.get_rid()]))
	if floor.is_empty() or floor.normal.y < 0.85 or world.room_at_world(floor.position + Vector3.UP * .8) != LOBBY:
		_refuse("the clock-side marker has no lobby floor")
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = .43
	capsule.height = 1.72
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.collision_mask = 1
	clearance.exclude = [world.player.get_rid()]
	clearance.transform.origin = floor.position + Vector3.UP * (capsule.height * .5 + .025)
	if not space.intersect_shape(clearance, 1).is_empty():
		_refuse("the clock-side standing volume is blocked")
		return
	var resident := Presentation.new()
	resident.setup("Adela Voss", PERSON, "", CastBodies.cast_model(PERSON))
	resident.externally_driven = true
	resident.face_interacting_player = true
	resident.position = to_local(floor.position)
	add_child(resident)
	if resident.cast_body == null or not resident.cast_body.ready_ok:
		resident.hide()
		resident.queue_free()
		_refuse("the existing rebuilt resident body did not load")
		return
	resident.look_at(Vector3(clock.global_position.x, resident.global_position.y, clock.global_position.z))
	actor = resident


func _refuse(reason: String) -> void:
	_binding_refused = true
	push_error("Friday lobby encounter: " + reason)
