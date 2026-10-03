extends "res://tests/orison_v2_lift_joinery_test.gd"
## Reproduce the old corner overlaps/gaps, then check one real weather surface.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false); world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var root: Node3D=world.adapter.root
	var owners: Array=root.fabricated_fixtures.get("roof_coping",[])
	var model: Node3D=root.get_node("FittedRoofCoping")
	var stone := model.get_node("CopingCourse") as MeshInstance3D
	check(stone.mesh is ArrayMesh,"roof has imported weathered coping")
	check(owners.size()==4,"four original cap owners remain")
	var old_faces := PackedVector3Array()
	var width := INF
	var contacts := 0
	var faces := stone.mesh.get_faces()
	var bounds := stone.mesh.get_aabb()
	for owner: MeshInstance3D in owners:
		check(not owner.visible,"overlapping primitive cap is hidden")
		var shape := owner.get_node("Collision").find_children("*","CollisionShape3D",false,false)[0] as CollisionShape3D
		check(not shape.disabled,"original cap collision stays enabled")
		var size := (owner.mesh as BoxMesh).size
		width=minf(width,minf(size.x,size.z))
		var relative := model.global_transform.affine_inverse()*owner.global_transform
		for vertex: Vector3 in owner.mesh.get_faces(): old_faces.append(relative*vertex)
		var at := model.to_local(owner.global_position)
		at[0 if size.x>size.z else 2]+=.037 # avoid an expansion joint
		var origin := at+Vector3.UP*.15
		var ray := PhysicsRayQueryParameters3D.create(model.to_global(origin),model.to_global(at-Vector3.UP*.10),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==owner.get_node("Collision"),"weather course retains its actual coping support")
		var distance := _mesh_distance(faces,origin,Vector3.DOWN)
		check(is_finite(distance),"coping crest has an imported surface")
		if not hit.is_empty(): check(absf(distance-origin.distance_to(model.to_local(hit.position)))<.002,"coping crest meets the original collision top")
		contacts+=1
	var corners := 0
	var old_defects := 0
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			for offset in [Vector2(-.035,.021),Vector2(.021,-.035),Vector2(.12,.105)]:
				var at := Vector3(sx*(bounds.end.x-width*.5+offset.x),bounds.end.y+.2,sz*(bounds.end.z-width*.5+offset.y))
				if _top_layers(old_faces,at,bounds.end.y)!=1: old_defects+=1
				check(_top_layers(faces,at,bounds.end.y)==1,"corner has exactly one weather surface, without overlap or missing outer quadrant")
				corners+=1
	check(old_defects>0,"same stations reproduce the old cap-box defects")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=65
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.light_energy=.3; fill.omni_range=4
	var corner := Vector3(bounds.end.x-width*.5,bounds.end.y,bounds.end.z-width*.5)
	var target := model.to_global(corner)
	camera.global_position=target+model.global_basis*Vector3(-width*2.2,width*1.2,-width*2.2)
	camera.look_at(target); fill.global_position=camera.global_position
	await shot("mitered_roof_corner")
	target=model.to_global(Vector3(0,bounds.end.y,bounds.end.z-width*.5))
	camera.global_position=target+model.global_basis*Vector3(width*3.5,width*1.8,-width*7.1)
	camera.look_at(target); fill.global_position=camera.global_position
	await shot("jointed_weather_course")
	print("ROOF COPING: contacts=%d corner_stations=%d reproduced_old_defects=%d failures=%d" % [contacts,corners,old_defects,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _top_layers(faces: PackedVector3Array,origin: Vector3,top: float) -> int:
	var count := 0
	for start in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[start],faces[start+1],faces[start+2])
		if hit!=null and hit.y>top-.016: count+=1
	return count
