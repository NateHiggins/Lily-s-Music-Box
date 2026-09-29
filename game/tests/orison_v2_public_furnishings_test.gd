extends "res://tests/orison_v2_public_doors_test.gd"
## Benches leave the arrival/turn routes clear; racks leave both parcel doors usable.
func _route() -> void:
	for point in [Vector3(2.3,0,-6.2),Vector3(3.9,0,-6.7),Vector3(0,0,-7.15),Vector3(-3.9,0,-7.15),Vector3(-3.3,0,-5.0),Vector3(2.3,0,-5.0),Vector3(2.3,0,-3.5)]:
		if not await _walk(point):return
	await super._route()
	route_label="PUBLIC FURNISHINGS"
	if not failures.is_empty():return
	var bodies: Array[Node]=[]
	for id in ["F01_LOBBY","F01_PACKAGE"]:
		var furniture: Node = world.adapter.resolve(id).get_node("PublicFurnishings")
		bodies.append_array(furniture.get_children())
	if bodies.size()!=4:failures.append("two lobby benches and two parcel racks required");return
	var contacts := 0
	var triangles := 0
	var batches := 0
	for body: StaticBody3D in bodies:
		var faces := PackedVector3Array()
		for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			var transform := body.global_transform.affine_inverse()*mesh.global_transform
			for vertex in mesh.mesh.get_faces(): faces.append(transform*vertex)
			batches+=1
		triangles+=faces.size()/3
		# A clear aisle does not prove the furniture avoids fixed risers/walls.
		for i in range(0,faces.size(),3):
			for edge in 3:
				var a := faces[i+edge]
				var b := faces[i+(edge+1)%3]
				if minf(a.y,b.y)<.03 or a.distance_to(b)<.005:continue
				var query := PhysicsRayQueryParameters3D.create(body.to_global(a),body.to_global(b),1,[body.get_rid(),player.get_rid()])
				var obstruction: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				if not obstruction.is_empty():
					failures.append("furniture crosses installed solid: %s into %s at %s" % [body.name,obstruction.collider.get_path(),world.adapter.root.to_local(obstruction.position)])
					return
		var lowest := INF
		for vertex in faces: lowest=minf(lowest,vertex.y)
		if absf(lowest)>.004: failures.append("furniture feet must seat on the room floor: "+str(body.name))
		var origin := Vector3(.25,1.8,0) if str(body.name).ends_with("Rack") else Vector3(0,.8,0)
		var direction := Vector3.DOWN
		var nearest := INF
		for i in range(0,faces.size(),3):
			var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
			if hit!=null: nearest=minf(nearest,origin.distance_to(hit))
		var ray := PhysicsRayQueryParameters3D.create(body.to_global(origin),body.to_global(origin+direction*1.2),1,[player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider")!=body or not is_finite(nearest) or absf(nearest-origin.distance_to(body.to_local(hit.get("position",Vector3.ZERO))))>.001:
			failures.append("actual collision must meet imported furniture triangles: "+str(body.name))
		contacts+=1
	var anchor := world.adapter.resolve("F01_PACKAGE_COMMON_DOOR") as Node3D
	var door := anchor.get_node("F01_PACKAGE_COMMON_DOOR_Leaf") as DoorProp
	if not await _use(door,true):return
	for point in [Vector3(-8.1,0,2.4),Vector3(-7.3,0,2.4),Vector3(-7.3,0,3.15),Vector3(-6.5,0,2.4),Vector3(-7.3,0,1.4)]:
		if not await _walk(point):return
	player.face_world_point(world.adapter.resolve("F01_PACKAGE").get_node("PublicFurnishings/NorthRack").to_global(Vector3(0,1,0)))
	await get_tree().create_timer(.5).timeout
	await _capture("parcel_racks_player")
	for layer in player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	await _capture("parcel_racks_clear")
	var camera := Camera3D.new()
	world.add_child(camera);camera.make_current();camera.fov=65
	var root: Node3D=world.adapter.root
	camera.global_position=root.to_global(Vector3(1.2,1.41,-5.3))
	camera.look_at(root.to_global(Vector3(4.7,.65,-6.7)))
	var fill := OmniLight3D.new()
	world.add_child(fill);fill.global_position=camera.global_position;fill.light_energy=.45;fill.omni_range=5
	await get_tree().create_timer(.25).timeout
	await _capture("lobby_bench_and_clear_arrival")
	camera.global_position=root.to_global(Vector3(3.85,1.1,-7.7))
	camera.look_at(root.to_global(Vector3(4.96,.5,-6.7)));fill.global_position=camera.global_position
	await get_tree().create_timer(.25).timeout
	await _capture("bench_joinery")
	print("PUBLIC FURNISHINGS CONTACTS: bodies=%d batches=%d triangles=%d failures=%d" % [contacts,batches,triangles,failures.size()])
