extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## Actual retained wall anchors, shelf/girder mates and roof-face contacts.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"front court roof initializes in production")
	if world.startup_failed:world.free();get_tree().quit(1);return
	var root: Node3D=world.adapter.root;var model: Node3D=root.get_node("FrontCourtRoofFrame")
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_front_court_roof.json"))
	check(FileAccess.get_sha256("res://assets/props/front_court_roof.glb")==fixture.asset_sha256,"export binds to the native construction fixture")
	var excluded: Array[RID]=[world.player.get_rid()]
	var upward:=PackedVector3Array();var downward:=PackedVector3Array();var parts:=0;var triangles:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		var spec: Dictionary=fixture.parts.filter(func(r):return r.name==str(draw.name))[0]
		check(draw.mesh.get_faces().size()==int(spec.triangles)*3,"every native triangle reaches the installed draw")
		check(draw.mesh.get_aabb().size.x<=4.00002 and draw.mesh.get_aabb().size.y<=4.00002 and draw.mesh.get_aabb().size.z<=4.00002,"all draws have bounded culling extents")
		_check_planar_mapping(draw.mesh,true)
		var material:=draw.get_active_material(0) as StandardMaterial3D
		check(material!=null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(spec.tile)),"native metre charts retain catalogue scale")
		check(material.albedo_texture!=null and material.normal_texture!=null and material.roughness_texture!=null,"three catalogue maps reach each stock")
		var shapes:=draw.find_children("*","CollisionShape3D",true,false)
		check(shapes.size()==1 and shapes[0].shape.get_faces()==draw.mesh.get_faces(),"native faces have exactly one matching collider")
		excluded.append(shapes[0].get_parent().get_rid())
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var faces: PackedVector3Array=pose*draw.mesh.get_faces()
		for index in range(0,faces.size(),3):
			var normal: Vector3=(faces[index+1]-faces[index]).cross(faces[index+2]-faces[index]).normalized()
			# Godot's clockwise front winding reverses the cross-product normal.
			if normal.y<-.999:
				for j in 3:upward.append(faces[index+j])
			elif normal.y>.999:
				for j in 3:downward.append(faces[index+j])
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"complete frame is accounted")
	for row: Dictionary in fixture.contacts:
		var at:=Vector3(row.point[0],row.point[1],row.point[2]);var inward:=Vector3(row.inward[0],0,0)
		var ray:=PhysicsRayQueryParameters3D.create(root.to_global(at+inward*.025),root.to_global(at-inward*.04),1,excluded)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and str(hit.collider.get_path()).contains("ExteriorMasonry") and root.to_local(hit.position).distance_to(at)<.00003,"each backplate anchor seats on actual stepped masonry")
	for row: Dictionary in fixture.bearings:
		for x: float in row.seat_x:
			for z: float in row.seat_z:
				var below:=Vector3(x,float(row.shelf_top)-.01,z)
				var seat:=_mesh_distance(upward,below,Vector3.UP)
				var bottom:=_mesh_distance(downward,below,Vector3.UP)
				check(is_finite(seat) and is_finite(bottom) and absf(seat-.01)<.00004 and absf(bottom-.01)<.00004,"shelf top and girder underside meet with a real bearing footprint")
	for row: Dictionary in fixture.beams:
		for x: float in [-4.0,0.0,4.0]:
			var at:=Vector3(x,float(fixture.roof_underside),float(row.z))
			var height:=_mesh_distance(upward,at-Vector3.UP*.01,Vector3.UP)
			check(is_finite(height) and absf(height-.01)<.00004,"girder top reaches the original slab underside")
			var ray:=PhysicsRayQueryParameters3D.create(root.to_global(at-Vector3.UP*.03),root.to_global(at+Vector3.UP*.03),1,excluded)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and str(hit.collider.get_path()).contains("ROOF_DECK_") and root.to_local(hit.position).distance_to(at)<.00004,"retained structural slab remains the roof contact owner")
	var finished:=0
	for space: Dictionary in root.layout.spaces:
		if not str(space.id).begins_with("ROOF_DECK_"):continue
		var floor:=root.get_node(str(space.id)+"/Floor") as MeshInstance3D
		if floor.mesh.get_surface_count()!=2:continue
		finished+=1
		var material:=floor.get_active_material(1) as ShaderMaterial
		check(material==root.architectural_materials.material_for("ExteriorSoffit","service"),"only exposed roof undersides use the calibrated concrete recipe")
		check(material.get_shader_parameter("has_height") and material.get_shader_parameter("has_normal_tex") and material.get_shader_parameter("has_rough_tex"),"actual roof soffit binds all calibrated surface maps")
	check(finished>0,"exposed roof soffits retain their original draws")
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["street",Vector3(0,1.43,11),Vector3(0,10,0)],
			["front_court",Vector3(0,1.43,3),Vector3(0,18.7,-6)],
			["roof_frame",root.to_global(Vector3(1.0,17.5,-10.0)),root.to_global(Vector3(-4.7,18.6,-8.1))]]:
		camera.global_position=view[1];camera.look_at(view[2]);await _settled_optics();await shot(view[0])
	print("FRONT COURT ROOF: parts=",parts," triangles=",triangles," anchors=",fixture.contacts.size()," bearings=",fixture.bearings.size()," checks=",checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
