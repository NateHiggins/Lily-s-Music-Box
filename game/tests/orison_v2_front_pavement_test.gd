extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## INERT installed public-floor ownership check against retained real owners.
var batch_mode := false
var capture_enabled := true
func _ready() -> void:
	if not batch_mode:call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"production world initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var source_report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_front_pavement_construction.json"))
	var reviewed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_front_pavement_review.json"))
	check(FileAccess.get_file_as_string("res://tests/fixtures/orison_front_pavement_construction.json").replace("\r\n","\n").sha256_text()==str(reviewed.original_fixture_sha256),"original construction fixture remains unchanged")
	for relative: String in source_report.source_bindings:
		if not relative.begins_with("game/"):continue
		var path: String="res://"+relative.trim_prefix("game/")
		var expected: String=str(source_report.source_bindings[relative])
		if relative in ["game/data/orison_v2_blockout.json","game/data/orison_v2/world_connection.json"]:expected=str(reviewed.source_bindings[relative])
		check(FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()==expected,"installed paving binds original or explicitly compared source: "+relative)
	check(FileAccess.get_sha256("res://assets/props/front_pavement.glb")==source_report.asset_sha256,"construction metadata binds the actual native asset")
	var envelope: Array=source_report.envelope;var y: Array=source_report.y
	var old_bounds:=AABB(Vector3(envelope[0],y[0],envelope[1]),Vector3(envelope[2]-envelope[0],y[1]-y[0],envelope[3]-envelope[1]))
	var owner: Node3D=root.get_node("FrontPavement")
	var street: Node3D=world.exterior_cell.instance_node("STREET_ORISON_01")
	for draw: MeshInstance3D in street.find_children("*","MeshInstance3D",true,false):check(str(draw.get_meta("authored_record_id",""))!="pavement_slab","the composed street contains no duplicate original slab draw")
	for shape: CollisionShape3D in street.find_children("*","CollisionShape3D",true,false):check(str(shape.get_meta("authored_record_id",""))!="pavement_slab","the composed street contains no duplicate original slab shape")
	var native:=PackedVector3Array();var parts:=0;var triangles:=0;var surface_contacts:=0
	await get_tree().physics_frame;await get_tree().physics_frame
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		_check_planar_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bounds: AABB=pose*draw.mesh.get_aabb()
		check(maxf(bounds.size.x,bounds.size.z)<=4.00001,"fitted street paving retains bounded export parts")
		var faces: PackedVector3Array=pose*draw.mesh.get_faces();native.append_array(faces)
		for index in range(0,faces.size(),3):
			var a:=faces[index];var b:=faces[index+1];var c:=faces[index+2]
			if absf(a.y)>.00003 or absf(b.y)>.00003 or absf(c.y)>.00003:continue
			if (b-a).cross(c-a).length()<.0002:continue
			var at: Vector3=(a+b+c)/3.
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.05),root.to_global(at-Vector3.UP*.05),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			var matched: bool=not hit.is_empty() and hit.collider.get_parent()==draw and root.to_local(hit.position).distance_to(at)<.00003
			if not matched:print("PAVEMENT FOREGROUND: ",at," expected=",draw.name," actual=",str(world.get_path_to(hit.collider)) if not hit.is_empty() else "none"," at=",root.to_local(hit.position) if not hit.is_empty() else Vector3.INF)
			check(matched,"actual first floor contact belongs to the new paving mesh")
			if matched:surface_contacts+=1
	var expected_triangles:=0
	for part: Dictionary in source_report.parts:expected_triangles+=int(part.quads)*2
	check(parts==source_report.parts.size() and triangles==expected_triangles,"fitted pavement imports all native parts and faces")
	var duplicate_pairs:=0;var retained_contacts:=0;var fixture_foregrounds:=0;var floor_records: Array=[]
	for identity: String in ["F01_D_BED","F01_D_BATH","F01_A_BATH","F01_A_BED","F01_A_STUDY"]:
		var record: Dictionary={}
		for space: Dictionary in root.layout.spaces:
			if str(space.id)==identity:record=space
		var floor_body:=root.get_node(identity+"/Floor/Collision")
		for shape: CollisionShape3D in floor_body.find_children("*","CollisionShape3D",true,false):
			var size: Vector3=shape.shape.size;var actual: AABB=(root.global_transform.affine_inverse()*shape.global_transform)*AABB(-size*.5,size)
			var overlap:=actual.intersection(old_bounds)
			check(overlap.size.x>.00003 and overlap.size.y>.00003 and absf(overlap.size.z-.7)<.00003,"original sidewalk reproduces the 700 mm room-floor overlap")
			duplicate_pairs+=1
		for fraction: float in [.2,.5,.8]:
			var rect: Array=record.rect;var at:=Vector3(lerpf(rect[0],rect[2],fraction),0,-12)
			var distance:=_mesh_distance(native,at+Vector3.UP*.05,Vector3.DOWN)
			check(not is_finite(distance),"new native pavement has no face beneath the retained room floor")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.05),root.to_global(at-Vector3.UP*.3),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.collider!=floor_body:print("ROOM FLOOR FOREGROUND: ",identity," ",at," actual=",str(world.get_path_to(hit.collider)) if not hit.is_empty() else "none"," at=",root.to_local(hit.position) if not hit.is_empty() else Vector3.INF)
			var first_owner: String=str(world.get_path_to(hit.collider)) if not hit.is_empty() else ""
			var first_y: float=root.to_local(hit.position).y if not hit.is_empty() else INF
			if first_owner in ["OrisonV2Blockout/F01_1D_SHOWER_01/FixtureBody","OrisonV2Blockout/F01_1A_SHOWER_01/FixtureBody"]:
				check(absf(first_y-.019)<.00003,"unchanged shower tray is the actual qualified foreground")
				var qualified_exclude:=query.exclude;qualified_exclude.append(hit.collider.get_rid());query.exclude=qualified_exclude
				hit=world.get_world_3d().direct_space_state.intersect_ray(query)
				fixture_foregrounds+=1
			check(not hit.is_empty() and hit.collider==floor_body and absf(root.to_local(hit.position).y)<.00003,"retained room keeps sole actual floor ownership")
			floor_records.append({"owner":identity,"point":[at.x,at.y,at.z],"first_owner":first_owner,"first_y":first_y,"floor_owner":str(world.get_path_to(hit.collider)) if not hit.is_empty() else ""})
			retained_contacts+=1
	check(duplicate_pairs==5 and retained_contacts==15 and fixture_foregrounds==2 and surface_contacts>150,"native paving resolves all five observed floor overlaps with two retained shower foregrounds")
	var observations: Array=[]
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["front_threshold",Vector3(0,1.524,-14.2),Vector3(0,.1,-11.65)],
		["west_bed_front",Vector3(-13,1.524,-14.2),Vector3(-13,0,-12.65)],
		["west_front_oblique",Vector3(-17,1.524,-14.6),Vector3(-13,0,-12.65)],
		["east_bath_front",Vector3(14.2,1.524,-14.2),Vector3(14.2,0,-12.65)],
		["alley_street_join",Vector3(16.8,1.524,-13.8),Vector3(16.8,0,-11.65)]]:
		if not capture_enabled:break
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
		var shown:=_pavement_render_stats()
		owner.hide();await _settled_optics()
		var hidden:=_pavement_render_stats()
		owner.show();await _settled_optics()
		observations.append({"view":view[0],"shown":shown,"hidden":hidden,"note":"Matched stationary main viewport observation; hiding leaves collision active. No timing or capacity verdict."})
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file:=FileAccess.open(directory.path_join("pavement-inspection.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"INERT","parts":parts,"triangles":triangles,"original_duplicate_pairs":duplicate_pairs,"retained_room_floor_contacts":retained_contacts,"retained_shower_foregrounds":fixture_foregrounds,"room_floor_stations":floor_records,"new_surface_contacts":surface_contacts,"render_observations":observations,"checks":checks,"failures":failures,"note":"Installed slab ownership check. Drainage and whole-shell readiness remain open."},"\t")+"\n");file.close()
	print("INERT FRONT PAVEMENT NATIVE: parts=%d triangles=%d old_duplicates=%d room_contacts=%d new_contacts=%d checks=%d failures=%d" % [parts,triangles,duplicate_pairs,retained_contacts,surface_contacts,checks,failures.size()])
	for failure: String in failures:print("FRONT PAVEMENT FAIL: ",failure)
	camera.free();world.player.camera.make_current()
	return {"checks":checks,"failures":failures,"parts":parts,"triangles":triangles,"surface_contacts":surface_contacts,"room_floor_stations":floor_records}

func _pavement_render_stats() -> Dictionary:
	var viewport:=get_viewport().get_viewport_rid()
	return {"draw_calls":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
