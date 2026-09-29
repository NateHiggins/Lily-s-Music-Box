extends "res://tests/orison_v2_public_doors_test.gd"
## Real public-door route followed by the furnished reading-room circuit.
func _route() -> void:
	await super._route()
	route_label="READING FURNITURE"
	if not failures.is_empty(): return
	var room := world.adapter.resolve("F01_COMMON_B") as Node3D
	var furniture := room.get_node("ReadingFurniture") as Node3D
	if furniture.get_child_count()!=9:
		failures.append("one reading table, six chairs and two bookcases required")
		return
	var contacts := 0
	var triangles := 0
	var batches := 0
	for body: StaticBody3D in furniture.get_children():
		var faces := PackedVector3Array()
		for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			var transform := body.global_transform.affine_inverse()*mesh.global_transform
			for vertex in mesh.mesh.get_faces(): faces.append(transform*vertex)
			batches+=1
		triangles+=faces.size()/3
		var lowest := INF
		for vertex in faces: lowest=minf(lowest,vertex.y)
		if absf(lowest)>.004: failures.append("furniture feet must seat on the room floor: "+str(body.name))
		var origin := Vector3(0,1.1,0) if body.name=="Table" else Vector3(0,.7,0)
		var direction := Vector3.DOWN
		if str(body.name).begins_with("Bookcase"):
			origin=Vector3(0,.90,-.5);direction=Vector3.BACK
		var nearest := INF
		for i in range(0,faces.size(),3):
			var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
			if hit!=null: nearest=minf(nearest,origin.distance_to(hit))
		var ray := PhysicsRayQueryParameters3D.create(body.to_global(origin),body.to_global(origin+direction*1.2),1,[player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider")!=body or not is_finite(nearest) or absf(nearest-origin.distance_to(body.to_local(hit.get("position",Vector3.ZERO))))>.001:
			failures.append("actual collision must meet imported furniture triangles: "+str(body.name))
		contacts+=1
	# From the existing arrival, walk around both table sides and up to the
	# bookcases, then return to the package-room door without repositioning.
	for point in [Vector3(-10.3,0,2.4),Vector3(-10.3,0,-1.4),Vector3(-14.6,0,-1.4),Vector3(-14.6,0,3.4),Vector3(-14.6,0,4.35),Vector3(-11.4,0,4.35),Vector3(-10.3,0,3.4),Vector3(-10.3,0,2.4)]:
		if not await _walk(point): return
	player.face_world_point(furniture.get_node("Table").to_global(Vector3(0,.75,0)))
	await get_tree().create_timer(1).timeout
	await _capture("furnished_reading_room_player")
	for layer in player.carried_device.get_children():
		if layer is CanvasLayer: layer.hide()
	await _capture("furnished_reading_room_clear")
	var camera := Camera3D.new()
	world.add_child(camera);camera.make_current();camera.fov=65
	camera.global_position=furniture.get_node("Table").to_global(Vector3(-1.8,1.05,-1.3))
	camera.look_at(furniture.get_node("Table").to_global(Vector3(0,.65,0)))
	var fill := OmniLight3D.new()
	world.add_child(fill);fill.global_position=camera.global_position;fill.light_energy=.45;fill.omni_range=4
	await get_tree().create_timer(.25).timeout
	await _capture("reading_table_joinery_and_chairs")
	camera.global_position=furniture.get_node("Bookcase_west").to_global(Vector3(.75,1.2,-1.5))
	camera.look_at(furniture.get_node("Bookcase_west").to_global(Vector3(0,.95,0)))
	fill.global_position=camera.global_position
	await get_tree().create_timer(.25).timeout
	await _capture("reading_bookcase_shelves_and_bindings")
	print("READING FURNITURE CONTACTS: bodies=%d batches=%d triangles=%d failures=%d" % [contacts,batches,triangles,failures.size()])
