extends Node3D
## Scoped door-coordination fixture; the domestic/laundry suites separately
## prove ordinary timetable-driven walking through the composed V2 building.
const Routine := preload("res://scripts/characters/orison_v2_mina_routine.gd")

class Resident extends AnimatedResident:
	func _ready() -> void:
		externally_driven = true
		add_to_group("animated_residents")
		_build_interaction()

class Player extends PlayerController:
	func _ready() -> void:
		add_to_group("player_controller")
		set_physics_process(false)
		set_process(false)
		set_process_unhandled_input(false)

var checks := 0
var failures: Array[String] = []

func _ready() -> void:
	RealityState.persistence_enabled = false
	call_deferred("_run")

func _run() -> void:
	await _context(Vector3.ZERO, 0.0, false)
	await _context(Vector3(12, 6, -19), .73, true)
	print("V2 MINA DOOR SAFETY: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _context(origin: Vector3, yaw: float, outward: bool) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	add_child(viewport)
	var frame := Node3D.new()
	frame.position = origin
	frame.rotation.y = yaw
	viewport.add_child(frame)
	var routine := Routine.new()
	frame.add_child(routine)
	routine.set_physics_process(false)
	var resident := Resident.new()
	frame.add_child(resident)
	routine.actor = resident
	var neighbour := Resident.new()
	frame.add_child(neighbour)
	neighbour.position = Vector3(6, 0, 6)
	var player := Player.new()
	frame.add_child(player)
	player.position = Vector3(8, 0, 8)
	var door := DoorProp.new()
	door.width = .91
	door.swing_out = outward
	frame.add_child(door)
	routine._doors.assign([door])
	var side := 1.0 if outward else -1.0
	var start := Vector3(.455, 0, side * 1.3)
	var goal := Vector3(.455, 0, -side * 2)
	resident.global_position = frame.to_global(start)
	routine.graph.add_point(0, frame.to_global(Vector3(.455, 0, 0)))
	routine.graph.add_point(1, frame.to_global(goal))
	routine.graph.add_point(2, frame.to_global(Vector3(1, 0, side * 1.3)))
	routine.path = PackedInt64Array([2])
	await get_tree().physics_frame
	_check("nearby parallel route does not acquire or open door", routine._route_doors_ready(.02)
		and not door.open and routine._door_passages.is_empty())
	routine.path = PackedInt64Array([0, 1])
	_check("route through on-plane waypoint selects real aperture", routine._route_crosses_door(door))
	door.leaf_state = "locked"
	_check("locked passage refuses movement without changing lock", not routine._route_doors_ready(.02)
		and door.leaf_state == "locked" and not door.open)
	door.leaf_state = "closed"
	var angle := door.motion_target_angle(true) * .5
	neighbour.global_position = frame.to_global(Basis(Vector3.UP, angle) * Vector3(.65, 0, 0))
	_check("neighbour inside opening arc keeps leaf stationary", not routine._route_doors_ready(.02)
		and not door.open and not door._moving)
	neighbour.position = Vector3(6, 0, 6)
	_check("opening request still holds until the owner settles", not routine._route_doors_ready(.02)
		and door.open and door._moving)
	var still := resident.global_position
	for _i in 12:
		await get_tree().physics_frame
		_check("in-flight leaf refuses readiness", not routine._route_doors_ready(.02))
	_check("waiting never relocates the actor", resident.global_position == still)
	await _settle(door)
	_check("settled leaf releases the passage", routine._route_doors_ready(.02) and door.is_ready_for_passage())
	# Move the fixture occupant to the far side; full production movement is
	# asserted separately. Do not make a claim that this placement walked.
	resident.global_position = frame.to_global(goal)
	routine.path = PackedInt64Array()
	neighbour.global_position = frame.to_global(Basis(Vector3.UP, angle) * Vector3(.65, 0, 0))
	routine._close_passed_doors()
	_check("neighbour inside closing arc keeps passage pending", door.open and not door._moving
		and not routine._door_passages.is_empty())
	# The same horizontal position on another floor is not an occupant.
	neighbour.position.y += 4.0
	player.position = Vector3(.455, 0, 0)
	routine._close_passed_doors()
	_check("player in doorway also holds the close request", door.open and not door._moving
		and not routine._door_passages.is_empty())
	player.position = Vector3(8, 0, 8)
	door.leaf_state = "locked"
	routine._close_passed_doors()
	_check("a newly locked door does not lose the pending close", door.open and not routine._door_passages.is_empty())
	door.leaf_state = "closed"
	routine._close_passed_doors()
	_check("clearance and unlock retry through the real door owner", not door.open and door._moving
		and routine._door_passages.is_empty())
	await _settle(door)
	_check("real leaf finishes closed", not door.open and not door._moving
		and absf(door._body.rotation.y) < .0001)
	# Existing player-open leaves remain propped after the resident passes.
	door.interact(null)
	await _settle(door)
	resident.global_position = frame.to_global(start)
	routine.path = PackedInt64Array([0, 1])
	_check("existing open passage is usable", routine._route_doors_ready(.02))
	resident.global_position = frame.to_global(goal)
	routine.path = PackedInt64Array()
	routine._close_passed_doors()
	_check("resident does not close a door opened by somebody else", door.open and not door._moving
		and routine._door_passages.is_empty())
	viewport.queue_free()
	for _i in 3: await get_tree().process_frame

func _settle(door: DoorProp) -> void:
	for _i in 120:
		if not door._moving:
			# AnimatableBody publishes the tween's final pose on the next tick.
			await get_tree().physics_frame
			await get_tree().physics_frame
			return
		await get_tree().physics_frame
	_check("door tween finished within deadline", false)

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("[MINA DOORS] %s %s" % ["PASS" if ok else "FAIL", label])
