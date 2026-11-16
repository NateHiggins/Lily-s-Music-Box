extends "res://tests/orison_v2_resident_walk_test.gd"
## Read-only loaded collision survey before changing the authored sink route.
## No actor relocation, graph edits, collision exclusions or attendance proof.
var samples: Array = []

func _run(world: OrisonV2RuntimeRoot) -> void:
	var deadline := Time.get_ticks_msec() + 180000
	while world.startup_ms <= 0.0 and not world.startup_failed and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	_route = world.mina_routine
	_check("installed Mina owner is ready", world.startup_ms > 0.0 and not world.startup_failed
		and is_instance_valid(_route) and is_instance_valid(_route.actor))
	if not failures.is_empty(): return
	var door: OrisonV2FittedDoor
	for candidate: DoorProp in _route._doors:
		if str(candidate.get_meta("semantic_id", "")) == "F02_A_BATH_DOOR": door = candidate as OrisonV2FittedDoor
	_check("actual fitted bathroom leaf resolves", is_instance_valid(door) and door is OrisonV2FittedDoor)
	if not failures.is_empty(): return
	var sink := world.adapter.resolve("F02_2A_SINK_01")
	_check("actual fitted lavatory profile is installed", sink != null
		and str(sink.get("lavatory_profile")) == "WallService_2955")
	var source_before := FileAccess.get_sha256(_route.source_path)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_route.source_path))
	var old: Vector3
	var entry: Vector3
	for chain: Array in source.paths:
		for point: Array in chain:
			if point[0] == "bathroom": old = Vector3(point[1], point[2], point[3])
			if point[0] == "bath_in": entry = Vector3(point[1], point[2], point[3])
	var proposed := Vector3(-7.70, 3.2, 4.30)
	_check("original negative remains the authored sink point", old.is_equal_approx(Vector3(-7.85, 3.2, 4.30)))
	_check("production capsule profile retained", is_equal_approx(_route._capsule.radius, .28)
		and is_equal_approx(_route._capsule.height, 1.40))
	door.npc_set_open(true, "mina_vale")
	for frame in 180:
		await get_tree().physics_frame
		if door.is_ready_for_passage(): break
	for frame in 2: await get_tree().physics_frame
	_check("real fitted leaf settles at its unchanged open stop", door.open and door.is_ready_for_passage()
		and is_equal_approx(door.open_stop_degrees, 90.0)
		and absf(door._body.rotation.y - door.motion_target_angle(true)) < .001)
	var old_hits := _contacts(world, old)
	_check("old sink point reproduces actual leaf exclusion", old_hits.any(func(hit: Dictionary) -> bool: return hit.collider == door._body))
	var clear := true
	for i in 31:
		var at := entry.lerp(proposed, float(i) / 30.0)
		var hits := _contacts(world, at)
		var names: Array = []
		for hit: Dictionary in hits: names.append(str(hit.collider.get_path()))
		samples.append({"foot": [at.x, at.y, at.z], "contacts": names})
		clear = clear and hits.is_empty()
	_check("candidate and entire final leg clear every loaded physical collider", clear)
	_check("probe leaves authored route bytes unchanged", FileAccess.get_sha256(_route.source_path) == source_before)
	var output := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var result := {"evidence_class": "INERT", "scope": "Loaded production physics survey only; no actor walk or installed candidate route acceptance.",
		"route_sha256": source_before, "leaf_angle": door._body.rotation.y, "leaf_target": door.motion_target_angle(true),
		"old_point_contacts": old_hits.map(func(hit: Dictionary) -> String: return str(hit.collider.get_path())),
		"candidate_samples": samples, "failures": failures}
	FileAccess.open(output.path_join("clearance.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame

func _contacts(world: OrisonV2RuntimeRoot, foot: Vector3) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _route._capsule
	query.collision_mask = 1
	query.transform.origin = world.adapter.root.to_global(foot) + Vector3.UP * (.25 + _route._capsule.height * .5)
	query.exclude = [world.player.get_rid()] # Same exclusion as the production motor.
	return _route.actor.get_world_3d().direct_space_state.intersect_shape(query, 32)
