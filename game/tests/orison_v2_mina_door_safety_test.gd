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
	RealityState.reset_campaign_for_tests()
	call_deferred("_run")

func _run() -> void:
	await _context(Vector3.ZERO, 0.0, false)
	await _context(Vector3(12, 6, -19), .73, true)
	await _animated_passage_release()
	# The mixer retires stopped decoders asynchronously after scene destruction.
	await get_tree().create_timer(.25).timeout
	print("V2 MINA DOOR SAFETY: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _animated_passage_release() -> void:
	var frame := Node3D.new()
	add_child(frame)
	var routine := Routine.new()
	frame.add_child(routine)
	routine.set_physics_process(false)
	var mina := AnimatedResident.new()
	mina.setup("Mina Vale", "mina_vale", "2A", "res://assets/characters/mina_vale/mina_vale.gltf")
	mina.externally_driven = true
	frame.add_child(mina)
	mina.position = Vector3(.455, 0, -2)
	routine.actor = mina
	var door := DoorProp.new()
	frame.add_child(door)
	await get_tree().physics_frame
	door.npc_set_open(true, "mina_vale")
	await get_tree().create_timer(.6).timeout
	routine._door_passages[door] = {"side":1.0,"opened":true,"revision":door.motion_revision,"gesture":true}
	var revision := door.motion_revision
	routine._release_passed_doors()
	_check("production Mina releases passage without a close or lock gesture",
		door.open and not mina.mina_animation.route_busy and routine._door_passages.is_empty()
		and door.motion_revision == revision)
	# No route-owned delayed gesture may undo a later explicit operation.
	door.interact(null)
	await get_tree().create_timer(.6).timeout
	door.interact(null)
	await get_tree().create_timer(.6).timeout
	routine._release_passed_doors()
	routine._release_passed_doors()
	_check("later explicit opening remains with the leaf owner", door.open
		and not mina.mina_animation.route_busy and routine._door_passages.is_empty())
	mina.mina_animation.finish_conversation(true)
	mina.mina_animation.update(2.0)
	_check("thanks cannot cue a stale door contact", not mina.mina_animation.action_contact_ready())
	frame.queue_free()
	await get_tree().physics_frame

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
	door.name = "MinaDoorSafetyOutward" if outward else "MinaDoorSafetyInward"
	door.width = .91
	door.swing_out = outward
	# The refusal control is a real private unit without a player/visitor key.
	# A generic unit-less service leaf is legitimately unlockable by the player.
	door.unit = "6C"
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
	_check("stationary locked leaf retains its refusal prompt", door.interact_prompt() == "[E]  Locked")
	var revision := door.motion_revision
	door.interact(player)
	_check("locked player interaction does not take motion ownership", door.motion_revision == revision)
	_check("locked passage refuses movement without changing lock", not routine._route_doors_ready(.02)
		and door.leaf_state == "locked" and not door.open)
	_check("unauthorized approach does not retain closer custody", not door.passage_held())
	door.leaf_state = "closed"
	var angle := door.motion_target_angle(true) * .5
	neighbour.global_position = frame.to_global(Basis(Vector3.UP, angle) * Vector3(.65, 0, 0))
	_check("neighbour inside opening arc keeps leaf stationary", not routine._route_doors_ready(.02)
		and not door.open and not door._moving)
	neighbour.position = Vector3(6, 0, 6)
	_check("opening request still holds until the owner settles", not routine._route_doors_ready(.02)
		and door.open and door._moving)
	_check("authorized active approach holds the real closer", door.passage_held())
	_check("opening leaf does not advertise an unavailable action", door.interact_prompt().is_empty())
	revision = door.motion_revision
	door.interact(player)
	_check("in-flight refused interaction does not take motion ownership", door.motion_revision == revision)
	var still := resident.global_position
	for _i in 12:
		await get_tree().physics_frame
		_check("in-flight leaf refuses readiness", not routine._route_doors_ready(.02))
	_check("waiting never relocates the actor", resident.global_position == still)
	await _settle(door)
	_check("settled leaf releases the passage", routine._route_doors_ready(.02) and door.is_ready_for_passage())
	_check("settled open leaf offers closing", door.interact_prompt() == "[E]  Close door")
	# Move the fixture occupant to the far side; full production movement is
	# asserted separately. Do not make a claim that this placement walked.
	resident.global_position = frame.to_global(goal)
	routine.path = PackedInt64Array()
	neighbour.global_position = frame.to_global(Basis(Vector3.UP, angle) * Vector3(.65, 0, 0))
	_check("neighbour inside closing arc is still unsafe for explicit motion", not routine._door_motion_clear(door, false))
	revision = door.motion_revision
	var released_angle := door._body.rotation.y
	routine._release_passed_doors()
	_check("completed passage releases custody without closing on neighbour", door.open and not door._moving
		and routine._door_passages.is_empty() and door.motion_revision == revision
		and is_equal_approx(door._body.rotation.y, released_angle) and not door.passage_held())
	# The same horizontal position on another floor is not an occupant.
	neighbour.position.y += 4.0
	_check("different-floor neighbour does not occupy the swing", routine._door_motion_clear(door, false))
	player.position = Vector3(.455, 0, 0)
	_check("player in doorway remains an obstruction to explicit closing", not routine._door_motion_clear(door, false))
	routine._release_passed_doors()
	_check("released route never issues a close on the player", door.open and not door._moving
		and routine._door_passages.is_empty() and door.motion_revision == revision)
	player.position = Vector3(8, 0, 8)
	await get_tree().create_timer(4.2).timeout
	_check("no-closer door stays at the released angle after the former delay", door.open and not door._moving
		and is_equal_approx(door._body.rotation.y, released_angle) and door.motion_revision == revision)
	_check("clear swing admits an explicit close", routine._door_motion_clear(door, false))
	door.npc_set_open(false, resident.resident_id)
	_check("explicit close starts through the real door owner", not door.open and door._moving)
	_check("closing leaf does not advertise an unavailable action", door.interact_prompt().is_empty())
	await _settle(door)
	_check("real leaf finishes closed", not door.open and not door._moving
		and absf(door._body.rotation.y) < .0001)
	_check("settled closed leaf offers opening", door.interact_prompt() == "[E]  Open door")
	# Existing player-open leaves remain propped after the resident passes.
	door.interact(null)
	await _settle(door)
	resident.global_position = frame.to_global(start)
	routine.path = PackedInt64Array([0, 1])
	# This fixture disables controller renewal. Snapshot its one-second lease
	# before stdout can stall; preserve the timestamps for any later failure.
	var open_ready := routine._route_doors_ready(.02)
	var observed_at := Time.get_ticks_msec()
	var lease: Dictionary = door._passage_holds.get(resident.get_instance_id(), {}).duplicate()
	var open_held := door.passage_held()
	var record_present := routine._door_passages.has(door)
	print("MINA OPEN LEASE ", {"outward": outward, "at_ms": observed_at, "until_ms": lease.get("until", -1), "record": record_present, "held": open_held, "local": door.to_local(resident.global_position)})
	_check("existing open passage is usable", open_ready)
	_check("already-open approach also retains closer custody", record_present and open_held)
	resident.global_position = frame.to_global(goal)
	routine.path = PackedInt64Array()
	routine._release_passed_doors()
	_check("resident does not close a door opened by somebody else", door.open and not door._moving
		and routine._door_passages.is_empty() and not door.passage_held())
	# An approach is not permanent ownership. An accepted newer operation
	# supersedes the resident's record even before the resident crosses.
	door.interact(null)
	await _settle(door)
	resident.global_position = frame.to_global(start)
	routine.path = PackedInt64Array([0, 1])
	_check("Mina acquires a fresh opening", not routine._route_doors_ready(.02) and door.open)
	await _settle(door)
	_check("opening keeps its approach record until crossing", not routine._door_passages.is_empty())
	door.interact(player)
	await _settle(door)
	door.interact(player)
	await _settle(door)
	revision = door.motion_revision
	routine._release_passed_doors()
	_check("player's later reopening retires stale passage ownership", door.open and not door._moving
		and routine._door_passages.is_empty() and door.motion_revision == revision and not door.passage_held())
	# Abandoning an approach also releases it, without undoing its opening.
	routine._door_passages[door] = {"side":side,"opened":true,"revision":door.motion_revision,"gesture":false}
	door.hold_passage(resident)
	resident.global_position = frame.to_global(Vector3(3, 0, side * 3))
	routine.path = PackedInt64Array()
	routine._release_passed_doors()
	_check("abandoned approach releases without a delayed close", door.open and not door._moving
		and routine._door_passages.is_empty() and door.motion_revision == revision and not door.passage_held())
	# The actual route caller may now use Mina's original on her own lock.
	# Sweep clearance and motion revision remain with their existing owners.
	door.interact(null)
	await _settle(door)
	door.unit = "2A"
	door.leaf_state = "locked"
	DoorKeyring.remember_lock(door, true)
	resident.resident_id = "mina_vale"
	resident.global_position = frame.to_global(start)
	routine.path = PackedInt64Array([0,1])
	_check("Mina's original opens her own locked route through the owner",
		not routine._route_doors_ready(.02) and door.open and door._moving)
	await _settle(door)
	_check("original-key route waits for the settled physical leaf",routine._route_doors_ready(.02))
	resident.global_position = frame.to_global(goal)
	routine.path = PackedInt64Array()
	routine._release_passed_doors()
	await _settle(door)
	_check("Mina leaves her authorized opening usable after passing",
		door.open and door.leaf_state == "closed" and routine._door_passages.is_empty()
		and door.is_ready_for_passage())
	_check("authorized passage unlock persists instead of restoring a locked open leaf",
		DoorKeyring.initial_state(door, "locked") == "closed")
	# A save/hand interruption can leave a real positive angle too narrow to
	# cross. It must complete its tween, without placing or exempting the body.
	door.restore_mechanism({"angle": door.motion_target_angle(true) * .25})
	resident.global_position = frame.to_global(start)
	routine.path = PackedInt64Array([0, 1])
	await get_tree().physics_frame
	_check("restored partial leaf is open but not a ready passage", door.open and not door.is_ready_for_passage())
	still = resident.global_position
	_check("partial opening continues through the real motion owner", not routine._route_doors_ready(.02)
		and door._moving and door.passage_held())
	await _settle(door)
	_check("continued opening reaches the authored stop without actor relocation", routine._route_doors_ready(.02)
		and is_equal_approx(door._body.rotation.y, door.motion_target_angle(true)) and resident.global_position == still)
	# A controller renewing its approach keeps the closer paused. A controller
	# no longer running must not leave an indefinite invisible hold behind.
	await get_tree().create_timer(.6).timeout
	_check("active approach renews its closer lease", routine._route_doors_ready(.02))
	await get_tree().create_timer(.6).timeout
	_check("renewed lease lasts beyond the original acquisition", door.passage_held())
	await get_tree().create_timer(.6).timeout
	_check("stopped controller's lease expires", not door.passage_held())
	_check("resumed approach reacquires the closer", routine._route_doors_ready(.02) and door.passage_held())
	routine.free()
	_check("retired route releases its remaining closer custody", not door.passage_held())
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
