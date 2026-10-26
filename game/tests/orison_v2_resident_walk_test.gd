extends Node
## Any resident's walking body in the production V2 root
## (design/ORISON_RESIDENT_BODIES_2026-10-25.md). RESIDENT names them; their
## route file (res://data/orison_v2/<resident>_routine.json) is composed the
## way the runtime composes a registered one, and they walk a tour of every
## place it names, home between each, without a teleport, a block or their
## capsule ever overlapping a door leaf, closing every door of their own unit
## behind them. Windowed: the runtime refuses headless.

const ResidentRoute := preload("res://scripts/characters/orison_v2_resident_route.gd")
var failures: Array[String] = []
var _route: Node3D
var _metres := 0.0
var _resident := ""


func _check(label: String, ok: bool) -> void:
	print("RESIDENT WALK: ", label, " = ", ok)
	if not ok:
		failures.append(label)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_route) or _route.actor == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _route._capsule
	query.collision_mask = 1
	query.transform.origin = _route.actor.global_position + Vector3.UP * (.25 + _route._capsule.height * .5)
	for hit: Dictionary in _route.actor.get_world_3d().direct_space_state.intersect_shape(query, 16):
		for door: DoorProp in _route._doors:
			if is_instance_valid(door) and hit.collider == door._body:
				var label := "capsule overlaps a leaf: " + str(door.name)
				if label not in failures:
					failures.append(label)


func _ready() -> void:
	_resident = OS.get_environment("RESIDENT")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 600)
	var world: OrisonV2RuntimeRoot = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if _resident == "":
		failures.append("RESIDENT not set")
	elif world.startup_failed:
		failures.append("startup")
	else:
		await _run(world)
	print("RESIDENT WALK %s: %.1f metres walked; %d failures %s" % [_resident, _metres, failures.size(), failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func _run(world: OrisonV2RuntimeRoot) -> void:
	_route = world.resident_routes.get(_resident)
	if _route == null:
		var route := ResidentRoute.new()
		route.name = _resident.to_pascal_case() + "Routine"
		route.resident = _resident
		route.source_path = "res://data/orison_v2/%s_routine.json" % _resident
		world.add_child(route)
		if route.setup(world):
			_route = route
	world.player.visible = false
	_check("%s's body is composed from their route file" % _resident, _route != null and _route.actor != null
			and _route.actor.resident_id == _resident and _route.actor._model != null)
	if _route == null:
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_route.source_path))
	var unit := str(source.unit)
	for place: String in source.places:
		if place == "unit":
			continue
		_route.force_destination = place
		await _walk(place)
		_route.force_destination = "unit"
		await _walk("unit")
	for door: DoorProp in _route._doors:
		if is_instance_valid(door) and door.unit == unit:
			_check("%s left closed behind them" % door.name, not door.open)
	await _capture_body(world)
	_route.force_destination = ""


func _capture_body(world: OrisonV2RuntimeRoot) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or not _route.actor.visible: return
	var target: Vector3 = _route.actor.global_position + Vector3.UP * .95
	var eye := Vector3.ZERO
	var clear := false
	for side: Vector3 in [Vector3(2, .3, 0), Vector3(-2, .3, 0), Vector3(0, .3, 2), Vector3(0, .3, -2)]:
		var ray := PhysicsRayQueryParameters3D.create(target, target + side, 1)
		if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			eye = target + side; clear = true; break
	_check("render review has an unobstructed camera stance", clear)
	if not clear: return
	var review := Camera3D.new()
	world.add_child(review)
	review.fov = 55.
	review.look_at_from_position(eye, target)
	review.make_current()
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var image := get_viewport().get_texture().get_image()
	_check("resident render capture writes successfully", image.save_png(output.path_join(_resident + ".png")) == OK)
	world.player.camera.make_current()
	review.queue_free()


func _walk(place: String) -> void:
	var actor: AnimatedResident = _route.actor
	var previous := actor.global_position
	var elapsed := 0.0
	while elapsed < 150.0:
		await get_tree().create_timer(.5).timeout
		elapsed += .5
		var at := actor.global_position
		if at.distance_to(previous) > .8 and actor.visible:
			failures.append("teleported on the way to " + place)
		_metres += at.distance_to(previous) if actor.visible else 0.0
		previous = at
		if _route.blocked_seconds > 3.0:
			failures.append("blocked on the way to %s at %v: %s" % [place, at, _route.blocked_reason])
			return
		if _route.current_id == _route.desired_id and _route.path.is_empty():
			break
	_check("reaches %s (%.0f s)" % [place, elapsed], _route.current_id == _route.desired_id and _route.desired_id >= 0)
