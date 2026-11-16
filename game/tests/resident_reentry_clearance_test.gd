extends "res://tests/character_squeeze_motor_test.gd"
## Nearby ordinary-owner reentry, not full-world schedule or arrival proof.
const BarGuide = preload("res://scripts/characters/orison_v2_bar_route.gd")
var logger
var observations: Array[Dictionary] = []

func make_route(id: String, start: Vector3, goal: Vector3) -> Node3D:
	var route = Route.new(); route.world = self; route.resident = id
	add_child(route); route.set_physics_process(false)
	route._sample = 10000; route._capsule.radius = .28; route._capsule.height = 1.4
	route._point("start",start); route._point("goal",goal); route.graph.connect_points(0,1)
	route.current_id = 0; route.desired_id = 1; route.destination = "unit"; route.route_speed = 1.05
	route._bar_route = BarGuide.new(); route._bar_route.route = route
	route.actor = Presentation.new()
	route.actor.setup(id,id,"","res://assets/characters/%s/%s.gltf" % [id,id])
	route.actor.externally_driven = true; route.add_child(route.actor)
	route.actor.global_position = start
	check(route.actor._model != null,"real presentation loaded " + id)
	return route

func simultaneous_returns(reverse: bool) -> void:
	player.camera.look_at(Vector3(6,1,3))
	var first_id := "sacha_reed" if reverse else "rhea_sato"
	var second_id := "rhea_sato" if reverse else "sacha_reed"
	var first = make_route(first_id,Vector3(0,0,-2),Vector3(-2,0,-2))
	var second = make_route(second_id,Vector3(0,0,-2),Vector3(2,0,-2))
	first._set_outside(true); second._set_outside(true)
	check(not first._observed() and not second._observed(),"simultaneous station unseen, reverse=" + str(reverse))
	first.set_physics_process(true); second.set_physics_process(true)
	var prior := [true,true]
	var appearances := 0
	var unsafe_overlap := false
	for tick: int in Engine.physics_ticks_per_second * 6:
		await get_tree().physics_frame
		for index: int in 2:
			var route: Node3D = [first,second][index]
			if prior[index] and not route.outside:
				appearances += 1
				observations.append({"kind":"simultaneous_appearance","reverse":reverse,"resident":route.resident,"frame":Engine.get_physics_frames(),"feet":route.actor.global_position,"first_outside":first.outside,"second_outside":second.outside,"first_contacts":first.squeeze._contacts.duplicate(true),"second_contacts":second.squeeze._contacts.duplicate(true)})
			prior[index] = route.outside
		if not first.outside and not second.outside:
			var flat := Vector2(first.actor.global_position.x-second.actor.global_position.x,first.actor.global_position.z-second.actor.global_position.z)
			unsafe_overlap = unsafe_overlap or flat.length() < .56
		if first.current_id == 1 and second.current_id == 1: break
	check(appearances == 2,"both simultaneous returns publish without rescue, reverse=" + str(reverse))
	check(not unsafe_overlap,"simultaneous returns never publish overlapping capsules, reverse=" + str(reverse))
	check(first.current_id == 1 and second.current_id == 1,"both simultaneous returns complete ordinary routes, reverse=" + str(reverse))
	first.set_physics_process(false); second.set_physics_process(false)
	first.free(); second.free()

