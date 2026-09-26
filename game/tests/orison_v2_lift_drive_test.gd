extends "res://tests/orison_v2_roof_route_test.gd"
## The guarded drive must leave both roof approaches walkable and follow the
## real production car. Only the lift request is issued directly by this test.
func _init() -> void:
	route_label = "LIFT DRIVE"

func _route() -> void:
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
	if not _require(at.z > -.31 and at.z < -.2 and absf(at.y-19.2)<.08,"actual capsule stops at the fixed machinery guard"): return
	if not await _walk(Vector3(0,19.2,.15)): return
	var lift := world.elevator as OrisonElevator
	var initial: float = drive.get("driven_angle")
	if not _require(lift.current == "F01" and not lift.moving,"guarded machine has not changed idle lift state"): return
	lift.travel_to("F02")
	var deadline := Time.get_ticks_msec()+20000
	while lift.moving and Time.get_ticks_msec()<deadline:
		await get_tree().physics_frame
	await get_tree().process_frame
	var height: float = drive.get("observed_car_height")
	var angle: float = drive.get("driven_angle")
	if not _require(not lift.moving and lift.current == "F02" and is_equal_approx(height,lift._cabin.position.y)
			and absf(angle-initial)>9.0 and is_equal_approx(angle,-height/.315),"sheave follows actual car travel"): return
	await get_tree().create_timer(.5).timeout
	if not _require(is_equal_approx(angle,float(drive.get("driven_angle"))),"stopped car stops the sheave"): return
	await _roof_capture("lift_drive_after_travel",Vector3(-.35,20.15,-1.7))
	if not await _walk(Vector3(-1.35,19.2,0)): return
	if not await _open_door("ROOF_PUBLIC_DOOR"): return
	if not await _walk(Vector3(-3.6,19.2,0)): return
	await _roof_capture("roof_machine_bulkhead",Vector3(-.1,20.4,-1.7))
	if not await _walk(Vector3(-1.35,19.2,0)): return
	for point in [Vector3(1.5,19.2,0),Vector3(1.5,19.2,-3.4),Vector3(3.8,19.2,-3.4),Vector3(3.8,17.6,1.3),Vector3(2.3,17.6,1.3),Vector3(2.3,16,-3.5)]:
		if not await _walk(point): return
	_require(player.is_on_floor() and not player.noclip,"machine route returns to F06 with ordinary collision")
