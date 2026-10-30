extends "res://tests/orison_v2_vertical_route_test.gd"

func _init() -> void:
	route_label = "V2 STREET BOUNDARY ROUTE"

func _route() -> void:
	if not await _leave_front_entrance():return
	for point in [Vector3(0,0,3), Vector3(-10,0,3), Vector3(-19.2,0,3),Vector3(-25,0,3),Vector3(-30,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	await _shot("open_west", Vector3(-60,1.2,3))
	var boundary := world.get_node("StreetBoundaries")
	if boundary.has_node("RetainedStreetEnds") or boundary.has_node("ShedTemporaryClosure"):
		failures.append("retired short street-end limits remain")
	if not boundary.has_node("TemporaryExteriorLimit"):failures.append("temporary distant limit is missing")
	if not world.find_children("StormCurtain_*","MeshInstance3D",true,false).is_empty():failures.append("placeholder road-end fog cards still enter V2")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-19.2,1.2,3),Vector3(-21,1.2,3))
	if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		failures.append("former west footway limit still stops passage")
	for point in [Vector3(-10,0,3), Vector3(0,0,3), Vector3(14,0,3),
			Vector3(19.5,0,3), Vector3(21.5,0,3), Vector3(24,0,3),Vector3(24,0,0),Vector3(24,0,-2.1)]:
		if not await _walk(world.adapter.root.to_local(point)): return
		if point == Vector3(21.5,0,3): await _shot("shed_entrance", Vector3(24,1.6,0))
		if point == Vector3(24,0,0): await _shot("shed_turn", Vector3(24,1.6,-3.08))
	await _shot("open_east_scaffold", Vector3(24,1.3,-4))
	ray = PhysicsRayQueryParameters3D.create(Vector3(24,1.2,-2.1),Vector3(24,1.2,-4))
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():failures.append("former temporary closure still stops passage")
	ray = PhysicsRayQueryParameters3D.create(Vector3(24,1.5,-2),Vector3(19,1.5,3))
	if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		failures.append("retired inner hoarding still closes the street view")
	for point in [Vector3(24,0,-4),Vector3(30,0,-4),Vector3(30,0,3),Vector3(0,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	if not await _enter_front_entrance():return

func _shot(identity: String, target: Vector3) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	player.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity+".png"))
