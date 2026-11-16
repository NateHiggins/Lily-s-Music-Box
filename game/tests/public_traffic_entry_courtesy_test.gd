extends "res://tests/character_squeeze_motor_test.gd"
## Nearby diagnostic: actual facade/open native leaf and ordinary motors/RVO.
## Explicit test region, floor and graph; not registered world/agenda proof.
const Traffic = preload("res://scripts/characters/public_foot_traffic.gd")
const NativeEntry = preload("res://scripts/props/orison_v2_entry_door.gd")
var replay: Array[Dictionary] = []

func run() -> void:
	if not RealityState.begin_preview_campaign(self): get_tree().quit(2); return
	adapter = OrisonV2AnchorAdapter.new(self)
	block(Vector3(0,-.1,0), Vector3(8,.2,8))
	player = PlayerController.new(); add_child(player)
	player.position = Vector3(3,0,3); player.set_physics_process(false)
	var facade = (load("res://assets/props/front_facade.glb") as PackedScene).instantiate() as Node3D
	var leaf = facade.get_node("EntryLeaf") as Node3D
	facade.remove_child(leaf)
	facade.rotation.y = PI; add_child(facade)
	for draw: MeshInstance3D in facade.find_children("*", "MeshInstance3D", true, false):
		draw.create_trimesh_collision()
	var door = NativeEntry.new()
	door.name = "F01_DOOR_06_Leaf"; door.native_leaf = leaf
	door.width = 1.10; door.height = 2.13; door.leaf_state = "open"
	door.swing_out = false; door.position = Vector3(-.55,0,-.035)
	add_child(door)
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
		var start = Vector3(-.260728,0,-.15) if index == 0 else Vector3(.268419,0,.144514)
		var goal = Vector3(0,0,1.25 if index == 0 else -1.25)
		route._point("start", start); route._point("goal", goal); route.graph.connect_points(0,1)
		route.current_id = 0; route.desired_id = 1; route.route_speed = 1.05
		route.actor = Presentation.new()
		route.actor.setup(id,id,"","res://assets/characters/%s/%s.gltf" % [id,id])
		route.actor.externally_driven = true; route.add_child(route.actor)
		route.actor.global_position = start; route._doors.append(door)
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
		if routes.all(func(r: Node3D) -> bool: return r.current_id == 1 and r.path.is_empty()): break
	for route: Node3D in routes:
		route.set_physics_process(false)
		check(route.current_id == 1 and route.path.is_empty(), "ordinary opposed motor clears native entry " + str(route.resident))
		check(is_equal_approx(route._capsule.radius,.28) and is_equal_approx(route.route_speed,1.05), "capsule and ordinary speed preserved " + str(route.resident))
	check(routes[0].squeeze.cue_count + routes[1].squeeze.cue_count > 0, "timed passage issues an ordinary courtesy cue")
	var output = OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT",
			"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures, "trace":replay,
			"scope":"Actual native facade/open leaf, ordinary route motors and RVO in declared diagnostic floor/region/graph. Not complete registered entry, opening/key/save, natural agenda, full crowd or artistic acceptance."},"\t"))
	public_traffic.shutdown()
	RealityState.end_preview_campaign(self)
	get_tree().quit(0 if failures.is_empty() else 1)
