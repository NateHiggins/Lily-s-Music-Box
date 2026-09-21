extends "res://tests/resident_door_readiness_test.gd"
## Uses the existing independent actual-capsule probe and real DoorProp owner.
## No navigation mutation, mocked readiness, collider exclusion or fake tween.

const WALKING_STAGES := [ResidentRoutines.Stage.HOME, ResidentRoutines.Stage.PACING,
	ResidentRoutines.Stage.WATCHING, ResidentRoutines.Stage.TO_LIFT,
	ResidentRoutines.Stage.AT_HAUNT, ResidentRoutines.Stage.RETURNING,
	ResidentRoutines.Stage.ON_STAIRS, ResidentRoutines.Stage.RETURN_STAIRS,
	ResidentRoutines.Stage.STREET]


func _run() -> void:
	await _service_context(Vector3.ZERO, 0.0, false, 0)
	await _service_context(Vector3(-19, 11, 27), -0.81, true, 1)
	_finish()


func _service_context(origin: Vector3, yaw: float, outward: bool, index: int) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	var frame := Node3D.new()
	frame.position = origin
	frame.rotation.y = yaw
	viewport.add_child(frame)
	_box(frame, "Support", Vector3(0, -0.1, 0), Vector3(16, 0.2, 12))
	_box(frame, "LeftMasonry", Vector3(-2.25, 1.2, 0), Vector3(3.48, 2.4, 0.18))
	_box(frame, "RightMasonry", Vector3(2.25, 1.2, 0), Vector3(3.48, 2.4, 0.18))
	var door: DoorProp = _service(frame, "RouteDoor_%d" % index, Vector3(-0.48, 0, 0), outward)
	var off_route: DoorProp = _service(frame, "OffRouteDoor_%d" % index, Vector3(2.4, 0, 0), outward)
	var routines := ResidentRoutines.new()
	viewport.add_child(routines)
	routines.set_process(false)
	var side := 1.0 if outward else -1.0
	var hold: Vector3 = frame.to_global(Vector3(0, 0.03, side * 1.30))
	var start: Vector3 = frame.to_global(Vector3(0, 0.03, side * 2.4))
	var goal: Vector3 = frame.to_global(Vector3(0, 0.03, -side * 2.4))
	var actors: Array[Dictionary] = []
	for stage in WALKING_STAGES:
		actors.append(_actor(frame, null, int(stage), hold, goal))
	routines.actors.assign(actors)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var label := "service frame %d" % index
	_check(label + " service is registered without an apartment home link",
		door.is_in_group("resident_route_doors") and not door.is_in_group("apartment_doors"))
	_check(label + " closed service leaf physically blocks the aperture", not _body_clear(viewport, start, goal))
	_check(label + " masonry remains an independent physical refusal",
		not _body_clear(viewport, frame.to_global(Vector3(1.2, 0.03, -1)),
			frame.to_global(Vector3(1.2, 0.03, 1))))
	for actor in actors:
		var timer_before: float = actor.timer
		routines._step(actor, STEP)
		_check(label + " actual walking stage %d holds and idles without consuming its route timer" % int(actor.stage),
			actor.node.global_position.is_equal_approx(hold)
			and actor.anim.current_animation == "Fixture_Idle" and actor.timer == timer_before)
	_check(label + " open target alone is not settled readiness", door.open and door._moving)
	var opening_clear := true
	var opening_held := true
	var opening_frames := 0
	while door._moving and opening_frames < 180:
		await get_tree().physics_frame
		opening_frames += 1
		if not door._moving: break
		for actor in actors:
			var before: Vector3 = actor.node.global_position
			routines._step(actor, STEP)
			opening_held = opening_held and actor.node.global_position.is_equal_approx(before)
			opening_clear = opening_clear and _body_clear(viewport, before, actor.node.global_position)
	_check(label + " all nine callers stay outside the real opening leaf", opening_held and opening_clear and not door._moving)
	for actor in actors:
		var before: Vector3 = actor.node.global_position
		routines._step(actor, STEP)
		_check(label + " settled service releases stage %d" % int(actor.stage),
			actor.node.global_position.distance_to(before) > 0.001)
	# Park the other witnesses. They remain real occupancy records, but are
	# outside the door's sweep while this resident walks both directions.
	var walker: Dictionary = actors[4]
	for actor in actors:
		if actor == walker: continue
		actor.node.global_position = frame.to_global(Vector3(-3.2, 0.03, side * 3.5))
		actor.path = PackedVector3Array()
		actor.leg = 0
	routines._route_doors.tick(routines)
	_reset(walker, start, goal)
	walker.stage = ResidentRoutines.Stage.AT_HAUNT
	var departure: Dictionary = await _walk(routines, walker, viewport, door)
	_check(label + " actual non-home departure reaches its goal with zero body exclusions",
		departure.arrived and departure.clear and walker.node.global_position.distance_to(goal) < 0.17)
	_check(label + " departure closes behind only after clearing the full leaf sweep", not door.open)
	_check(label + " departure close settles", await _settled(door))
	walker.stage = ResidentRoutines.Stage.HOME
	_reset(walker, goal, start)
	var returning: Dictionary = await _walk(routines, walker, viewport, door)
	_check(label + " actual HOME return opens and waits for the non-home service leaf",
		returning.opened and int(returning.held_frames) > 0)
	_check(label + " actual return reaches its goal with zero body exclusions",
		returning.arrived and returning.clear and walker.node.global_position.distance_to(start) < 0.17)
	_check(label + " return closes the service leaf behind the resident", not door.open)
	_check(label + " return close settles", await _settled(door))
	_check(label + " nearby off-route leaf stayed closed through both walks", not off_route.open and not off_route._moving)
	# One path crosses the same door twice. The second crossing must be
	# rediscovered after the first passage closes, without replacing the path.
	walker.stage = ResidentRoutines.Stage.AT_HAUNT
	_reset(walker, start, start)
	walker.path = PackedVector3Array([goal, start])
	var looped: Dictionary = await _walk(routines, walker, viewport, door, 900)
	_check(label + " repeated door in one route reopens and clears both crossings",
		looped.arrived and looped.clear and int(looped.open_requests) >= 2
		and walker.node.global_position.distance_to(start) < 0.17)
	var loop_settled: bool = await _settled(door)
	_check(label + " looped passage closes behind", not door.open and loop_settled)
	# A locked service host is an actual refusal, not permission to walk
	# through it. Unlocking retries its existing owner while staying still.
	door.leaf_state = "locked"
	_reset(walker, hold, goal)
	var timer_before: float = walker.timer
	routines._step(walker, STEP)
	_check(label + " locked non-home door holds route and timer",
		walker.node.global_position.is_equal_approx(hold) and walker.timer == timer_before
		and not door.open and not door._moving)
	door.leaf_state = "closed"
	routines._step(walker, STEP)
	_check(label + " unlocking retries through the real owner", door.open and door._moving
		and walker.node.global_position.is_equal_approx(hold))
	_check(label + " unlocked opening settles", await _settled(door))
	door.npc_set_open(false)
	var retry_held := true
	var reopened := false
	for _i in 180:
		await get_tree().physics_frame
		var was_ready: bool = door.is_ready_for_passage()
		var before: Vector3 = walker.node.global_position
		routines._step(walker, STEP)
		if not was_ready: retry_held = retry_held and walker.node.global_position.is_equal_approx(before)
		reopened = reopened or (door.open and door._moving)
		if door.is_ready_for_passage(): break
	_check(label + " player closing motion is waited out and opening retried", retry_held and reopened and door.is_ready_for_passage())
	# A visitor standing in the doorway prevents both the general passage
	# and the linked home owner from closing into the same occupied sweep.
	var neighbour: Dictionary = actors[0]
	neighbour.node.global_position = frame.to_global(Vector3(0, 0.03, 0))
	neighbour.node.visible = true
	neighbour.path = PackedVector3Array()
	var occupied_walk: Dictionary = await _walk(routines, walker, viewport, door)
	_check(label + " passed resident leaves door open for a neighbour in its sweep",
		occupied_walk.arrived and occupied_walk.clear and door.is_ready_for_passage()
		and int(routines._route_doors.stats().pending_closes) > 0)
	walker.home_door = door
	walker.door_cycle = 1
	routines._manage_home_door(walker, false)
	_check(label + " home owner shares visitor occupancy refusal", door.open and int(walker.door_cycle) == 1)
	walker.home_door = null
	door.leaf_state = "locked"
	neighbour.node.global_position = frame.to_global(Vector3(-3.2, 0.03, side * 3.5))
	routines._route_doors.tick(routines)
	_check(label + " vacated but locked close remains pending", door.open and int(routines._route_doors.stats().pending_closes) > 0)
	door.leaf_state = "closed"
	routines._route_doors.tick(routines)
	_check(label + " clear unlocked sweep accepts its pending close", not door.open and door._moving)
	_check(label + " occupancy close settles", await _settled(door))
	# Cancellation before crossing is also a relinquished request. It must
	# close after its current opening settles, even if the actor stops walking.
	_reset(walker, hold, goal)
	routines._step(walker, STEP)
	_check(label + " cancellation begins with an actual opening", door.open and door._moving)
	walker.path = PackedVector3Array([hold + frame.global_basis.x * 0.4])
	routines._step(walker, STEP)
	walker.path = PackedVector3Array()
	for _i in 180:
		await get_tree().physics_frame
		routines._route_doors.tick(routines)
		routines._step(walker, STEP)
		if not door.open and not door._moving: break
	_check(label + " replaced un-crossed route relinquishes and closes without a fabricated passage",
		not door.open and not door._moving and door.to_local(walker.node.global_position).z * side > 0.0
		and int(routines._route_doors.stats().pending_closes) == 0)
	# On-plane off-aperture waypoint: the actual polyline never crosses
	# this opening; a chord formed by dropping that waypoint would do so.
	var outside_start: Vector3 = door.to_global(Vector3(-2, 0.03, 1))
	_reset(walker, outside_start, door.to_global(Vector3(2, 0.03, -1)))
	walker.path = PackedVector3Array([door.to_global(Vector3(-2, 0.03, 0)),
		door.to_global(Vector3(2, 0.03, -1))])
	routines._step(walker, STEP)
	_check(label + " off-aperture on-plane bend does not invent a door crossing",
		not door.open and walker.node.global_position.distance_to(outside_start) > 0.001)
	# Populate an empty cache, then add/move/remove a real door over that
	# path. Host revisions, not a permanent scene snapshot, own discovery.
	var late_start: Vector3 = frame.to_global(Vector3(5, 0.03, side * 1.30))
	var late_goal: Vector3 = frame.to_global(Vector3(5, 0.03, -side * 2.4))
	_reset(walker, late_start, late_goal)
	routines._step(walker, STEP)
	_check(label + " door-free path initially moves", walker.node.global_position.distance_to(late_start) > 0.001)
	var late: DoorProp = _service(frame, "LateDoor_%d" % index, Vector3(4.52, 0, 0), outward)
	_reset(walker, late_start, late_goal)
	routines._step(walker, STEP)
	_check(label + " late-added host invalidates empty selection and holds", late.open and late._moving
		and walker.node.global_position.is_equal_approx(late_start))
	_check(label + " late-added owner settles before removal", await _settled(late))
	var late_ref: WeakRef = weakref(late)
	late.queue_free()
	late = null
	for _i in 2: await get_tree().process_frame
	routines._step(walker, STEP)
	_check(label + " freed host is not retained and no longer gates", late_ref.get_ref() == null
		and walker.node.global_position.distance_to(late_start) > 0.001)
	off_route.position = Vector3(4.52, 0, 0)
	off_route.force_update_transform()
	_reset(walker, late_start, late_goal)
	routines._step(walker, STEP)
	_check(label + " moved host invalidates formerly off-route selection", off_route.open and off_route._moving
		and walker.node.global_position.is_equal_approx(late_start))
	_check(label + " moved host settles before restoring position", await _settled(off_route))
	off_route.position = Vector3(2.4, 0, 0)
	off_route.force_update_transform()
	# Removing the last actor must still retire its pending door request.
	var walker_ref: WeakRef = weakref(walker.node)
	walker.node.queue_free()
	for other in actors:
		if other != walker: other.node.queue_free()
	actors.clear()
	routines.actors.clear()
	walker.clear()
	for _i in 180:
		await get_tree().physics_frame
		routines._route_doors.tick(routines)
		if not off_route.open and not off_route._moving: break
	_check(label + " actor teardown relinquishes its opened request", walker_ref.get_ref() == null
		and not off_route.open and not off_route._moving and int(routines._route_doors.stats().pending_closes) == 0)
	# Foreign-world host at the same global aperture must remain untouched.
	var foreign := SubViewport.new()
	foreign.own_world_3d = true
	foreign.size = Vector2i(64, 64)
	add_child(foreign)
	var foreign_frame := Node3D.new()
	foreign_frame.transform = frame.global_transform
	foreign.add_child(foreign_frame)
	var foreign_door: DoorProp = _service(foreign_frame, "ForeignDoor_%d" % index, Vector3(4.52, 0, 0), outward)
	var independent: Dictionary = _actor(frame, null, ResidentRoutines.Stage.AT_HAUNT, late_start, late_goal)
	routines.actors.append(independent)
	routines._step(independent, STEP)
	_check(label + " same-coordinate foreign World3D host is not opened",
		independent.node.global_position.distance_to(late_start) > 0.001 and not foreign_door.open)
	# The actual subclass overrides _ready. Inherited entry registration is
	# required, rather than relying on ordinary DoorProp's build function.
	var hero := LandmarkEntryDoor.new()
	hero.name = "RegisteredHero_%d" % index
	hero.position = Vector3(-6, 0, 0)
	frame.add_child(hero)
	_check(label + " actual Landmark override inherits route registration", hero.is_in_group("resident_route_doors")
		and is_instance_valid(hero._body))
	measurements.append({"origin": _v(origin), "yaw": yaw, "swing_out": outward,
		"departure": departure, "return": returning, "repeated_route": looped,
		"occupied_walk": occupied_walk, "body_radius": BODY_RADIUS,
		"body_height": BODY_HEIGHT, "movement_collider_exclusions": 0})
	var retired: WeakRef = weakref(viewport.find_world_3d())
	var foreign_retired: WeakRef = weakref(foreign.find_world_3d())
	viewport.queue_free()
	foreign.queue_free()
	viewport = null
	foreign = null
	routines = null
	door = null
	off_route = null
	foreign_door = null
	hero = null
	frame = null
	foreign_frame = null
	actors.clear()
	neighbour.clear()
	independent.clear()
	for _i in 4: await get_tree().process_frame
	_check(label + " private worlds retire with all weak coordinator references", retired.get_ref() == null and foreign_retired.get_ref() == null)


