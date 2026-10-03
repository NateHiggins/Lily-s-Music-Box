extends "res://tests/orison_v2_roof_bulkhead_caps_test.gd"
## Production sheet roof, open outlet, retained cap and wall-contact inspection.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production service roof initializes actual world")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var model: Node3D=root.get_node("RoofServiceWeathering")
	await get_tree().physics_frame;await get_tree().physics_frame
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_service_weathering.json"))
	var cap: Array=manifest.cap_outer_rect
	var native:=PackedVector3Array();var triangles:=0;var parts:=0;var weather_bodies: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):weather_bodies.append(body.get_rid())
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		var key: String=draw.get_meta("material_key")
		check(MatLib.SETS.has(key) and draw.material_override==MatLib.get_mat(key),"weather assembly uses an actual existing mapped material key")
		_check_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bound: AABB=pose*draw.mesh.get_aabb()
		check(maxf(maxf(bound.size.x,bound.size.y),bound.size.z)<4.00001,"weather assembly export uses bounded partitions")
		native.append_array(pose*draw.mesh.get_faces())
	check(parts==6 and triangles==4546,"production weather assembly retains the inspected six partitions and open fitted outlet")
	var top_contacts:=0;var bearings:=0;var original_contacts:=0
	for ux: float in [.1,.5,.9]:
		for uz: float in [.1,.5,.9]:
			var x:=lerpf(cap[0],cap[2],ux);var z:=lerpf(cap[1],cap[3],uz)
			var y: float=manifest.retained_cap_top+manifest.bearing_toe+manifest.roof_fall*(cap[2]-x)+manifest.sheet_thickness
			for seam_x: float in manifest.seam_recipe.x:
				if absf(x-seam_x)<=manifest.seam_recipe.half_width:y+=manifest.seam_recipe.extra_height;break
			var point:=Vector3(x,y,z)
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(point+Vector3.UP*.05),root.to_global(point-Vector3.UP*.12),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.get_parent()==model and root.to_local(hit.position).distance_to(point)<.00005,"native sloped roof first contact follows its exact construction fall")
			top_contacts+=1
			query.exclude=weather_bodies;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and str(root.get_path_to(hit.collider)).begins_with("RoofBulkheadCaps/") and absf(root.to_local(hit.position).y-manifest.retained_cap_top)<.00005,"excluding weather assembly reproduces retained original flat cap")
			original_contacts+=1
	for height: float in manifest.leader_wall_plates:
		var contact:=Vector3(cap[2],height,manifest.outlet_z)
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(contact+Vector3.RIGHT*.02),root.to_global(contact-Vector3.RIGHT*.07),1,weather_bodies)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and str(root.get_path_to(hit.collider)).begins_with("ROOF_SERVICE_CORE/Wall") and root.to_local(hit.position).distance_to(contact)<.00005,"actual leader strap plate seats on retained service wall")
		bearings+=1
	# These probes use actual imported triangles and physics, rather than the
	# source's named gutter/leader identities. Its outlet crown must not dam the bowl.
	var bore_at:=Vector3(manifest.gutter_x,manifest.retained_cap_top-1.2,manifest.outlet_z)
	for direction: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var distance:=_mesh_distance(native,bore_at,direction)
		check(is_finite(distance) and absf(distance-manifest.leader_bore_radius)<.00005,"actual leader retains its open 76.2 mm bore")
	var fluid:=Vector3(manifest.gutter_x,manifest.gutter_low_y-manifest.gutter_radius+manifest.gutter_wall+.004,manifest.outlet_z)
	check(not is_finite(_mesh_distance(native,fluid,Vector3.DOWN)),"native gutter floor drains into the continuous open leader")
	var outlet_query:=PhysicsRayQueryParameters3D.create(root.to_global(fluid),root.to_global(Vector3(fluid.x,root.level_y.ROOF-.01,fluid.z)),1,[world.player.get_rid()])
	var outlet_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(outlet_query)
	check(not outlet_hit.is_empty() and str(root.get_path_to(outlet_hit.collider)).begins_with("RoofBaseFlashings/") and absf(root.to_local(outlet_hit.position).y-root.level_y.ROOF-.0012)<.00005,"real open outlet discharges onto the fitted base flashing foot")
	var outlet_exclude: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in root.get_node("RoofBaseFlashings").find_children("*","CollisionObject3D",true,false):outlet_exclude.append(body.get_rid())
	outlet_query.exclude=outlet_exclude
	outlet_hit=world.get_world_3d().direct_space_state.intersect_ray(outlet_query)
	check(not outlet_hit.is_empty() and str(root.get_path_to(outlet_hit.collider)).begins_with("ROOF_DECK_EAST/Floor") and absf(root.to_local(outlet_hit.position).y-root.level_y.ROOF)<.00005,"flashing foot retains the original unfinished main roof field below")
	for z_fraction: float in [.2,.5,.8]:
		var z:=lerpf(manifest.gutter_z[0],manifest.outlet_z,z_fraction)
		var centre_y: float=manifest.gutter_low_y+manifest.gutter_fall*absf(z-manifest.outlet_z)
		var at:=Vector3(manifest.gutter_x,centre_y-.03,z)
		var distance:=_mesh_distance(native,at,Vector3.DOWN)
		check(is_finite(distance) and absf(distance-(manifest.gutter_radius-manifest.gutter_wall-.03))<.00005,"actual gutter bowl follows its fall toward the outlet")
	var camera: Camera3D=world.player.camera;camera.make_current();camera.fov=65
	var observations: Array[Dictionary]=[]
	for view: Array in [["service_sheet_roof_elevated",Vector3(14.4,24.3,11.4),Vector3(11.35,22.45,5.25)],
		["service_gutter_outlet_elevated",Vector3(14.1,22.95,10.9),Vector3(manifest.gutter_x,22.33,manifest.outlet_z)],
		["service_leader_from_roof",Vector3(14.4,20.61,9.3),Vector3(manifest.gutter_x,21.2,manifest.outlet_z)],
		["service_outlet_close_diagnostic",Vector3(manifest.gutter_x+.18,manifest.gutter_low_y+.22,manifest.outlet_z+.18),Vector3(manifest.gutter_x,manifest.gutter_low_y-.045,manifest.outlet_z)],
		["service_roof_from_deck",Vector3(8.2,20.61,3),Vector3(11.35,22.4,5.25)]]:
		world.player.global_position=root.to_global(view[1])-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(root.to_global(view[2]));camera.basis=camera.basis.orthonormalized()
		world.player._hand.basis=world.player._hand.basis.orthonormalized()
		world.player.set_lamp_enabled(true);await _settled_optics();await shot(str(view[0]))
		observations.append({"view":str(view[0]),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"rendered_objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"rendered_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("inspection.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","parts":parts,"triangles":triangles,"checks":checks,"failures":failures,"roof_contacts":top_contacts,"retained_cap_contacts":original_contacts,"wall_bearings":bearings,"startup_ms":world.startup_ms,"render_observations":observations,"note":"Production service-roof assembly. Elevated diagnostic cameras; no ledger, hydraulic capacity, whole-shell weather or downstream drainage acceptance. Render counters are observations, not frame-rate verdicts."},"\t")+"\n");file.close()
	print("INERT ROOF SERVICE WEATHERING: parts=%d triangles=%d roof_contacts=%d wall_bearings=%d checks=%d failures=%d" % [parts,triangles,top_contacts,bearings,checks,failures.size()])
	for failure: String in failures:print("ROOF SERVICE WEATHERING FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
