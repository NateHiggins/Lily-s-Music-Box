extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var world: OrisonV2RuntimeRoot
var player: PlayerController
var trace: Array[Dictionary] = []
var failures: Array[String] = []
var route_label := "VERTICAL ROUTE"
var externally_managed := false
var interaction_checks: Array[Dictionary] = []

func _ready() -> void:
	if not externally_managed: call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().create_timer(0.5).timeout
	if world.startup_failed:
		failures.append("runtime startup")
	else:
		player = world.player
		_prepare_player_start()
		player.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await get_tree().process_frame
		await get_tree().process_frame
		await _route()
	Input.action_release("move_forward")
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("route.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"failures": failures, "trace": trace}, "  "))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("last_position.png"))
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().create_timer(0.25).timeout
	print("%s: %d waypoints; %d failures" % [route_label, trace.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(1.925, 0.02, -3.5))
	player.velocity = Vector3.ZERO

func _route() -> void:
	# Both occupied upper storeys are part of the default building now.
	for floor_index in 5:
		var base := floor_index * 3.2
		for point in [Vector3(1.925, base + 1.6, 1.3), Vector3(3.975, base + 1.6, 1.3),
				Vector3(3.975, base + 3.2, -2.4), Vector3(3.975, base + 3.2, -3.4)]:
			if not await _walk(point): return
		if floor_index == 1:
			# F03 decision landing connects to the same crossing used by the 3B route.
			for point in [Vector3(5.0, 6.4, -3.25), Vector3(8.85, 6.4, -3.25)]:
				if not await _walk(point): return
			# Follow the real riser bypass, then climb and descend the service stair.
			var service_approach := [Vector3(8.85, 6.4, -1.0), Vector3(7.65, 6.4, -1.0),
					Vector3(7.65, 6.4, 2.0), Vector3(8.9, 6.4, 2.0), Vector3(8.9, 6.4, 5.55),
					Vector3(10.05, 6.4, 5.55), Vector3(10.05, 6.4, 4.3), Vector3(11.075, 6.4, 4.3)]
			for point in service_approach:
				if point==Vector3(10.05,6.4,5.55) and not await _move_front_entrance("F03_SERVICE_CORE_DOOR",true):return
				if not await _walk(point): return
			for point in [Vector3(11.075, 8.0, 9.15), Vector3(12.425, 8.0, 9.15),
					Vector3(12.425, 9.6, 5.65), Vector3(12.425, 8.0, 9.15),
					Vector3(11.075, 8.0, 9.15), Vector3(11.075, 6.4, 4.3)]:
				if not await _walk(point): return
			service_approach.reverse()
			for point in service_approach:
				if not await _walk(point): return
				if point==Vector3(8.9,6.4,5.55) and not await _move_front_entrance("F03_SERVICE_CORE_DOOR",false):return
			for point in [Vector3(8.85, 6.4, -3.25), Vector3(5.0, 6.4, -3.25), Vector3(3.975, 6.4, -3.4)]:
				if not await _walk(point): return
		elif floor_index >= 2:
			# Dossier slice 85: the F04-F06 service halls' first walked route, past the riser cluster's
			# maintenance evidence by the bypass and into the service core, then back to the stair.
			var y := base + 3.2
			var hall := [Vector3(5.0, y, -3.25), Vector3(8.9, y, -3.25), Vector3(8.9, y, -1.0), Vector3(7.65, y, -1.0),
					Vector3(7.65, y, 2.0), Vector3(8.9, y, 3.2), Vector3(10.05, y, 3.2)]
			for point in hall:
				if not await _walk(point): return
			hall.reverse()
			for point in hall:
				if not await _walk(point): return
			if not await _walk(Vector3(3.975, y, -3.4)): return
		if not await _walk(Vector3(1.925, base + 3.2, -3.4)): return
	# Return down the same physical stair, keeping the controller live throughout.
	for floor_index in [4, 3, 2, 1, 0]:
		var base: float = floor_index * 3.2
		for point in [Vector3(3.975, base + 3.2, -3.4), Vector3(3.975, base + 1.6, 1.3),
				Vector3(1.925, base + 1.6, 1.3), Vector3(1.925, base, -3.5)]:
			if not await _walk(point): return
	# The lower primary flight must also connect the actual B1 landing.
	for point in [Vector3(3.975, 0, -3.4), Vector3(3.975, -1.6, 1.3),
			Vector3(1.925, -1.6, 1.3), Vector3(1.925, -3.2, -3.5),
			Vector3(1.925, -1.6, 1.3), Vector3(3.975, -1.6, 1.3),
			Vector3(3.975, 0, -2.4)]:
		if not await _walk(point): return

func _walk(local_target: Vector3) -> bool:
	var target: Vector3 = world.adapter.root.to_global(local_target)
	var started := Time.get_ticks_msec()
	var travel_budget_ms := maxi(6000, int(player.global_position.distance_to(target) / player.WALK * 1000.0) + 2000)
	var contacts := {}
	var frames := 0
	while Time.get_ticks_msec() - started < travel_budget_ms:
		frames+=1
		var delta := target - player.global_position
		delta.y = 0
		if delta.length() < 0.1: break
		player.rotation.y = atan2(-delta.x, -delta.z)
		player.camera.rotation = Vector3.ZERO
		Input.action_press("move_forward", minf(1.0, delta.length() / 0.35))
		await get_tree().physics_frame
		for index in player.get_slide_collision_count():
			var contact := player.get_slide_collision(index)
			var collider := contact.get_collider() as Node
			if collider != null and absf(contact.get_normal().y) < .7:
				contacts[str(collider.get_path())] = str(contact.get_position())
	Input.action_release("move_forward")
	await get_tree().physics_frame
	var actual: Vector3 = world.adapter.root.to_local(player.global_position)
	var ok := Vector2(actual.x - local_target.x, actual.z - local_target.z).length() < 0.18 \
			and absf(actual.y - local_target.y) < 0.15 and not player.noclip \
			and player.collision_mask == 1 and player.is_physics_processing()
	trace.append({"target": [local_target.x, local_target.y, local_target.z],
			"actual": [actual.x, actual.y, actual.z], "ok": ok, "wall_contacts": contacts})
	if not ok:
		var label := "target %s actual %s" % [local_target, actual]
		failures.append(label)
		push_error(route_label + ": " + label)
		print("ROUTE_COLLISION_DIAGNOSTIC ", JSON.stringify({"contacts":contacts,"frames":frames,"elapsed_ms":Time.get_ticks_msec()-started,"call_locked":player.call_locked,"inspecting":player.inspecting(),"physics":player.is_physics_processing(),"velocity":str(player.velocity)}))
	return ok

## Every street round now passes the same closed production landmark leaf.
## The vestibule's inner doorway is unhung; walk through it to the street
## door, grab from outside the real leaf sweep, then walk through.
func _leave_front_entrance() -> bool:
	for point in [Vector3(1.925,0,-6.5),Vector3(0,0,-7.65),Vector3(0,0,-10.2)]:
		if not await _walk(point):return false
	if not await _open_front_entrance():return false
	return await _walk(Vector3(0,0,-12.2))

## Arrival remains at the production street spawn; approach and operate the leaf.
func _enter_front_entrance() -> bool:
	if not await _walk(Vector3(0,0,-13.15)):return false
	if not await _open_front_entrance():return false
	if not await _walk(Vector3(0,0,-10.2)):return false
	return await _walk(Vector3(0,0,-8.5))

func _open_front_entrance(identity: String="F01_DOOR_06") -> bool:
	return await _move_front_entrance(identity,true)

func _close_front_entrance(identity: String="F01_DOOR_06") -> bool:
	return await _move_front_entrance(identity,false)

func _move_front_entrance(identity: String,want_open: bool) -> bool:
	var anchor:=world.adapter.resolve(identity) as Node3D
	var door:=anchor.get_node(identity+"_Leaf") as DoorProp
	var goal:=door.motion_target_angle(want_open)
	if door.open!=want_open or door._moving or absf(door._body.rotation.y-goal)>.01:
		# The free edge travels out of arm reach during the outward swing.
		# Grab the hinge-side third without changing the real reach constraint.
		player.face_world_point(door._body.to_global(Vector3(door.width/3.0,1.1,door._hinge_offset)))
		player.set_mouse_released(false)
		await get_tree().physics_frame
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
		player._unhandled_input(click)
		var held_contact: Vector3=player._grab.contact
		for frame in 160:
			if not player._grab.active() or player._grab.target.owner!=door:break
			var angle: float=player._grab.target.read.call()
			if absf(angle-goal)<.000001:break
			var point:=door._body.to_global(player._grab.contact)
			var tangent: Vector3=door.global_basis.y.cross(point-door._body.global_position)
			var screen: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
			if screen.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
				screen=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
			var motion:=InputEventMouseMotion.new();motion.relative=screen*clampf(goal-angle,-.12,.12)
			player._unhandled_input(motion)
			await get_tree().physics_frame
		if player._grab.active():player._unhandled_input(click)
		await get_tree().physics_frame
		if door.open!=want_open or door._moving or absf(door._body.rotation.y-goal)>.01:
			var at:=door._body.to_global(held_contact)
			var obstruction:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,at,1,[player.get_rid()]))
			print("DOOR_HAND_DIAGNOSTIC ",identity," angle=",door._body.rotation.y," wanted=",goal," point=",at," camera=",player.camera.global_position," distance=",at.distance_to(player.camera.global_position)," blocker=",obstruction.get("collider"))
			failures.append(identity+" did not reach its requested stop through player input: "+str(door._body.rotation.y)+" / "+str(goal));return false
	return true
