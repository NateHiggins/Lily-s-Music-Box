extends Node
@export var return_home := false
@export var domestic := false
@export var mail_round := false
@export var laundry_round := false
@export var off_map := false
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var _observed_routine: Node3D
var _last_position := Vector3.INF
var _leaf_checks := 0
var _opening_holds := 0

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_observed_routine): return
	var routine := _observed_routine
	var at: Vector3 = routine.actor.global_position
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = routine._capsule
	query.collision_mask = 1
	query.transform.origin = at + Vector3.UP * (.25 + routine._capsule.height * .5)
	var hits: Array = routine.actor.get_world_3d().direct_space_state.intersect_shape(query, 32)
	_leaf_checks += 1
	for door: DoorProp in routine._doors:
		if not is_instance_valid(door): continue
		for hit: Dictionary in hits:
			if hit.collider == door._body:
				var label := "actual capsule overlaps moving/settled leaf: " + str(door.name)
				if label not in failures: failures.append(label)
		if door.open and door._moving and routine._door_passages.has(door) \
				and door.to_local(at).z * float(routine._door_passages[door].side) > 0:
			_opening_holds += 1
			if _last_position != Vector3.INF and at.distance_to(_last_position) > .001:
				var label := "resident moved while opening leaf was unsettled"
				if label not in failures: failures.append(label)
	_last_position = at

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,899 if off_map else 779 if laundry_round else 1200 if domestic else 179 if mail_round else 1423 if return_home else 1409)
	var world: OrisonV2RuntimeRoot = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if world.startup_failed:
		failures.append("startup")
	else:
		var routine: Node3D = world.mina_routine
		_observed_routine = routine
		var transitions := [[7,"unit"]] if return_home else [[1,"bodega"]]
		if domestic: transitions = [[510,"unit:bedroom"],[930,"unit:bathroom"],[975,"unit:kitchen"],[1065,"unit"]]
		if mail_round: transitions = [[1,"mail_bank"],[21,"unit"]]
		if laundry_round: transitions = [[1,"laundry"],[91,"unit:desk"]]
		if off_map:
			transitions = []
			await _off_map_round(world,clock,routine)
		for transition: Array in transitions:
			clock.advance_to(transition[0])
			await _travel(routine,str(transition[1]))
			if not failures.is_empty(): break
			if domestic: await _capture_domestic(routine, str(transition[1]))
		if domestic:
			await get_tree().create_timer(.7).timeout
			for identity in ["F02_A_HALL_DOOR", "F02_A_BATH_DOOR", "F02_A_BED_DOOR"]:
				var door := world.find_child(identity + "_Leaf", true, false) as DoorProp
				if door == null or door.open or door._moving:
					failures.append("resident did not close passed home door: " + identity)
			var sink_stance := world.adapter.resolve("F02_2A_SINK_01_STANCE") as Node3D
			if sink_stance == null or routine.graph.get_point_position(routine.identities.bathroom).distance_to(sink_stance.global_position) > .01:
				failures.append("bathroom destination departed from authored sink clearance")
			if _opening_holds == 0: failures.append("domestic route never observed a real door-opening hold")
		if routine.travelled_metres < (20 if domestic else 30): failures.append("full connected route not travelled")
		print("MINA ROUTINE: direction=", "return" if return_home else "outbound",
				" domestic=",domestic," mail=",mail_round," metres=",routine.travelled_metres," failures=",failures)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("mobility.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"return_home":return_home,"failures":failures,"samples":samples},"  "))
	print("MINA PHYSICS: leaf_checks=", _leaf_checks, " opening_holds=", _opening_holds)
	_observed_routine = null
	world.shutdown_for_tests()
	world.free()
	await get_tree().create_timer(.25).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture_domestic(routine: Node3D, destination: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	var station := "main_entry"
	if destination == "unit:bedroom": station = "bed_approach"
	elif destination == "unit:bathroom": station = "bath_approach"
	elif destination == "unit:kitchen": station = "kitchen_approach"
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = routine.graph.get_point_position(routine.identities[station]) + Vector3.UP * 1.4
	camera.look_at(routine.actor.global_position + Vector3.UP)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(destination.replace(":", "_") + ".png"))
	camera.queue_free()

func _travel(routine: Node3D, expected: String) -> void:
	var actor: AnimatedResident = routine.actor
	var previous := actor.global_position
	var elapsed := 0.0
	while elapsed < 130:
		await get_tree().create_timer(.5).timeout
		elapsed += .5
		var at := actor.global_position
		if at.distance_to(previous) > .8: failures.append("resident teleported during live route")
		previous = at
		samples.append({"seconds":elapsed,"destination":expected,"position":[at.x,at.y,at.z],
				"current":routine.current_id,"desired":routine.desired_id,"blocked":routine.blocked_seconds})
		if routine.blocked_seconds > 3:
			failures.append("resident blocked at %v; next=%s; %s"%[at,routine.path,routine.blocked_reason])
			break
		if routine.destination == expected and routine.current_id == routine.desired_id: break
	if routine.current_id != routine.desired_id: failures.append("scheduled destination not reached")
	if routine.destination != expected: failures.append("wrong authored timetable block")
	print("MINA DESTINATION: ",expected," time=",elapsed," failures=",failures)

func _off_map_round(world: OrisonV2RuntimeRoot, clock: CampaignClock, routine: Node3D) -> void:
	var street: Vector3 = routine.graph.get_point_position(routine.identities.street)
	world.player.set_physics_process(false)
	world.player.global_position = street + Vector3(1,0,2)
	var camera := world.player.camera
	camera.look_at(street+Vector3.UP)
	clock.advance_to(1)
	await _travel(routine,"out")
	await get_tree().create_timer(.7).timeout
	if routine.outside or not routine.actor.visible: failures.append("resident vanished while observed at exit")
	camera.look_at(camera.global_position+Vector3(0,0,2))
	await get_tree().create_timer(.7).timeout
	if not routine.outside or routine.actor.get_node("Interaction").collision_layer != 0:
		failures.append("unseen off-map departure retained body or interaction")
	camera.look_at(street+Vector3.UP)
	clock.advance_to(61)
	await get_tree().create_timer(.7).timeout
	if not routine.outside: failures.append("resident reappeared while observed")
	camera.look_at(camera.global_position+Vector3(0,0,2))
	await _travel(routine,"unit:desk")
	if routine.outside or not routine.actor.visible: failures.append("unseen return did not restore physical resident")
