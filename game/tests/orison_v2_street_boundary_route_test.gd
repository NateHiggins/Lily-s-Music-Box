extends "res://tests/orison_v2_vertical_route_test.gd"

func _init() -> void:
	route_label = "V2 STREET BOUNDARY ROUTE"

func _route() -> void:
	for point in [Vector3(2.3, 0, -6.5), Vector3(0, 0, -8.5),
			Vector3(0, 0, -10.2), Vector3(0, 0, -12.2)]:
		if not await _walk(point): return
	for point in [Vector3(0,0,3), Vector3(-10,0,3), Vector3(-19.2,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	await _shot("west_timber", Vector3(-20.1,1.2,3))
	var boundary := world.get_node("StreetBoundaries/RetainedStreetEnds/StreetEndWeatherBoundary")
	for identity in ["WestNorthWorks", "WestStormCore", "WestSouthWorks"]:
		if not boundary.has_node(identity): failures.append("retained west span " + identity)
	if boundary.has_node("EastNorthWorks"): failures.append("east pavement remains blocked")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-19.2,1.2,3),Vector3(-21,1.2,3))
	if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		failures.append("visible west timber stops passage")
	for point in [Vector3(-10,0,3), Vector3(0,0,3), Vector3(14,0,3),
			Vector3(19.5,0,3), Vector3(21.5,0,3), Vector3(24,0,3),Vector3(24,0,0),Vector3(24,0,-2.1)]:
		if not await _walk(world.adapter.root.to_local(point)): return
		if point == Vector3(21.5,0,3): await _shot("shed_entrance", Vector3(24,1.6,0))
		if point == Vector3(24,0,0): await _shot("shed_turn", Vector3(24,1.6,-3.08))
	await _shot("east_temporary_closure", Vector3(24,1.3,-3.08))
	ray = PhysicsRayQueryParameters3D.create(Vector3(24,1.2,-2.1),Vector3(24,1.2,-4))
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or str(hit.collider.name) != "ShedTemporaryClosure":
		failures.append("visible temporary closure stops passage")
	ray = PhysicsRayQueryParameters3D.create(Vector3(24,1.5,-2),Vector3(19,1.5,3))
	if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		failures.append("dogleg occludes direct street view")
	for point in [Vector3(24,0,0),Vector3(24,0,3),Vector3(21.5,0,3),Vector3(19.5,0,3),Vector3(14,0,3),Vector3(0,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	for point in [Vector3(0,0,-10.2),Vector3(0,0,-8.5),Vector3(2.3,0,-6.5)]:
		if not await _walk(point): return

func _shot(identity: String, target: Vector3) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	player.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity+".png"))