func _service(parent: Node3D, label: String, at: Vector3, outward: bool) -> DoorProp:
	var door := DoorProp.new()
	door.name = label
	door.door_kind = "service"
	door.width = 0.96
	door.height = 2.10
	door.position = at
	door.swing_out = outward
	parent.add_child(door)
	return door


func _walk(routines: ResidentRoutines, actor: Dictionary, viewport: SubViewport,
		door: DoorProp, limit: int = 480) -> Dictionary:
	var result := {"frames": 0, "clear": true, "arrived": false,
		"held_frames": 0, "opened": false, "open_requests": 0}
	var was_open: bool = door.open
	while int(actor.leg) < actor.path.size() and int(result.frames) < limit:
		await get_tree().physics_frame
		var before: Vector3 = actor.node.global_position
		routines._step(actor, STEP)
		result.clear = bool(result.clear) and _body_clear(viewport, before, actor.node.global_position)
		if actor.node.global_position.is_equal_approx(before) and door._moving:
			result.held_frames = int(result.held_frames) + 1
		if door.open and not was_open: result.open_requests = int(result.open_requests) + 1
		result.opened = bool(result.opened) or door.open
		was_open = door.open
		result.frames = int(result.frames) + 1
	result.arrived = int(actor.leg) >= actor.path.size()
	return result


func _check(label: String, ok: bool) -> void:
	checks.append({"label": label, "ok": ok})
	if not ok: failures += 1
	print("[ROUTE DOORS] %s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(output)
		var file: FileAccess = FileAccess.open(output.path_join("resident_route_doors.json"), FileAccess.WRITE) if error == OK else null
		if file == null:
			_check("requested scoped evidence can be written", false)
		else:
			file.store_string(JSON.stringify({"schema": "orison.resident-route-doors-test.v1",
				"scope": "Actual non-home DoorProp owner and all nine walking-stage gates; translated/rotated service departure, return and repeated passage with zero body exclusions. Occupancy, cancellation, lifecycle and foreign-world controls. No abstract shop transfer, elevator panel, full-autonomy performance or runtime_contract admission.",
				"checks": checks, "failures": failures, "measurements": measurements}, "\t"))
			file.flush()
			var written: bool = file.get_error() == OK
			file.close()
			if not written: _check("requested scoped evidence was flushed", false)
	print("[ROUTE DOORS] RESULT %d/%d" % [checks.size() - failures, checks.size()])
	get_tree().quit(0 if failures == 0 else 1)
