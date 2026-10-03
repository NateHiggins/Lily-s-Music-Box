extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## Source-bound original gaps, native frame, live collision and retained landing contacts.
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
	var owner: Node3D=root.get_node("GroundCoreTransfer")
	var native:=PackedVector3Array();var parts:=0;var triangles:=0;var steel_draws:=0
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		var key: String="metal" if str(draw.name).begins_with("Steel") else "concrete"
		if key=="metal":steel_draws+=1
		check(draw.material_override==MatLib.get_mat("metal",preload("res://scripts/building/orison_v2_ground_core_transfer.gd").STEEL_TINT) if key=="metal" else draw.material_override==MatLib.get_mat("concrete"),"installed source family keeps its mapped material")
		print("TRANSFER MATERIAL: ",draw.name," ",key);_check_planar_mapping(draw.mesh,true)
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		var pose:=root.global_transform.affine_inverse()*draw.global_transform;native.append_array(pose*draw.mesh.get_faces())
		var bounds: AABB=pose*draw.mesh.get_aabb()
		check(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<=4.00001,"native partitions remain bounded")
	await get_tree().physics_frame;await get_tree().physics_frame
	var construction: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_ground_transfer_stations.json"))
	var isolated: Array[RID]=[];var old: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if owner.is_ancestor_of(body):old.append(body.get_rid())
		else:isolated.append(body.get_rid())
	var masonry_exclude: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in root.get_node("ExteriorMasonry").find_children("*","CollisionObject3D",true,false):masonry_exclude.append(body.get_rid())
	var contacts:=0;var reproduced:=0
	check(parts==3 and triangles==1884 and steel_draws==1,"three native partitions include one mapped steel assembly")
	check(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n").sha256_text()==construction.source_layout_sha256_lf,"original discovery binds to retained source layout")
	check(FileAccess.get_sha256("res://assets/props/exterior_masonry.glb")==construction.source_masonry_sha256,"original discovery binds to retained native masonry")
	for station: Dictionary in construction.stations:
		check(str(station.source).begins_with("F01_"),"earlier ground wall witness remains explicit")
		for p: Array in station.points:
			var point:=Vector3(p[0],p[1],p[2]);var start:=point+Vector3.UP*.05
			var distance:=_mesh_distance(native,start,Vector3.DOWN)
			check(is_finite(distance) and absf(distance-.05)<.00003,"native beam reaches the deficient wall-base sample")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(start),root.to_global(point-Vector3.UP*.1),1,masonry_exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(point)<.00003,"new beam is matching physical wall-base support")
			contacts+=1
			query.exclude=masonry_exclude+old;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			var missing: bool=hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.0001
			check(missing,"excluding only new structure reproduces the old wall-base gap")
			if missing:reproduced+=1
	var conflicts: Array=[]
	for record: Dictionary in construction.components:
		var b: Array=record.bounds;var box:=AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3]-b[0],b[4]-b[1],b[5]-b[2])).grow(-.00003)
		var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=box.size;query.shape=shape;query.transform=Transform3D(root.global_basis,root.to_global(box.get_center()));query.collision_mask=1;query.exclude=old
		for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,64):
			conflicts.append([record.id,str(world.get_path_to(hit.collider))])
	check(conflicts.is_empty(),"new true plate/web/pad components have no positive existing collision overlap: "+str(conflicts))
	var heads:=0
	for record: Dictionary in construction.components:
		if not str(record.id).contains("AnchorHead"):continue
		var b: Array=record.bounds;var point:=Vector3((b[0]+b[3])*.5,b[4],(b[2]+b[5])*.5)
		var distance:=_mesh_distance(native,point+Vector3.UP*.01,Vector3.DOWN)
		check(is_finite(distance) and absf(distance-.01)<.00003,"anchor head has a clear native upper face outside the column flanges")
		# A 30 mm segment times this 15 mm triangle's area falls below Godot
		# Physics' determinant parallel threshold. Use a 200 mm segment while
		# keeping the same first-hit owner and 30 micron contact requirement.
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(point+Vector3.UP*.1),root.to_global(point-Vector3.UP*.1),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and owner.is_ancestor_of(hit.collider) and root.to_local(hit.position).distance_to(point)<.00003,"exposed anchor head has matching live collision")
		heads+=1
	check(heads==8,"all eight plate anchor heads remain exposed")
	var bases:=0;var pads:=0
	for col: Dictionary in construction.columns:
		var c: Array=col.center;var point:=Vector3(c[0],c[1],c[2])
		for off: Vector2 in [Vector2(-.075,-.075),Vector2(.075,-.075),Vector2(-.075,.075),Vector2(.075,.075)]:
			var at:=point+Vector3(off.x,0,off.y)
			var native_base:=_mesh_distance(native,at-Vector3.UP*.04,Vector3.UP)
			check(is_finite(native_base) and absf(native_base-.04)<.00003,"native base underside matches retained landing datum")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(at+Vector3.UP*.04),root.to_global(at-Vector3.UP*.05),1,old)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and str(root.get_path_to(hit.collider)).begins_with(str(col.floor_owner)+"/") and root.to_local(hit.position).distance_to(at)<.00003,"column base contacts the retained source landing")
			bases+=1
			at.y-=.2;query.from=root.to_global(at+Vector3.UP*.04);query.to=root.to_global(at-Vector3.UP*.05);query.exclude=isolated
			var native_pad:=_mesh_distance(native,at+Vector3.UP*.04,Vector3.DOWN)
			check(is_finite(native_pad) and absf(native_pad-.04)<.00003,"native footing reaches the retained landing bottom")
			hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			# Existing foundation may own a portion of a supplemental pad footprint.
			if hit.is_empty():
				query.exclude=old;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and root.to_local(hit.position).distance_to(at)<.00003,"retained landing bottom contacts new or existing footing")
			pads+=1
	check(contacts==12 and reproduced==12 and bases==8 and pads==8,"all original stations and retained footing interfaces checked")
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["transfer_below",Vector3(.1,-1.676,1.7),Vector3(-1.45,-.45,1.2)],
		["south_base",Vector3(-.1,-1.676,1.7),Vector3(-1.175,-2.9,.69)],
		["north_base",Vector3(-.2,-1.676,2.1),Vector3(-1.305,-2.9,3.64)],
		["watch_seat",Vector3(-1.65,-.9,1.2),Vector3(-1.9,-.2,.725)],
		["anchor_heads",Vector3(-.8,-2.6,1.1),Vector3(-1.175,-3.16,.69)],
		["pad_below",Vector3(-1.9,-3.9,.69),Vector3(-1.175,-3.65,.69)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE;world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
	print("GROUND CORE TRANSFER: parts=%d triangles=%d contacts=%d reproduced=%d bases=%d pads=%d conflicts=%d checks=%d failures=%d" % [parts,triangles,contacts,reproduced,bases,pads,conflicts.size(),checks,failures.size()])
	for failure: String in failures:print("GROUND CORE TRANSFER FAIL: ",failure)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
