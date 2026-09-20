extends Node3D
## Actual DoorProp tween and ResidentRoutines caller coverage in private worlds.
## The identical composed F06 route fixture remains a separate acceptance gate.

const BODY_RADIUS := 0.28
const BODY_HEIGHT := 1.55
const STEP := 1.0 / 60.0
const ROUTE_STAGES := [ResidentRoutines.Stage.HOME, ResidentRoutines.Stage.TO_LIFT,
	ResidentRoutines.Stage.AT_HAUNT, ResidentRoutines.Stage.ON_STAIRS,
	ResidentRoutines.Stage.RETURN_STAIRS]

var checks: Array[Dictionary] = []
var measurements: Array[Dictionary] = []
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _context(Vector3.ZERO, 0.0, false, 0)
	await _context(Vector3(17.0, 8.0, -23.0), 0.73, true, 1)
	await _finish()


func _context(origin: Vector3, yaw: float, outward: bool, index: int) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	var frame := Node3D.new()
	frame.position = origin
	frame.rotation.y = yaw
	viewport.add_child(frame)
	_box(frame, "Support", Vector3(0, -0.1, 0), Vector3(8, 0.2, 8))
	_box(frame, "LeftMasonry", Vector3(-2.245, 1.2, 0), Vector3(3.51, 2.4, 0.18))
	_box(frame, "RightMasonry", Vector3(2.245, 1.2, 0), Vector3(3.51, 2.4, 0.18))
	var door := DoorProp.new()
	door.name = "ReadinessDoor_%d" % index
	door.width = 0.91
	door.height = 2.13
	door.door_kind = "apartment_entry"
	door.swing_out = outward
	door.position = Vector3(-door.width * 0.5, 0, 0)
	frame.add_child(door)
	var routines := ResidentRoutines.new()
	viewport.add_child(routines)
	routines.set_process(false)
	var side := 1.0 if outward else -1.0
	var start: Vector3 = frame.to_global(Vector3(0, 0.03, side * 1.25))
	var goal: Vector3 = frame.to_global(Vector3(0, 0.03, -side * 2.0))
	var actors: Array[Dictionary] = []
	for stage in ROUTE_STAGES:
		actors.append(_actor(frame, door, int(stage), start, goal))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var label := "frame %d" % index
	_check(label + " closed actual leaf blocks the centre crossing",
		not _body_clear(viewport, start, goal))
	_check(label + " neighbouring masonry remains blocking",
		not _body_clear(viewport, frame.to_global(Vector3(1.2, 0.03, -1)),
			frame.to_global(Vector3(1.2, 0.03, 1))))
	_check(label + " the hold position is outside the physical leaf sweep",
		_body_clear(viewport, start, start))
	_check(label + " closed owner reports no passage readiness",
		door.has_method("is_ready_for_passage") and not bool(door.call("is_ready_for_passage")))
	var held: Array[bool] = [true, true, true, true, true]
	var body_clear := true
	for i in actors.size():
		routines._step(actors[i], STEP)
		held[i] = actors[i].node.global_position.is_equal_approx(start)
		_check(label + " stage %d holds on the opening request" % ROUTE_STAGES[i], held[i])
		_check(label + " stage %d uses its idle clip while waiting" % ROUTE_STAGES[i],
			actors[i].anim.current_animation == "Fixture_Idle")
	_check(label + " open flag alone is insufficient during the real tween",
		door.open and door._moving and door.has_method("is_ready_for_passage")
		and not bool(door.call("is_ready_for_passage")))
	var opening_frames := 0
	while door._moving and opening_frames < 180:
		await get_tree().physics_frame
		if not door._moving: break
		opening_frames += 1
		for i in actors.size():
			var before: Vector3 = actors[i].node.global_position
			routines._step(actors[i], STEP)
			held[i] = held[i] and actors[i].node.global_position.is_equal_approx(start)
			body_clear = body_clear and _body_clear(viewport, before, actors[i].node.global_position)
	_check(label + " actual opening reaches settled state within the frame budget",
		opening_frames > 0 and door.open and not door._moving)
	for i in actors.size():
		_check(label + " stage %d waits throughout the moving leaf" % ROUTE_STAGES[i], held[i])
	_check(label + " no capsule overlaps the leaf while residents wait", body_clear)
	_check(label + " settled owner reports passage readiness",
		door.has_method("is_ready_for_passage") and bool(door.call("is_ready_for_passage")))
	for actor in actors:
		var before: Vector3 = actor.node.global_position
		routines._step(actor, STEP)
		_check(label + " settled leaf releases stage %d" % int(actor.stage),
			actor.node.global_position.distance_to(before) > 0.001
			and actor.anim.current_animation == "Fixture_Walk")
	# One of those actual route callers now traverses the full aperture.
	# Queries include the floor, jambs and moving leaf, with no RID exclusions.
	var walker: Dictionary = actors[2]
	var walk_frames := 0
	var walk_clear := true
	while int(walker.leg) < walker.path.size() and walk_frames < 360:
		await get_tree().physics_frame
		var before: Vector3 = walker.node.global_position
		routines._step(walker, STEP)
		walk_clear = walk_clear and _body_clear(viewport, before, walker.node.global_position)
		walk_frames += 1
	_check(label + " full production walk crosses the real leaf without body contact",
		int(walker.leg) >= walker.path.size() and walk_clear
		and walker.node.global_position.distance_to(goal) < 0.17)
	_check(label + " departure closes behind the resident asynchronously",
		int(walker.door_cycle) == 2 and not door.open)
	_check(label + " close animation settles", await _settled(door))
	# Return through the same closed physical leaf from the other side. HOME
	# closes on arrival near home rather than using the departure distance.
	var returning: Dictionary = actors[0]
	var return_home: Vector3 = frame.to_global(Vector3(0, 0.03, side * 2.0))
	_reset(returning, goal, return_home)
	var return_frames := 0
	var return_clear := true
	var return_opened := false
	var return_held_frames := 0
	while int(returning.leg) < returning.path.size() and return_frames < 420:
		await get_tree().physics_frame
		var before: Vector3 = returning.node.global_position
		routines._step(returning, STEP)
		return_clear = return_clear and _body_clear(viewport, before, returning.node.global_position)
		return_opened = return_opened or door.open
		if door._moving and returning.node.global_position.is_equal_approx(before):
			return_held_frames += 1
		return_frames += 1
	_check(label + " full HOME return opens and waits for the actual leaf",
		return_opened and return_held_frames > 0)
	_check(label + " full HOME return reaches home without any body exclusion",
		int(returning.leg) >= returning.path.size() and return_clear
		and returning.node.global_position.distance_to(return_home) < 0.17)
	_check(label + " HOME return closes the actual leaf behind the resident",
		int(returning.door_cycle) == 2 and not door.open)
	_check(label + " return close settles", await _settled(door))
	# A locked leaf refuses every caller; removing the lock retries the same
	# pending route instead of claiming that a rejected request opened it.
	door.leaf_state = "locked"
	for actor in actors:
		_reset(actor, start, goal)
		routines._step(actor, STEP)
		_check(label + " locked owner holds stage %d" % int(actor.stage),
			actor.node.global_position.is_equal_approx(start)
			and int(actor.door_cycle) == 0 and not door.open and not door._moving)
	door.leaf_state = "closed"
	routines._step(walker, STEP)
	_check(label + " unlocking retries through the actual owner while still holding",
		door.open and door._moving and walker.node.global_position.is_equal_approx(start))
	_check(label + " retried opening settles", await _settled(door))
	# A player starts closing after the resident has already opened the door.
	# The resident must wait out that owner, request opening again, and wait
	# for the second real tween; no timer or test directly clears _moving.
	walker.door_cycle = 1
	door.npc_set_open(false)
	var closing_was_real := not door.open and door._moving
	var reopening_seen := false
	var held_during_retry := true
	var retry_frames := 0
	while retry_frames < 240:
		await get_tree().physics_frame
		var ready_before := door.open and not door._moving and door.leaf_state != "locked"
		var before: Vector3 = walker.node.global_position
		routines._step(walker, STEP)
		if not ready_before:
			held_during_retry = held_during_retry and walker.node.global_position.is_equal_approx(before)
		reopening_seen = reopening_seen or (door.open and door._moving)
		retry_frames += 1
		if door.open and not door._moving: break
	_check(label + " a player closing the leaf cannot resume the resident prematurely",
		closing_was_real and held_during_retry and reopening_seen
		and door.open and not door._moving and retry_frames < 240)
	# Refused close: a passed resident may keep walking while an opening
	# tween or a lock prevents closing. Keep the request pending until accepted.
	door.npc_set_open(false)
	_check(label + " close-request fixture settles", await _settled(door))
	door.npc_set_open(true)
	walker.node.global_position = goal
	walker.door_cycle = 1
	routines._manage_home_door(walker, false)
	_check(label + " refused close during opening stays pending",
		int(walker.door_cycle) == 1 and door.open and door._moving)
	var close_frames := 0
	while door.open and close_frames < 180:
		await get_tree().physics_frame
		routines._manage_home_door(walker, false)
		close_frames += 1
	_check(label + " pending close retries and completes its cycle when accepted",
		int(walker.door_cycle) == 2 and not door.open and door._moving)
	_check(label + " accepted close settles", await _settled(door))
	door.npc_set_open(true)
	_check(label + " locked-close fixture opens", await _settled(door))
	door.leaf_state = "locked"
	walker.door_cycle = 1
	routines._manage_home_door(walker, false)
	_check(label + " locked close remains pending without overriding the lock",
		int(walker.door_cycle) == 1 and door.open and not door._moving)
	door.leaf_state = "closed"
	routines._manage_home_door(walker, false)
	_check(label + " unlocking permits the pending close through its owner",
		int(walker.door_cycle) == 2 and not door.open and door._moving)
	# Non-crossing routes are unaffected, even while that close is moving.
	for actor in actors:
		_reset(actor, goal, goal - frame.global_basis.z * side * 2.0)
		actor.door_cycle = 2
		var before: Vector3 = actor.node.global_position
		routines._step(actor, STEP)
		_check(label + " passed stage %d continues during asynchronous closing" % int(actor.stage),
			actor.node.global_position.distance_to(before) > 0.001)
		_reset(actor, start + frame.global_basis.z * side * 2.0, goal)
		before = actor.node.global_position
		routines._step(actor, STEP)
		_check(label + " far stage %d keeps approaching" % int(actor.stage),
			actor.node.global_position.distance_to(before) > 0.001)
		_reset(actor, start, goal)
		actor.home_door = null
		before = actor.node.global_position
		routines._step(actor, STEP)
		_check(label + " no-door stage %d keeps moving" % int(actor.stage),
			actor.node.global_position.distance_to(before) > 0.001)
		actor.home_door = door
	_check(label + " final owned tween settles before retirement", await _settled(door))
	measurements.append({"origin": _v(origin), "yaw": yaw, "swing_out": outward,
		"opening_frames": opening_frames, "walk_frames": walk_frames,
		"return_frames": return_frames, "return_held_frames": return_held_frames,
		"return_clear": return_clear,
		"retry_frames": retry_frames, "close_retry_frames": close_frames,
		"body_radius": BODY_RADIUS, "body_height": BODY_HEIGHT,
		"movement_collider_exclusions": 0, "walk_clear": walk_clear})
	var retired: WeakRef = weakref(viewport.find_world_3d())
	viewport.queue_free()
	viewport = null
	routines = null
	door = null
	frame = null
	actors.clear()
	walker.clear()
	returning.clear()
	for _i in 4: await get_tree().process_frame
	_check(label + " private world retires", retired.get_ref() == null)


