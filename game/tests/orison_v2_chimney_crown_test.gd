extends "res://tests/orison_v2_lift_joinery_test.gd"
## Imported open throat, retained wall/coping collision and installed roof views.
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
	var flue: Node3D=world.adapter.root.get_node("BoilerFlue")
	var crown: Node3D=flue.get_node("FittedChimneyCrown")
	var parts := crown.find_children("*","MeshInstance3D",true,false)
	check(parts.size()==3,"brick, mortar and coping are three imported material batches")
	var bounds := AABB()
	for part: MeshInstance3D in parts:
		check(part.mesh is ArrayMesh,"chimney uses the Blender mesh")
		bounds=bounds.merge(part.transform*part.mesh.get_aabb())
		check(not is_finite(_mesh_distance(part.mesh.get_faces(),Vector3(0,2.4,0),Vector3.DOWN)),"chimney throat is geometrically open")
	var old_bodies := 0
	for child in flue.get_children():
		if child is StaticBody3D and not str(child.name).begins_with("Breeching"):
			old_bodies+=1
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",false,false):
				check(not mesh.visible,"old primitive chimney is not double-rendered")
	check(old_bodies==8,"all original chimney collision owners remain")
	var contacts := 0
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var tangent := Vector3(direction.z,0,-direction.x)*.06
		var at := Vector3.UP+tangent
		# Start beside this wall, inside the neighboring roof parapet.
		var origin: Vector3=at+direction*((bounds.size.x if direction.x!=0 else bounds.size.z)*.5+.01)
		var ray := PhysicsRayQueryParameters3D.create(crown.to_global(origin),crown.to_global(at),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider.get_parent()==flue,"bonded masonry retains its physical wall")
		var nearest := INF
		for part: MeshInstance3D in parts:
			nearest=minf(nearest,_mesh_distance(part.mesh.get_faces(),origin,-direction))
		check(is_finite(nearest),"masonry has actual exterior triangles")
		if not hit.is_empty(): check(absf(nearest-origin.distance_to(crown.to_local(hit.position)))<.003,"brick face fits existing wall collider")
		var cap_at: Vector3=direction*(.175 if direction.x!=0 else .30)
		var cap_ray := PhysicsRayQueryParameters3D.create(crown.to_global(cap_at+Vector3.UP*2.4),crown.to_global(cap_at+Vector3.UP*1.9),1,[world.player.get_rid()])
		var cap_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(cap_ray)
		check(not cap_hit.is_empty(),"coping retains solid collision")
		if not cap_hit.is_empty(): check(absf(crown.to_local(cap_hit.position).y-bounds.end.y)<.002,"stone coping fits its original top plane")
		contacts+=2
	var throat := PhysicsRayQueryParameters3D.create(crown.to_global(Vector3.UP*2.4),crown.to_global(Vector3.UP*.1),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(throat).is_empty(),"physical throat remains open above structural shaft")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=65
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.light_energy=.5; fill.omni_range=5
	var target := crown.to_global(bounds.get_center())
	camera.global_position=target+crown.global_basis*Vector3(bounds.size.x*3,bounds.size.y*.15,bounds.size.z*2.6)
	camera.look_at(target); fill.global_position=camera.global_position
	await shot("bonded_chimney")
	target=crown.to_global(Vector3.UP*bounds.end.y)
	camera.global_position=target+crown.global_basis*Vector3(bounds.size.x,bounds.size.y*.25,bounds.size.z)
	camera.look_at(target); fill.global_position=camera.global_position
	await shot("open_coping")
	print("CHIMNEY CROWN: collision_owners=%d contacts=%d failures=%d" % [old_bodies,contacts,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
