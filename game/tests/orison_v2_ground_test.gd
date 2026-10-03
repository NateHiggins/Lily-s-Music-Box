extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## INERT installed native ground, original ownership and mapped surface checks.
const SOURCE := "res://tests/fixtures/orison_ground_source.json"
const CONSTRUCTION := "res://tests/fixtures/orison_ground_construction.json"

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var owner:=root.get_node("Ground") as Node3D
	var asphalt:=MatLib.get_mat("asphalt") as StandardMaterial3D
	check(asphalt.albedo_texture!=null and asphalt.roughness_texture!=null and asphalt.normal_texture!=null,"catalogued asphalt has all three original maps")
	check(asphalt.uv1_scale.is_equal_approx(Vector3.ONE/2.5),"catalogue owns the 2.5 metre asphalt scale")
	var construction: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONSTRUCTION))
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var parts:=0;var triangles:=0;var native:=PackedVector3Array()
	var new_bodies: Array[RID]=[]
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		_check_planar_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bounds: AABB=pose*draw.mesh.get_aabb()
		check(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<=4.00001,"ground has bounded material parts")
		native.append_array(pose*draw.mesh.get_faces())
		var material:=draw.material_override as StandardMaterial3D
		check(material!=null and not material.uv1_triplanar,"installed ground uses the verified metre UV channel")
		new_bodies.append(draw.get_node("GroundCollision").get_rid())
	check(parts==construction.parts.size() and triangles==construction.native_faces*2,"production imports the complete bound native ground export")
	check(FileAccess.get_sha256("res://assets/props/orison_ground.glb")==construction.source_native_sha256,"installed ground binds its exact native export")
	await get_tree().physics_frame;await get_tree().physics_frame
	var old_exclude: Array[RID]=[world.player.get_rid()]
	for name: String in ["RearWingASupport","RearWingCSupport","Foundations"]:
		for body: CollisionObject3D in root.get_node(name).find_children("*","CollisionObject3D",true,false):old_exclude.append(body.get_rid())
	var original_exclude:=old_exclude.duplicate();original_exclude.append_array(new_bodies)
	var stations: Dictionary=source.stations
	var discovery: Dictionary={"records":source.prior_records}
	var plan: Dictionary=construction.source_plan
	var results: Array=[];var contacts:=0;var embedded:=0;var reproduced:=0
	for record_index in stations.records.size():
		var post: Dictionary=stations.records[record_index]
		for point_index in post.points.size():
			var p: Array=post.points[point_index];var at:=Vector3(p[0],p[1],p[2])
			var containing: Array=[]
			for component: Dictionary in plan.retained_solids:
				if component.kind not in ["authored_original_box","authored_union_component","actual_axis_aligned_box","retained_continuous_paving_substrate"]:continue
				var b: Array=component.bounds
				if at.x>b[0]+.00001 and at.x<b[3]-.00001 and at.y>=b[1]-.00001 and at.y<=b[4]+.00001 and at.z>b[2]+.00001 and at.z<b[5]-.00001:containing.append(component.id)
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.05),root.to_global(at-Vector3.UP*4),1,old_exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			var distance:=_mesh_distance(native,at+Vector3.UP*.05,Vector3.DOWN)
			if containing.is_empty():
				check(not hit.is_empty() and new_bodies.has(hit.collider.get_rid()) and absf(root.to_local(hit.position).y+.02)<.00003,"unchanged exterior station meets the actual new native terrain")
				check(is_finite(distance) and absf(distance-.07)<.00003,"native mesh and collision agree at the exterior station")
				contacts+=1
			else:
				check(not is_finite(distance) or absf(distance-.07)>.0001,"existing embedded masonry station is not filled by new terrain")
				embedded+=1
			query.exclude=original_exclude
			var old_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			var prior: Dictionary=discovery.records[record_index].samples[point_index]
			var same:=old_hit.is_empty() if str(prior.first_owner).is_empty() else not old_hit.is_empty() and str(world.get_path_to(old_hit.collider))==str(prior.first_owner) and absf(root.to_local(old_hit.position).y-float(prior.first_y))<.00003
			check(same,"excluding only the ground reproduces the original unshifted discovery")
			if same:reproduced+=1
			results.append({"post":post.post,"point":p,"retained_components":containing,"terrain_y":root.to_local(hit.position).y if not hit.is_empty() else null,"original_reproduced":same})
	check(contacts==46 and embedded==2 and reproduced==48,"all 48 original stations have explicit terrain or retained-volume ownership")
	var air_ray:=PhysicsRayQueryParameters3D.create(root.to_global(Vector3(16.6,-1.3,3.2)),root.to_global(Vector3(15.5,-1.3,3.2)),1,[world.player.get_rid()])
	var air_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(air_ray)
	print("POST PAVEMENT AIR THROAT: owner=",str(world.get_path_to(air_hit.collider)) if not air_hit.is_empty() else "empty")
	check(air_hit.is_empty(),"ground subgrade preserves the existing open collision throat of the boiler window")
	var camera: Camera3D=world.player.camera;camera.make_current();camera.fov=65
	var observations: Array=[]
	for view: Array in [["west_grade",Vector3(-17.3,1.524,8.5),Vector3(-15.8,0,8.5)],
		["north_grade",Vector3(-7,1.524,14),Vector3(-7,0,11.8)],
		["east_grade",Vector3(7.65,1.524,8.5),Vector3(7.205,0,9.1)],
		["boiler_air_reserved_below_alley",Vector3(16.5,-1.1,2.7),Vector3(15.93,-1.3,3.2)],
		["east_maint_route",Vector3(14,1.524,10.8),Vector3(8.5,0,11)],
		["courtyard_city_plinth",Vector3(20.5,1.524,11.6),Vector3(19.7,0,10.15)],
		["west_front_seam",Vector3(-18,1.524,-10.2),Vector3(-16,0,-11.65)],
        ["front_east_recess",Vector3(6.1,1.524,-13.3),Vector3(6.1,.0,-9.4)],
        ["front_west_recess",Vector3(-3.9,1.524,-13.3),Vector3(-3.9,.0,-9.8)]]:
		world.player.global_position=root.to_global(view[1])-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(root.to_global(view[2]))
		camera.basis=camera.basis.orthonormalized();world.player._hand.basis=world.player._hand.basis.orthonormalized()
		world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
		var shown:=_ground_render_stats()
		owner.hide();await _settled_optics();var hidden:=_ground_render_stats()
		owner.show();await _settled_optics()
		observations.append({"view":view[0],"shown":shown,"hidden":hidden,"note":"Matched stationary native ground visibility; collision stays enabled. No timing verdict."})
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("ground-inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","parts":parts,"triangles":triangles,"terrain_contacts":contacts,"embedded_stations":embedded,"original_reproduced":reproduced,"results":results,"render_observations":observations,"checks":checks,"failures":failures,"note":"Installed bounded ground only. Drainage, air-well, city plinth and weather closure remain open."},"\t")+"\n");file.close()
	print("INERT V2 GROUND: parts=%d triangles=%d contacts=%d embedded=%d reproduced=%d checks=%d failures=%d" % [parts,triangles,contacts,embedded,reproduced,checks,failures.size()])
	for failure: String in failures:print("COURTYARD TRIAL FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _ground_render_stats() -> Dictionary:
	var viewport:=get_viewport().get_viewport_rid()
	return {"draw_calls":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
