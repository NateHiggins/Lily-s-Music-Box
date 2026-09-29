extends "res://tests/orison_v2_vertical_route_test.gd"
## The lowest primary stair needs a physical foundation, not an open storey cut.
func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(4.9,-3.18,-1.2))
	player.velocity=Vector3.ZERO

func _route() -> void:
	route_label="BASEMENT FOUNDATION"
	var root: Node3D=world.adapter.root
	var foundation := world.adapter.resolve("B1_PRIMARY_STAIR_BASE") as MeshInstance3D
	if foundation==null: failures.append("missing stair base");return
	var faces := foundation.mesh.get_faces()
	var contacts := 0
	for x in [1.95,2.8,3.6,4.15]:
		for z in [-1.4,0,1.2]:
			var origin := root.to_global(Vector3(x,-3.18,z))
			var ray := PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*2,1,[player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.get("collider")!=foundation.get_node("Collision"):
				failures.append("previous void must hit the new foundation");return
			var nearest := INF
			var local := foundation.to_local(origin)
			for i in range(0,faces.size(),3):
				var h: Variant=Geometry3D.ray_intersects_triangle(local,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
				if h!=null:nearest=minf(nearest,local.distance_to(h))
			if absf(nearest-origin.distance_to(hit.position))>.001 or absf(root.to_local(hit.position).y+3.2)>.001:
				failures.append("foundation collision must meet its actual floor triangles");return
			contacts+=1
	# Inspect the original gap from the same safe landing before walking onto it.
	player.face_world_point(root.to_global(Vector3(3,-3.15,0)))
	player.set_lamp_enabled(true)
	for layer in player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	await get_tree().create_timer(.3).timeout
	await _ground_capture("continuous_basement_stair_foundation")
	# The return flight has standing clearance here. Stay out of the deliberately
	# low space under the half-landing, then climb and descend the ordinary stair.
	for point in [Vector3(3.7,-3.2,-1.4),Vector3(3.7,-3.2,-.55),Vector3(4.9,-3.2,-.55),Vector3(4.9,-3.2,-3.4),Vector3(2.3,-3.2,-3.4),Vector3(2.3,-1.6,1.3),Vector3(3.8,-1.6,1.3),Vector3(3.8,0,-3.4),Vector3(3.8,-1.6,1.3),Vector3(2.3,-1.6,1.3),Vector3(2.3,-3.2,-3.4)]:
		if not await _walk(point):return
	print("BASEMENT FOUNDATION CONTACTS: contacts=%d failures=%d" % [contacts,failures.size()])

func _ground_capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
