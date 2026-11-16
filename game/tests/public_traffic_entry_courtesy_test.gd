extends "res://tests/character_squeeze_motor_test.gd"
## Nearby diagnostic: actual facade/open native leaf and ordinary motors/RVO.
## Explicit test region, floor and graph; not registered world/agenda proof.
const Traffic = preload("res://scripts/characters/public_foot_traffic.gd")
const NativeEntry = preload("res://scripts/props/orison_v2_entry_door.gd")
var replay: Array[Dictionary] = []
var log_capture

func run() -> void:
	log_capture = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(log_capture)
	if not RealityState.begin_preview_campaign(self): get_tree().quit(2); return
	adapter = OrisonV2AnchorAdapter.new(self)
	block(Vector3(0,-.1,0), Vector3(8,.2,8))
	player = PlayerController.new(); add_child(player)
	player.global_position = Vector3(3,0,3); player.set_physics_process(false)
	var facade = (load("res://assets/props/front_facade.glb") as PackedScene).instantiate() as Node3D
	var leaf = facade.get_node("EntryLeaf") as Node3D
	leaf.owner = null
	for child: Node in leaf.find_children("*", "", true, false): child.owner = null
	facade.remove_child(leaf)
	facade.rotation.y = PI; add_child(facade)
	for draw: MeshInstance3D in facade.find_children("*", "MeshInstance3D", true, false):
		draw.create_trimesh_collision()
	var door = NativeEntry.new()
	door.name = "F01_DOOR_06_Leaf"; door.native_leaf = leaf
	door.width = 1.10; door.height = 2.13; door.leaf_state = "open"
	door.door_kind = "landmark_entry"
	door.swing_out = false
	add_child(door)
	door.global_position = Vector3(-0.55,0,-0.035)
	door.restore_mechanism({"angle": door.motion_target_angle(true)})
	await get_tree().physics_frame; await get_tree().physics_frame
	check(door.is_ready_for_passage(), "native fitted leaf starts at its declared open pose")
	public_traffic = Traffic.new(); add_child(public_traffic)
	# Declared nearby owner scope; no fake resolver or registered-frame claim.
	public_traffic._world = weakref(self)
	public_traffic._bounds = Rect2(-4,-4,8,8)
	public_traffic._floor_y = 0.0; public_traffic._configured = true
	var routes: Array[Node3D] = []
	for index: int in 2:
		var id: String = ["rhea_sato", "sacha_reed"][index]
		var route = Route.new(); route.world = self; route.resident = id
		add_child(route); route.set_physics_process(false)
		route._sample = 10000; route._capsule.radius = .28; route._capsule.height = 1.4
		var route_start = Vector3(-0.260728,0,-0.8) if index == 0 else Vector3(0.268419,0,0.8)
		var route_goal = Vector3(0,0,1.25) if index == 0 else Vector3(0,0,-1.25)
		route._point("start", route_start); route._point("threshold", Vector3(0,0,-0.035)); route._point("goal", route_goal)
		route.graph.connect_points(0,1); route.graph.connect_points(1,2)
		route.current_id = 0; route.desired_id = 2; route.route_speed = 1.05
		route.actor = Presentation.new()
		route.actor.setup(id,id,"","res://assets/characters/%s/%s.gltf" % [id,id])
		route.actor.externally_driven = true; route.add_child(route.actor)
		route.actor.global_position = route_start; route._doors.append(door)
		check(route.actor._model != null, "real resident presentation " + id)
		routes.append(route)
	await get_tree().physics_frame
	for route: Node3D in routes: route.set_physics_process(true)
	for tick: int in Engine.physics_ticks_per_second * 16:
		await get_tree().physics_frame
		if tick % 15 == 0:
			var row: Dictionary = {"frame": Engine.get_physics_frames(), "traffic": public_traffic.stats.duplicate(), "actors": []}
			for route: Node3D in routes:
				row.actors.append({"resident": route.resident, "feet": route.actor.global_position, "current": route.current_id,
					"blocked": route.blocked_reason, "blocked_seconds": route.blocked_seconds, "door_passages": route._door_passages.size(),
					"can_steer": public_traffic._can_steer(route), "courtesy": route.squeeze.active(), "cues": route.squeeze.cue_count})
			replay.append(row)
		if routes.all(func(r: Node3D) -> bool: return r.current_id == 2 and r.path.is_empty()): break
	for route: Node3D in routes:
		route.set_physics_process(false)
		check(route.current_id == 2 and route.path.is_empty(), "ordinary opposed motor clears native entry " + str(route.resident))
		check(is_equal_approx(route._capsule.radius,.28) and is_equal_approx(route.route_speed,1.05), "capsule and ordinary speed preserved " + str(route.resident))
	check(routes[0].squeeze.cue_count + routes[1].squeeze.cue_count > 0, "timed passage issues an ordinary courtesy cue")
	var crossing_held := false
	for row: Dictionary in replay:
		for actor: Dictionary in row.actors:
			if int(actor.door_passages) > 0:
				crossing_held = true
				check(not bool(actor.can_steer), "door custody excludes lateral public steering")
	check(crossing_held, "actual door-passage ownership observed during crossing")
	if failures.is_empty():
		for route: Node3D in routes:
			var goal: Vector3 = route.graph.get_point_position(2) + Vector3(.25,0,.35 if route == routes[0] else -.35)
			route._point("public_continue", goal); route.graph.connect_points(2,3); route.desired_id = 3
			route.set_physics_process(true)
		for tick: int in 3: await get_tree().physics_frame
		for route: Node3D in routes:
			check(route._door_passages.is_empty() and public_traffic._can_steer(route), "released crossing resumes ordinary public steering " + str(route.resident))
		for tick: int in Engine.physics_ticks_per_second * 2:
			await get_tree().physics_frame
			if routes.all(func(r: Node3D) -> bool: return r.current_id == 3 and r.path.is_empty()): break
		for route: Node3D in routes:
			route.set_physics_process(false)
			check(route.current_id == 3 and route.path.is_empty(), "resumed public motor reaches continuation " + str(route.resident))
		var native_before: int = int(public_traffic.stats.native_veto)
		var probe: Node3D = routes[0]
		probe._point("solid_frame", Vector3(1.1,0,0)); probe.graph.connect_points(3,4); probe.desired_id = 4
		probe.set_physics_process(true)
		for tick: int in Engine.physics_ticks_per_second * 4: await get_tree().physics_frame
		probe.set_physics_process(false)
		check(probe.current_id != 4 and int(public_traffic.stats.native_veto) > native_before, "actual native frame still refuses an obstructed target")
	public_traffic.shutdown()
	RealityState.end_preview_campaign(self)
	await get_tree().process_frame
	var engine_errors: Array = log_capture.errors.duplicate()
	check(engine_errors.is_empty(), "no unexpected engine errors in native entry diagnostic")
	OS.remove_logger(log_capture)
	var output = OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT",
			"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures, "engine_errors":engine_errors, "trace":replay,
			"scope":"Actual native facade/open leaf, ordinary route motors and RVO in declared diagnostic floor/region/graph. Not complete registered entry, opening/key/save, natural agenda, full crowd or artistic acceptance."},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
