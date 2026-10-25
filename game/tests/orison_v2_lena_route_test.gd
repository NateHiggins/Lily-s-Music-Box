extends Node
## Lena's walking body in the production V2 root
## (design/ORISON_RESIDENT_BODIES_2026-10-25.md): she is composed from her
## route file, her agenda is held to the places her route reaches, and she
## walks a tour of them (her kitchen, bedroom and bath, the east hall, the
## lobby, the mail bank, out to the street and home) without a teleport, a
## block or her capsule ever overlapping a door leaf, closing every door she
## opened behind her. Windowed: the runtime refuses headless.

const TOUR := ["unit:kitchen", "unit:bedroom", "unit:bathroom", "unit", "corridor", "lobby",
		"mail_bank", "unit", "out", "unit"]
var failures: Array[String] = []
var _route: Node3D
var _metres := 0.0


func _check(label: String, ok: bool) -> void:
	print("LENA ROUTE: ", label, " = ", ok)
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
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 600)
	var world: OrisonV2RuntimeRoot = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if world.startup_failed:
		failures.append("startup")
	else:
		await _run(world)
	print("LENA ROUTE: %.1f metres walked; %d failures %s" % [_metres, failures.size(), failures])
	get_tree().quit(0 if failures.is_empty() else 1)


func _run(world: OrisonV2RuntimeRoot) -> void:
	_route = world.resident_routes.get("lena_ortiz")
	# The player arrives by the front door; keep the arrival body out of the
	# sweep of the doors she must open.
	world.player.visible = false
	_check("Lena's body is composed from her route file", _route != null and _route.actor != null
			and _route.actor.resident_id == "lena_ortiz" and _route.actor._model != null)
	if _route == null:
		return
	_check("her agenda is held to the places her route reaches",
			world.resident_agenda._allowed.get("lena_ortiz", []).has("unit:kitchen")
			and not world.resident_agenda._allowed.get("lena_ortiz", []).has("roof"))
	_check("her own four doors are hers", _route._doors.filter(func(d): return d.unit == "2B").size() == 4)
	var whereabouts: Dictionary = world.resident_whereabouts("lena_ortiz")
	_check("she starts where her agenda puts her: %s" % whereabouts.get("place", "?"),
			_route.destination == str(whereabouts.get("place", "")))
	for place: String in TOUR:
		_route.force_destination = place
		await _walk(place)
	_route.force_destination = ""
	for door: DoorProp in _route._doors:
		if is_instance_valid(door) and door.unit == "2B":
			_check("%s left closed behind her" % door.name, not door.open)


## Look at her from two metres off, on her floor, from whichever side is open.
func _shot(identity: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty():
		return
	var player: Node3D = _route.world.player
	var her: Vector3 = _route.actor.global_position
	for side: Vector3 in [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2), Vector3(1.4, 0, 1.4), Vector3(-1.4, 0, -1.4)]:
		var ray := PhysicsRayQueryParameters3D.create(her + Vector3.UP * 1.4, her + side + Vector3.UP * 1.4, 1)
		if _route.actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			player.global_position = her + side
			break
	for _frame in 4:
		await get_tree().physics_frame
	_route.world.player.camera.look_at(her + Vector3.UP * 1.1)
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))


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
	if place in ["unit:kitchen", "lobby", "corridor"]:
		await _shot("lena_" + place.replace(":", "_"))
	if place == "out":
		_check("leaves unseen once out", not actor.visible or _route._observed())
