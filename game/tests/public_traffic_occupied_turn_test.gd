extends "res://tests/character_squeeze_motor_test.gd"
## Production motor and public traffic on a diagnostic floor and graph.
const Traffic := preload("res://scripts/characters/public_foot_traffic.gd")

func run() -> void:
	if not RealityState.begin_preview_campaign(self): get_tree().quit(2); return
	adapter = OrisonV2AnchorAdapter.new(self)
	block(Vector3(0, -.1, 4), Vector3(10, .2, 10))
	player = PlayerController.new()
	add_child(player)
	player.position = Vector3(.00016, 0, 3.92544)
	player.set_physics_process(false)
	public_traffic = Traffic.new()
	add_child(public_traffic)
	public_traffic._world = weakref(self)
	public_traffic._bounds = Rect2(-4, 0, 8, 8)
	public_traffic._configured = true
	await _walk_turn(false)
	await _walk_turn(true)
	public_traffic.shutdown()
	RealityState.end_preview_campaign(self)
	get_tree().quit(0 if failures.is_empty() else 1)

func _walk_turn(retarget: bool) -> void:
	var route := Route.new()
	route.world = self
	route.resident = "sacha_reed"
	add_child(route)
	route._sample = 10000
	route._capsule.radius = .28
	route._capsule.height = 1.4
	var start := Vector3(.95 if retarget else .72, 0, 4.08)
	var turn := Vector3(0, .04, 4)
	# Continue to the opposite side of the turn on the diagnostic floor.
	var exit := Vector3.LEFT * 1.4 + Vector3.BACK * (turn.z + .25)
	route._point("pavement_approach", start)
	route._point("pavement_turn", turn)
	route._point("pavement_exit", exit)
	route._point("alternate_exit", exit + Vector3.BACK * .8)
	route.graph.connect_points(0, 1)
	route.graph.connect_points(1, 2)
	route.graph.connect_points(1, 3)
	route.current_id = 0
	route.desired_id = 2
	route.actor = Presentation.new()
	route.actor.setup("Sacha Reed", "sacha_reed", "", "res://assets/characters/sacha_reed/sacha_reed.gltf")
	route.actor.externally_driven = true
	route.add_child(route.actor)
	route.actor.position = start
	check(route.actor._model != null, "resident uses production presentation")
	if retarget:
		for tick in Engine.physics_ticks_per_second:
			await get_tree().physics_frame
			if route.actor.position.distance_to(start) > .07: break
		check(route.current_id == 0 and route.path.size() == 2 and route.path[0] == 1,
				"original motor is travelling toward the occupied turn before retargeting")
		route.desired_id = 3
	var retained_turn := false
	var peak_wait := 0.0
	var reached_with_courtesy := false
	for tick in Engine.physics_ticks_per_second * 9:
		await get_tree().physics_frame
		peak_wait = maxf(peak_wait, route.blocked_seconds)
		retained_turn = retained_turn or (route.current_id == 0 and route.path == PackedInt64Array([1]))
		if route.current_id == 1 and peak_wait >= .7 and route.squeeze.cue_count > 0:
			reached_with_courtesy = true
		if route.current_id == route.desired_id and route.path.is_empty(): break
	if retarget:
		check(retained_turn, "retarget preserves the occupied waypoint as the single queued vertex")
	check(public_traffic.stats.proposals > 0, "public solver operates")
	check(route.current_id == route.desired_id and route.path.is_empty(), "resident crosses occupied intermediate turn and continues")
	check(reached_with_courtesy, "pause and cue precede passage")
	print("OCCUPIED TURN FINAL ", route.actor.position, " wait=", peak_wait, " cues=", route.squeeze.cue_count, " traffic=", public_traffic.stats)
	route.set_physics_process(false)
	route.free()
