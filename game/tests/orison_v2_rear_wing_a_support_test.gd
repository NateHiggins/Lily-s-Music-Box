extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## Retained source identities, native mapping and actual installed support contacts.
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
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_rear_wing_a_construction.json"));var plan: Dictionary=data.source_plan
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_rear_wing_a_stations.json"))
	check(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n").sha256_text()==data.source_layout_sha256_lf,"frame binds retained layout")
	check(FileAccess.get_sha256("res://assets/props/exterior_masonry.glb")==data.source_masonry_sha256,"frame binds retained native masonry")
	check(fixture.source_layout_sha256_lf==data.source_layout_sha256_lf and fixture.source_masonry_sha256==data.source_masonry_sha256,"frozen negative stations bind the retained source identities")
	check(FileAccess.get_sha256("res://assets/props/rear_wing_a_support.glb")==data.source_native_sha256,"construction metadata binds the actual exported native frame")
	var owner: Node3D=root.get_node("RearWingASupport")
	var native:=PackedVector3Array();var footing_native:=PackedVector3Array();var parts:=0;var triangles:=0
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		var steel:=str(draw.name).begins_with("Steel")
		check(draw.material_override==(MatLib.get_mat("metal",Color(.32,.34,.36)) if steel else MatLib.get_mat("concrete")),"installed part uses the retained mapped catalogue finish")
		_check_planar_mapping(draw.mesh,true);parts+=1;triangles+=draw.mesh.get_faces().size()/3
		var pose:=root.global_transform.affine_inverse()*draw.global_transform;native.append_array(pose*draw.mesh.get_faces())
		var bounds: AABB=pose*draw.mesh.get_aabb();check(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<=4.00001,"true surface clipping bounds each draw")
	footing_native.append_array(native)
	for draw: MeshInstance3D in root.get_node("Foundations").find_children("*","MeshInstance3D",true,false):footing_native.append_array((root.global_transform.affine_inverse()*draw.global_transform)*draw.mesh.get_faces())
	check(parts==data.parts.size() and triangles==int(data.native_triangles),"native export matches the fabricated partitions and triangles")
	await get_tree().physics_frame;await get_tree().physics_frame
	var old: Array[RID]=[world.player.get_rid()];var masonry_exclude: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):old.append(body.get_rid())
	for body: CollisionObject3D in root.get_node("ExteriorMasonry").find_children("*","CollisionObject3D",true,false):masonry_exclude.append(body.get_rid())
	var contacts:=0;var reproduced:=0
	for station: Dictionary in fixture.stations:
		for p: Array in station.points:
			var point:=Vector3(p[0],p[1],p[2]);var start:=point+Vector3.UP*.05
			var distance:=_mesh_distance(native,start,Vector3.DOWN);check(is_finite(distance) and absf(distance-.05)<.00003,"native beam reaches the original outer wall base")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(start),root.to_global(point-Vector3.UP*.25),1,masonry_exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(point)<.00003,"actual frame is the first matching wall-base support")
			contacts+=1;query.exclude=masonry_exclude+old;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			var missing: bool=hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.0001
			check(missing,"excluding only the frame reproduces the old support gap")
			if missing:reproduced+=1
	var conflicts: Array=[]
	for record: Dictionary in plan.components:
		var b: Array=record.bounds;var box:=AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3]-b[0],b[4]-b[1],b[5]-b[2])).grow(-.00003)
		var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=box.size;query.shape=shape;query.transform=Transform3D(root.global_basis,root.to_global(box.get_center()));query.collision_mask=1;query.exclude=old
		for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,64):conflicts.append([record.id,str(world.get_path_to(hit.collider))])
	check(conflicts.is_empty(),"native component volumes preserve retained walls, equipment and risers: "+str(conflicts))
	var bases:=0;var pads:=0;var wall_seats:=0;var heads:=0
	for col: Dictionary in plan.columns:
		var c: Array=col.center;var point:=Vector3(c[0],c[1],c[2])
		for off: Vector2 in [Vector2(-.075,-.075),Vector2(.075,-.075),Vector2(-.075,.075),Vector2(.075,.075)]:
			var p:=point+Vector3(off.x,0,off.y);var native_base:=_mesh_distance(native,p-Vector3.UP*.04,Vector3.UP)
			check(is_finite(native_base) and absf(native_base-.04)<.00003,"native post base matches its actual seat datum")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(p+Vector3.UP*.1),root.to_global(p-Vector3.UP*.5),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and root.to_local(hit.position).distance_to(p)<.00003,"post base contacts new pedestal, edge band or retained storage roof")
			bases+=1
			if col.base_owner=="storage_edge":
				p.y-=.2;query.from=root.to_global(p+Vector3.UP*.05);query.to=root.to_global(p-Vector3.UP*.25);query.exclude=old;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and root.to_local(hit.position).distance_to(p)<.00003,"edge band's true underside seats on retained basement masonry");wall_seats+=1
		if col.base_owner=="external":
			for off: Vector2 in [Vector2(-.25,-.25),Vector2(.25,-.25),Vector2(-.25,.25),Vector2(.25,.25)]:
				var p:=point+Vector3(off.x,-3.4,off.y);var distance:=_mesh_distance(footing_native,p+Vector3.UP*.1,Vector3.DOWN)
				check(is_finite(distance) and absf(distance-.1)<.00003,"new or retained native pad reaches the pedestal footing datum")
				var query:=PhysicsRayQueryParameters3D.create(root.to_global(p+Vector3.UP*.1),root.to_global(p-Vector3.UP*.3),1,[world.player.get_rid()]);var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and root.to_local(hit.position).distance_to(p)<.00003,"actual independent footing reaches its source datum");pads+=1
	for record: Dictionary in plan.components:
		if not str(record.id).contains("AnchorHead"):continue
		var b: Array=record.bounds;var p:=Vector3((b[0]+b[3])*.5,b[4],(b[2]+b[5])*.5)
		var distance:=_mesh_distance(native,p+Vector3.UP*.01,Vector3.DOWN);check(is_finite(distance) and absf(distance-.01)<.00003,"native anchor has a clear exposed upper face")
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(p+Vector3.UP*.1),root.to_global(p-Vector3.UP*.1),1,[world.player.get_rid()]);var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(p)<.00003,"exposed anchor has matching live collision");heads+=1
	check(contacts==60 and reproduced==60 and bases==36 and pads==20 and wall_seats==8 and heads==36,"all original samples and fitted construction interfaces checked")
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["a_north",Vector3(-14,1.524,13.8),Vector3(-13,2.7,11.7)],
		["a_west",Vector3(-17.2,1.524,8.6),Vector3(-15.7,2.7,8.6)],
		["a_court",Vector3(-8,1.524,9.5),Vector3(-10.15,2.7,8.9)],
		["a_storage_edge",Vector3(-11.2,.7,9.5),Vector3(-10.145,.12,9.1)],
		["a_bath_seat",Vector3(-8,1.524,6.6),Vector3(-6.575,2.7,5.755)],
		["a_floor",Vector3(-12.7,4.724,8.6),Vector3(-11,4.4,8.6)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE;world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
		var with_frame:=_render_counts()
		owner.hide()
		for _frame in 3:await RenderingServer.frame_post_draw
		var without_frame:=_render_counts()
		owner.show()
		for _frame in 3:await RenderingServer.frame_post_draw
		print("A FRAME VIEW OBSERVATION: ",view[0]," with_frame=",with_frame," frame_hidden=",without_frame)
	print("A REAR WING SUPPORT: parts=%d triangles=%d contacts=%d reproduced=%d bases=%d pads=%d wall_seats=%d heads=%d conflicts=%d checks=%d failures=%d" % [parts,triangles,contacts,reproduced,bases,pads,wall_seats,heads,conflicts.size(),checks,failures.size()])
	for failure: String in failures:print("A REAR WING SUPPORT FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _render_counts() -> Dictionary:
	var viewport:=get_viewport().get_viewport_rid()
	return {"draw_calls":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}