func _actor(parent: Node3D, door: DoorProp, stage: int, start: Vector3, goal: Vector3) -> Dictionary:
	var node := Node3D.new()
	parent.add_child(node)
	# Tiny named clips prove the real _play role selection without loading
	# a character rig or replacing production animation ownership.
	var anim := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for clip_name in ["Fixture_Idle", "Fixture_Walk"]:
		var clip := Animation.new()
		clip.length = 1.0
		clip.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip_name, clip)
	anim.add_animation_library("", library)
	node.add_child(anim)
	var actor := {"node": node, "slug": "door_fixture", "anim": anim,
		"stage": stage, "home_door": door, "haunt": goal, "at_venue": false,
		"target_floor": "", "hidden_for": 0.0, "unit": "", "sched_key": ""}
	_reset(actor, start, goal)
	return actor


func _reset(actor: Dictionary, start: Vector3, goal: Vector3) -> void:
	actor.node.global_position = start
	actor.timer = 600.0
	actor.path = PackedVector3Array([goal])
	actor.leg = 0
	actor.door_cycle = 0
	actor.home = goal if int(actor.stage) in [ResidentRoutines.Stage.HOME,
		ResidentRoutines.Stage.RETURN_STAIRS] else start


func _settled(door: DoorProp) -> bool:
	for _i in 180:
		if not door._moving: return true
		await get_tree().physics_frame
	return not door._moving


