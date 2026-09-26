extends "res://tests/orison_v2_roof_route_test.gd"
## The guarded drive must leave both roof approaches walkable and follow the
## real production car. Only the lift request is issued directly by this test.
func _init() -> void:
	route_label = "LIFT DRIVE"

func _route() -> void:
	failures.append("lift suspension checks interrupted before completion")
	for point in [Vector3(2.3,17.6,1.3),Vector3(3.8,17.6,1.3),Vector3(3.8,19.2,-3.4),Vector3(1.5,19.2,-3.4),Vector3(1.5,19.2,0),Vector3(0,19.2,.15)]:
		if not await _walk(point): return
	var drive := world.adapter.resolve("ROOF_LIFT_DRIVE") as Node3D
	if not _require(drive != null and drive.get("lift") == world.elevator,"drive observes the production lift"): return
	var wheel := drive.get("sheave") as Node3D
	var bounds := AABB()
	var first := true
	for node: Node in wheel.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for index in 8:
			var corner := drive.to_local(mesh.to_global(mesh.get_aabb().get_endpoint(index)))
			if first:
				bounds = AABB(corner,Vector3.ZERO)
				first = false
			else: bounds = bounds.expand(corner)
	if not _require(not first and bounds.size.x < .3 and bounds.size.y > .6 and bounds.size.z > .6,
			"imported sheave stands vertically on its driven X axle: "+str(bounds.size)): return
	await _roof_capture("guarded_lift_drive",Vector3(-.35,20.15,-1.7))
	var toward: Vector3 = world.adapter.root.global_basis * Vector3.FORWARD
	player.rotation.y = atan2(-toward.x,-toward.z)
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await get_tree().create_timer(.7).timeout
	Input.action_release("move_forward")
	var at: Vector3 = world.adapter.root.to_local(player.global_position)
	if not _require(absf(at.z-(-.37+PlayerController.BODY_RADIUS)) < .025 and absf(at.y-19.2)<.08,"actual capsule stops at the extended machinery guard: "+str(at)): return
	if not await _walk(Vector3(0,19.2,.15)): return
	var lift := world.elevator as OrisonElevator
	var initial: float = drive.get("driven_angle")
	var rope_total: float = drive.get("total_vertical_rope")
	if not _require(lift.current == "F01" and not lift.moving,"guarded machine has not changed idle lift state"): return
	lift.travel_to("F02")
	var deadline := Time.get_ticks_msec()+20000
	while lift.moving and Time.get_ticks_msec()<deadline:
		await get_tree().physics_frame
	await get_tree().process_frame
	var height: float = drive.get("observed_car_height")
	var angle: float = drive.get("driven_angle")
	if not _require(not lift.moving and lift.current == "F02" and is_equal_approx(height,lift._cabin.position.y)
			and absf(angle-initial)>9.0 and is_equal_approx(angle,height/.315),"rear rope tangent raises the car with the sheave"): return
	await get_tree().create_timer(.5).timeout
	if not _require(is_equal_approx(angle,float(drive.get("driven_angle"))),"stopped car stops the sheave"): return
	var counter := drive.get("counterweight") as AnimatableBody3D
	var weight_bounds := _mesh_bounds(counter)
	var crosshead := drive.get("crosshead") as Node3D
	var crosshead_bounds := _mesh_bounds(crosshead)
	if not _require(weight_bounds.size.is_equal_approx(Vector3(.4,1.58,.1)),"imported counterweight matches the rear-shaft envelope: "+str(weight_bounds.size)): return
	var weight_shape := BoxShape3D.new()
	weight_shape.size = weight_bounds.size
	var crosshead_shape := BoxShape3D.new()
	crosshead_shape.size = crosshead_bounds.size
	var sample_count := 0
	for destination: String in ["F06","B1","F01"]:
		lift.travel_to(destination)
		deadline = Time.get_ticks_msec()+30000
		while lift.moving and Time.get_ticks_msec()<deadline:
			await get_tree().physics_frame
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = weight_shape
			query.transform = counter.global_transform * Transform3D(Basis.IDENTITY,weight_bounds.get_center())
			query.exclude = [counter.get_rid()]
			query.collision_mask = 1
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query)
			if not hits.is_empty():
				_require(false,"counterweight clearance at "+str(lift._cabin.position.y)+": "+str(hits))
				return
			query.shape = crosshead_shape
			query.transform = crosshead.global_transform * Transform3D(Basis.IDENTITY,crosshead_bounds.get_center())
			# The mounting shoes intentionally rest on the production car roof.
			query.exclude = [counter.get_rid(),lift._cabin.get_rid()]
			if not world.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
				_require(false,"car crosshead hits shaft construction at "+str(lift._cabin.position.y))
				return
			if absf(float(drive.get("total_vertical_rope"))-rope_total)>.001:
				_require(false,"suspension length changes during production travel")
				return
			sample_count += 1
		if not _require(not lift.moving and lift.current == destination,"suspension reaches "+destination): return
		if not _require(is_equal_approx(float(drive.get("counter_height")),13.7-lift._cabin.position.y),"counterweight follows the car in opposite travel"): return
		if destination == "B1": await _shaft_inspection()
	if not _require(sample_count > 100,"continuous real-physics clearance samples: "+str(sample_count)): return
	for z: float in [-2.141,-.474]:
		var ray := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(Vector3(-.75,19.35,z)),world.adapter.root.to_global(Vector3(-.75,19.0,z)),1)
		ray.exclude = [(drive.get_node("PlantGuard") as StaticBody3D).get_rid()]
		if not _require(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"rope passes through a real roof opening at "+str(z)): return
	await _roof_capture("lift_drive_after_travel",Vector3(-.35,20.15,-1.7))
	if not await _walk(Vector3(-1.35,19.2,0)): return
	if not await _open_door("ROOF_PUBLIC_DOOR"): return
	if not await _walk(Vector3(-3.6,19.2,0)): return
	await _roof_capture("roof_machine_bulkhead",Vector3(-.1,20.4,-1.7))
	if not await _walk(Vector3(-1.35,19.2,0)): return
	for point in [Vector3(1.5,19.2,0),Vector3(1.5,19.2,-3.4),Vector3(3.8,19.2,-3.4),Vector3(3.8,17.6,1.3),Vector3(2.3,17.6,1.3),Vector3(2.3,16,-3.5)]:
		if not await _walk(point): return
	_require(player.is_on_floor() and not player.noclip,"machine route returns to F06 with ordinary collision")
	failures.erase("lift suspension checks interrupted before completion")

func _shaft_inspection() -> void:
	# Supplemental render inspection, not a claimed player route into the well.
	# Restore the ordinary controller before continuing the collision walk.
	var pose := player.camera.transform
	player.set_physics_process(false)
	player.camera.global_position = world.adapter.root.to_global(Vector3(.5,17.4,-1.7))
	await _roof_capture("counterweight_in_shaft",Vector3(-.75,16.9,-.48))
	player.camera.transform = pose
	player.set_physics_process(true)

func _mesh_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for index in 8:
			var point := root.to_local(mesh.to_global(mesh.get_aabb().get_endpoint(index)))
			if first:
				bounds = AABB(point,Vector3.ZERO)
				first = false
			else: bounds = bounds.expand(point)
	return bounds