func run() -> void:
	logger = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	if not RealityState.begin_preview_campaign(self): get_tree().quit(2); return
	adapter = OrisonV2AnchorAdapter.new(self)
	block(Vector3(0,-.1,0),Vector3(10,.2,10))
	player = PlayerController.new(); add_child(player)
	player.global_position = Vector3(3,0,3); player.set_physics_process(false)
	player.camera.look_at(Vector3(6,1,3))
	var returning = make_route("rhea_sato",Vector3.ZERO,Vector3(0,0,2))
	var peer = make_route("sacha_reed",Vector3(.1,0,0),Vector3(2,0,0))
	returning._set_outside(true)
	await get_tree().physics_frame; await get_tree().physics_frame
	check(not returning._observed(),"real camera does not observe declared reentry station")
	var origin: Vector3 = returning.actor.global_position
	returning.set_physics_process(true)
	for tick: int in 4: await get_tree().physics_frame
	observations.append({"kind":"occupied_endpoint","frame":Engine.get_physics_frames(),"outside":returning.outside,"visible":returning.actor.visible,"feet":returning.actor.global_position,"peer":peer.actor.global_position,"contacts":returning.squeeze._contacts.duplicate(true)})
	check(returning.outside and not returning.actor.visible,"occupied endpoint keeps returning body outside and hidden")
	check(returning.actor.global_position == origin,"occupied reentry never relocates or advances hidden body")
	check(returning.actor.get_node("Interaction").collision_layer == 0,"occupied reentry retains noninteracting outside state")
	check(returning.squeeze._contacts.is_empty(),"reentry does not manufacture courtesy permission")
	var queued_station := Vector3(-3,0,0)
	check(returning._initial_peer_clear(queued_station),"queued-peer control station initially clear")
	var queued_peer := Node3D.new(); add_child(queued_peer)
	queued_peer.global_position = queued_station; queued_peer.add_to_group("animated_residents")
	queued_peer.queue_free()
	check(not returning._initial_peer_clear(queued_station),"queued visible peer blocks publication until actual removal")
	await get_tree().process_frame; await get_tree().process_frame
	check(not is_instance_valid(queued_peer) and returning._initial_peer_clear(queued_station),"removed peer no longer blocks publication")
	if failures.is_empty():
		peer.set_physics_process(true)
		var first_visible := false
		for tick: int in Engine.physics_ticks_per_second * 6:
			await get_tree().physics_frame
			if not returning.outside and not first_visible:
				first_visible = true
				var gap := Vector2(returning.actor.global_position.x-peer.actor.global_position.x,returning.actor.global_position.z-peer.actor.global_position.z).length()
				observations.append({"frame":Engine.get_physics_frames(),"gap":gap,"returning":returning.actor.global_position,"peer":peer.actor.global_position})
				check(gap >= .60,"ordinary peer movement clears absolute reentry separation before appearance")
			if returning.current_id == 1 and peer.current_id == 1: break
		check(first_visible,"unseen returning body appears after actual peer walks clear")
		check(returning.current_id == 1 and returning.path.is_empty(),"ordinary returning motor completes authored route")
		check(peer.current_id == 1 and peer.path.is_empty(),"ordinary peer motor completes authored route")
		check(returning.actor.get_node("Interaction").collision_layer == 1,"clear reentry restores normal interaction layer")
		check(is_equal_approx(returning._capsule.radius,.28) and is_equal_approx(returning.route_speed,1.05),"original capsule and speed retained")
		returning.set_physics_process(false); peer.set_physics_process(false)
		returning._set_outside(true); returning.desired_id = 0
		player.camera.look_at(returning.actor.global_position+Vector3.UP)
		check(returning._observed(),"real camera observes clear return station")
		returning.set_physics_process(true)
		for tick: int in 4: await get_tree().physics_frame
		check(returning.outside and not returning.actor.visible,"observation still prevents clear reappearance")
	returning.set_physics_process(false); peer.set_physics_process(false)
	if failures.is_empty():
		await simultaneous_returns(false)
		await simultaneous_returns(true)
	RealityState.end_preview_campaign(self)
	await get_tree().process_frame
	var errors: Array = logger.errors.duplicate()
	check(errors.is_empty(),"no unexpected engine errors")
	OS.remove_logger(logger)
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"engine_errors":errors,"observations":observations,"scope":"Real route motor, presentation, camera and peer enumeration on declared nearby floor/graph. Not actual Monday schedule, native entrance, save or natural arrival proof."},"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
