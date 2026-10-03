extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## INERT installed native fitting; source fabric retains its geometry and owner.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(world.player!=null and not world.startup_failed,"installed world initializes")
	if world.player==null:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var root: Node3D=world.adapter.root
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_first_upper_hall_construction.json"));var plan: Dictionary=data.source_plan
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_first_upper_hall_stations.json"))
	check(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n").sha256_text()==data.source_layout_sha256_lf,"installed asset binds retained layout")
	check(FileAccess.get_sha256("res://assets/props/exterior_masonry.glb")==data.source_masonry_sha256,"installed asset binds retained native masonry")
	check(fixture.source_layout_sha256_lf==data.source_layout_sha256_lf and fixture.source_masonry_sha256==data.source_masonry_sha256,"original negatives bind retained sources")
	check(FileAccess.get_sha256("res://assets/props/first_upper_hall_seats.glb")==data.source_native_sha256,"metadata binds actual native export")
	var owner: Node3D=root.get_node("FirstUpperHallSeats")
	var native:=PackedVector3Array();var parts:=0;var triangles:=0
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		check(draw.material_override==MatLib.get_mat("metal",Color(.32,.34,.36)),"native part uses mapped catalogue steel")
		_check_planar_mapping(draw.mesh,true);parts+=1;triangles+=draw.mesh.get_faces().size()/3
		var pose:=root.global_transform.affine_inverse()*draw.global_transform;native.append_array(pose*draw.mesh.get_faces())
		var bounds: AABB=pose*draw.mesh.get_aabb();check(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<=4.00001,"true surfaces bound every draw")
	check(parts==data.parts.size() and triangles==int(data.native_triangles),"export matches fabricated native partitions")
	await get_tree().physics_frame;await get_tree().physics_frame
	var old: Array[RID]=[world.player.get_rid()];var masonry_exclude: Array[RID]=[world.player.get_rid()];var only_new: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):old.append(body.get_rid())
	for body: CollisionObject3D in root.get_node("ExteriorMasonry").find_children("*","CollisionObject3D",true,false):masonry_exclude.append(body.get_rid())
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not owner.is_ancestor_of(body):only_new.append(body.get_rid())
	var contacts:=0;var reproduced:=0;var retained:=0
	for station: Dictionary in fixture.stations:
		for sample: Dictionary in station.points:
			if not sample.new_seat:check(not sample.retained_source.is_empty(),"original overlapping masonry footprint retains its source");retained+=1;continue
			var p: Array=sample.point;var point:=Vector3(p[0],p[1],p[2]);var start:=point+Vector3.UP*.05
			var distance:=_mesh_distance(native,start,Vector3.DOWN);check(is_finite(distance) and absf(distance-.05)<.00003,"native top reaches original unsupported sample")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(start),root.to_global(point-Vector3.UP*.25),1,masonry_exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(point)<.00003,"matching live first-hit seat reaches original sample");contacts+=1
			query.exclude=masonry_exclude+old;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			var missing: bool=hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.0001
			check(missing,"excluding only the installed seats reproduces original unsupported sample")
			if missing:reproduced+=1
	var conflicts: Array=[]
	for record: Dictionary in plan.components:
		var b: Array=record.bounds;var box:=AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3]-b[0],b[4]-b[1],b[5]-b[2])).grow(-.00003)
		var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=box.size;query.shape=shape;query.transform=Transform3D(root.global_basis,root.to_global(box.get_center()));query.collision_mask=1;query.exclude=old
		for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,64):conflicts.append([record.id,str(root.get_path_to(hit.collider))])
	check(conflicts.is_empty(),"component bounds preserve existing collision: "+str(conflicts))
	var faces:=0;var heads:=0
	for seat: Dictionary in plan.seats:
		var c: Array=seat.center;var n: Array=seat.normal;var p:=Vector3(c[0],c[1],c[2]);var normal:=Vector3(n[0],n[1],n[2])
		var distance:=_mesh_distance(native,p-normal*.1,normal);check(is_finite(distance) and absf(distance-.1)<.00003,"native bracket back seats on retained wall face")
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(p-normal*.1),root.to_global(p+normal*.1),1,only_new);var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(p)<.00003,"live bracket back matches its native face")
		query.from=root.to_global(p+normal*.15);query.to=root.to_global(p-normal*.15);query.exclude=old;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and root.to_local(hit.position).distance_to(p)<.00003,"unchanged retained wall physically meets bracket back");faces+=1
	for record: Dictionary in plan.components:
		if not str(record.id).ends_with("_Head"):continue
		var normal:=Vector3(0,0,1) if str(record.id).begins_with("WestHall") else (Vector3.RIGHT if str(record.id).contains("_west_") else Vector3.LEFT)
		var b: Array=record.bounds;var p:=Vector3((b[0]+b[3])*.5,(b[1]+b[4])*.5,(b[2]+b[5])*.5)
		if normal.x!=0:p.x=b[3] if normal.x>0 else b[0]
		else:p.z=b[5]
		var distance:=_mesh_distance(native,p+normal*.01,-normal);check(is_finite(distance) and absf(distance-.01)<.00003,"actual native bolt head is exposed beside its gusset")
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(p+normal*.1),root.to_global(p-normal*.1),1,[world.player.get_rid()]);var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(p)<.00003,"exposed bolt head has matching first-hit collision");heads+=1
	check(contacts==15 and reproduced==15 and retained==6 and faces==5 and heads==32,"every targeted interface and preserved source sample checked")
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["east_south",Vector3(6.9,1.524,-3.2),Vector3(5.83,2.72,-4.025)],
		["east_north",Vector3(6.9,1.524,-3.2),Vector3(5.83,2.72,-2.475)],
		["east_bracket",Vector3(6.25,1.524,-3.4),Vector3(5.82,2.68,-4.025)],
		["west_ledger",Vector3(-3.5,1.524,2),Vector3(-3.9,2.98,.875)],
		["west_detail",Vector3(-3.1,1.524,1.35),Vector3(-3.23333,2.85,.875)]]:
		camera.fov=25 if str(view[0]).contains("detail") else (35 if str(view[0]).contains("bracket") else 65)
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE;world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
		var with_frame:=_render_counts();owner.hide()
		for _frame in 3:await RenderingServer.frame_post_draw
		var without_frame:=_render_counts();owner.show()
		for _frame in 3:await RenderingServer.frame_post_draw
		print("HALL SEAT VIEW OBSERVATION: ",view[0]," with_frame=",with_frame," hidden=",without_frame)
	print("INERT FIRST-UPPER HALL NATIVE: parts=%d triangles=%d contacts=%d reproduced=%d retained_source=%d wall_faces=%d heads=%d conflicts=%d checks=%d failures=%d" % [parts,triangles,contacts,reproduced,retained,faces,heads,conflicts.size(),checks,failures.size()])
	for failure: String in failures:print("HALL NATIVE FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _render_counts() -> Dictionary:
	var viewport:=get_viewport().get_viewport_rid()
	return {"draw_calls":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