func _box(parent: Node3D, label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _body_clear(viewport: SubViewport, from: Vector3, to: Vector3) -> bool:
	# Same physical Body dimensions as both production resident constructors.
	# The .33/1.65 conservative navigation envelope is deliberately unchanged.
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.margin = 0.001
	query.collide_with_areas = false
	query.transform = Transform3D(Basis(), from + Vector3.UP * BODY_HEIGHT * 0.5)
	var space := viewport.find_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin = to + Vector3.UP * BODY_HEIGHT * 0.5
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.transform.origin = from + Vector3.UP * BODY_HEIGHT * 0.5
	query.motion = to - from
	if query.motion.is_zero_approx(): return true
	var fractions := space.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0 and fractions[1] >= 1.0


func _v(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


func _check(label: String, ok: bool) -> void:
	checks.append({"label": label, "ok": ok})
	if not ok: failures += 1
	print("[DOOR READINESS] %s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(output)
		var file: FileAccess = FileAccess.open(output.path_join("resident_door_readiness.json"), FileAccess.WRITE) if error == OK else null
		if file == null:
			_check("requested scoped evidence can be written", false)
		else:
			file.store_string(JSON.stringify({"schema": "orison.resident-door-readiness-test.v1",
				"scope": "Actual DoorProp state/tweens and five ResidentRoutines route callers in translated/rotated private worlds. Body overlap and sweeps have zero collider exclusions. No composed F06, whole-autonomy, performance or runtime_contract admission.",
				"checks": checks, "failures": failures, "measurements": measurements}, "\t"))
			file.flush()
			var written: bool = file.get_error() == OK
			file.close()
			if not written: _check("requested scoped evidence was flushed", false)
	print("[DOOR READINESS] RESULT %d/%d" % [checks.size() - failures, checks.size()])
	get_tree().quit(0 if failures == 0 else 1)
