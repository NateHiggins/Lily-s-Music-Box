extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Static construction inspection of exposed landing undersides and retained bodies.

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var levels: Dictionary={}
	for level: Dictionary in layout.levels:levels[str(level.id)]=float(level.y)
	var draws: Array[MeshInstance3D]=[]
	for space: Dictionary in layout.spaces:
		var holder:=root.get_node_or_null(str(space.id))
		if holder!=null and holder.has_node("Ceiling"):draws.append(holder.get_node("Ceiling"))
	for platform: Dictionary in layout.platforms:draws.append(root.get_node(str(platform.id)))
	var cache: Array=[]
	for draw: MeshInstance3D in draws:
		if not draw.is_visible_in_tree():continue
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		cache.append({"owner":str(root.get_path_to(draw)),"bounds":pose*draw.mesh.get_aabb(),"faces":pose*draw.mesh.get_faces()})
	var samples:=0;var missing:=0;var duplicate:=0
	for platform: Dictionary in layout.platforms:
		var draw:=root.get_node(str(platform.id)) as MeshInstance3D
		if draw.mesh.get_surface_count()==2:
			var arrays: Array=draw.mesh.surface_get_arrays(1)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
			check(uv.size()==vertices.size() and normals.size()==vertices.size() and tangents.size()==vertices.size()*4,"new underside exports complete mapping arrays")
			var mapped:=true
			for i in vertices.size():
				var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				# ArrayMesh's 16-bit octahedral normal/tangent storage returns
				# 15.26 microradians on an exact axis; inspect within two codes.
				mapped=mapped and vertices[i].is_finite() and uv[i].is_finite() and normals[i].distance_to(Vector3.DOWN)<.00003
				mapped=mapped and tangent.distance_to(Vector3.RIGHT)<.00003 and is_equal_approx(tangents[i*4+3],1.0)
				mapped=mapped and absf(normals[i].length()-1)<.000001 and absf(tangent.length()-1)<.000001 and absf(tangent.dot(normals[i]))<.000001
				if i%3<2:mapped=mapped and absf(vertices[i].distance_to(vertices[i+1])-uv[i].distance_to(uv[i+1]))<.00005
			check(mapped,"underside retains metre scale and its downward orthogonal tangent basis: "+str(platform.id)+" n="+str(normals[0])+" t="+str(tangents.slice(0,4)))
			var cls:=str(platform.get("class","core"))
			check(draw.mesh.surface_get_material(0)==root.architectural_materials.material_for(str(platform.id),cls),"original walking surface keeps its material: "+str(platform.id))
			check(draw.mesh.surface_get_material(1)==root.architectural_materials.material_for("Ceiling",cls),"new underside uses the existing ceiling finish: "+str(platform.id))
		var body:=draw.get_node("Collision") as StaticBody3D
		check(body.get_child_count()==1 and body.get_child(0).shape is BoxShape3D,"retained platform keeps its original single box body")
		var rect: Array=platform.rect
		var underside: float=levels[str(platform.level)]-float(layout.dimensions.slab_thickness)
		var body_shape:=body.get_child(0).shape as BoxShape3D
		check(body_shape.size.is_equal_approx(Vector3(float(rect[2])-float(rect[0]),.2,float(rect[3])-float(rect[1]))),"source platform body dimensions remain unchanged")
		for ux: float in [.08,.5,.92]:
			for uz: float in [.08,.5,.92]:
				var point:=Vector3(lerpf(float(rect[0]),float(rect[2]),ux),underside-.08,lerpf(float(rect[1]),float(rect[3]),uz))
				var surfaces:=0
				for record: Dictionary in cache:
					if not (record.bounds as AABB).grow(.001).has_point(point+Vector3.UP*.08):continue
					var distance:=_mesh_distance(record.faces,point,Vector3.UP)
					if is_finite(distance) and absf(distance-.08)<.00003:surfaces+=1
				if surfaces==0:missing+=1
				if surfaces>1:duplicate+=1
				check(surfaces==1,"one visible underside at "+str(platform.id)+" "+str(point)+" owners="+str(surfaces))
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(point),root.to_global(point+Vector3.UP*.16),1,[world.player.get_rid()])
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and absf(point.distance_to(root.to_local(hit.position))-.08)<.0001,"visible underside meets retained structural collision")
				samples+=1
	await _capture_soffits(world,root)
	print("LANDING SOFFITS: platforms=%d samples=%d missing=%d duplicate=%d checks=%d failures=%d startup_ms=%f" % [layout.platforms.size(),samples,missing,duplicate,checks,failures.size(),world.startup_ms])
	for failure: String in failures:print("LANDING SOFFIT FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture_soffits(world: Node3D,root: Node3D) -> void:
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=60
	for view: Array in [
		["basement_north",Vector3(4.6,-1.676,2.7),Vector3(3.2,-.2,2.4)],
		["floor_02_south",Vector3(4.7,4.724,-3.4),Vector3(3.0,6.2,-3.0)],
		["floor_03_lift_side",Vector3(.8,7.924,2.35),Vector3(1.45,9.4,-1.5)],
		["service_basement",Vector3(11.075,-1.676,3.0),Vector3(11.2,-.2,3.8)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
