extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## Native surface fit, actual wall bearings and the single moving collision owner.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"fitted front facade initializes in production")
	if world.startup_failed:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root;var model: Node3D=root.get_node("FrontFacade")
	var anchor:=world.adapter.resolve("F01_DOOR_06") as Node3D
	var door:=anchor.get_node("F01_DOOR_06_Leaf") as DoorProp
	check(door is LandmarkEntryDoor and door.door_kind=="landmark_entry" and not anchor.has_node("Hinge"),"original landmark behavior replaces the noninteractive graybox")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_front_facade.json"))
	check(FileAccess.get_sha256("res://assets/props/front_facade.glb")==fixture.asset_sha256,"native export binds to the fitted construction fixture")
	var parts:=0;var triangles:=0;var excluded: Array[RID]=[world.player.get_rid(),door._body.get_rid()]
	for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	for branch: Node3D in [model,door.native_leaf]:
		for draw: MeshInstance3D in branch.find_children("*","MeshInstance3D",true,false):
			if not draw.has_meta("facade_material_key"):continue
			var spec: Dictionary=fixture.parts.filter(func(row):return row.name==str(draw.name))[0]
			parts+=1;triangles+=draw.mesh.get_faces().size()/3
			check(draw.mesh.get_faces().size()==int(spec.triangles)*3,"precise partition retains every native triangle")
			check(draw.mesh.get_aabb().size.max_axis_index()>=0 and maxf(draw.mesh.get_aabb().size.x,maxf(draw.mesh.get_aabb().size.y,draw.mesh.get_aabb().size.z))<=4.00001,"draw is spatially bounded")
			_check_planar_mapping(draw.mesh,true)
			var material:=draw.get_active_material(0)
			if spec.key=="glass":check(material is ShaderMaterial and material.shader==preload("res://shaders/lamp_glass_surface.gdshader"),"real panes use the established clear dielectric")
			else:
				check(material is StandardMaterial3D and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(spec.tile)),"local metre charts retain original catalogue scale")
				check(material.albedo_texture!=null and material.normal_texture!=null and material.roughness_texture!=null,"all three existing maps reach each opaque stock")
			var shapes:=draw.find_children("*","CollisionShape3D",true,false)
			if branch==model:check(shapes.size()==1 and shapes[0].shape.get_faces()==draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform),"fixed native faces have exactly matching collision")
			else:check(shapes.is_empty(),"fabricated leaf has no second collider or interaction owner")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"complete fixed and moving export accounted")
	for row: Dictionary in fixture.contacts:
		var at:=model.to_global(Vector3(row.point[0],row.point[1],row.point[2]));var outward:=model.global_basis.z.normalized()
		var query:=PhysicsRayQueryParameters3D.create(at+outward*.003,at-outward*.03,1,excluded)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and str(hit.collider.get_path()).contains("ExteriorMasonry") and hit.position.distance_to(at)<.00005,"each canopy pier anchor seats on retained masonry")
	var shape:=door._body.get_child(0) as CollisionShape3D
	for degree in range(0,101,2):
		var pose:=door._body.global_transform
		pose.basis=door.global_basis*Basis(Vector3.UP,deg_to_rad(degree))
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=pose*shape.transform;query.collision_mask=1;query.exclude=[world.player.get_rid(),door._body.get_rid()];query.margin=.0001
		check(world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"physical leaf sweep clears retained and fitted fabric at "+str(degree))
	var blade: Node3D=root.get_node("F01_NEON_BLADE")
	check(AcousticGraphData.node_pos(blade.graph_node_id).distance_to(blade.global_position)<.00001,"original acoustic identity follows the fitted sign")
	check(root.to_local(blade.global_position).distance_to(Vector3(fixture.blade_root_position[0],fixture.blade_root_position[1],fixture.blade_root_position[2]))<.00001,"blade derives the nearest front-wing pier seats")
	print("FACADE BLADE pose=",blade.global_transform," draws=",blade.find_children("*","MeshInstance3D",true,false).size())
	for y: float in [4.1175,9.0825]:
		var at:=Vector3(blade.global_position.x,y,blade.global_position.z);var outward:=-root.global_basis.z.normalized()
		var ray:=PhysicsRayQueryParameters3D.create(at+outward*.003,at-outward*.035,1,excluded);ray.collide_with_areas=false
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and str(hit.collider.get_path()).contains("ExteriorMasonry") and hit.position.distance_to(at)<.0001,"original blade bracket has a real retained pier")
		var approach:=PhysicsRayQueryParameters3D.create(Vector3(blade.global_position.x,y,4),at,1,[world.player.get_rid()])
		print("FACADE STREET OCCLUDER at y=",y," hit=",world.get_world_3d().direct_space_state.intersect_ray(approach))
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["front",Vector3(0,1.43,6),Vector3(0,2.7,0)],["approach",Vector3(3,1.43,4),Vector3(0,2.7,0)],["door",Vector3(.45,1.43,1.55),Vector3(0,1.6,0)],["canopy",Vector3(1.5,1.43,2.8),Vector3(0,3.1,.4)],["blade",Vector3(9,1.43,4),blade.global_position+Vector3(0,0,.65)],["front_wide",Vector3(0,1.43,11),Vector3(0,6,0)]]:
		var feet: Vector3=view[1]-Vector3.UP*world.player.STANDING_EYE
		var ground:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.35,feet-Vector3.UP*.40,1,[world.player.get_rid()])
		var support: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ground)
		check(not support.is_empty() and support.normal.y>.7,"retained pavement supports capture station "+str(view[0]))
		if not support.is_empty():feet=support.position+Vector3.UP*.02;print("FACADE STATION SUPPORT ",view[0]," ",support.collider.get_path()," feet=",feet)
		camera.global_position=feet+Vector3.UP*world.player.STANDING_EYE;camera.look_at(view[2]);world.player.global_position=feet;world.player.camera.global_transform=camera.global_transform
		var stance:=PhysicsShapeQueryParameters3D.new();stance.shape=world.player._capsule;stance.collision_mask=1;stance.exclude=[world.player.get_rid()]
		stance.transform=Transform3D(Basis.IDENTITY,world.player.global_position+Vector3.UP*world.player.STANDING_HEIGHT*.5)
		var blockers: Array=world.get_world_3d().direct_space_state.intersect_shape(stance,4)
		for blocker: Dictionary in blockers:print("FACADE STATION BLOCKER ",view[0]," ",blocker.collider.get_path())
		check(blockers.is_empty(),"ordinary standing capsule clears capture station "+str(view[0]))
		world.player.set_lamp_enabled(true);await _settled_optics();await shot(str(view[0]))
	world.player.global_position=Vector3(blade.global_position.x,.02,2.1)
	var inspection: Node3D=blade.get_node("NeonSignInspection")
	world.player.face_world_point(inspection.get_child(0).global_position)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;world.player._update_prompt()
	var inspect_ray:=PhysicsRayQueryParameters3D.create(world.player.camera.global_position,world.player.camera.global_position-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()]);inspect_ray.collide_with_areas=true
	print("FACADE INSPECTION ",world.get_world_3d().direct_space_state.intersect_ray(inspect_ray)," prompt=",world.player._prompt.text)
	check(world.player._prompt.text.contains("Inspect ORISON neon"),"original low transformer inspection is reachable from the pavement")
	print("FRONT FACADE TEST: parts=",parts," triangles=",triangles," checks=",checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
