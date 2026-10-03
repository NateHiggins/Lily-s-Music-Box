extends "res://tests/orison_v2_ventilation_fabric_test.gd"
## Source-bound earlier bearing stations, actual native contact and retained basement volumes.
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
	var owner: Node3D=root.get_node("Foundations")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_foundation_stations.json"))
	var layout_text:=FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n")
	check(layout_text.sha256_text()==data.source_layout_sha256_lf,"earlier discovery binds to the retained layout bytes")
	check(FileAccess.get_sha256("res://assets/props/exterior_masonry.glb")==data.source_masonry_sha256,"earlier discovery binds to the retained native masonry")
	var native:=PackedVector3Array();var parts:=0;var triangles:=0
	for draw: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		check(draw.mesh is ArrayMesh,"foundation uses actual native triangles")
		check(draw.material_override==MatLib.get_mat("concrete"),"foundation uses existing concrete")
		_check_mapping(draw.mesh,true)
		var pose:=root.global_transform.affine_inverse()*draw.global_transform
		var bounds: AABB=pose*draw.mesh.get_aabb()
		check(maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<=4.00001,"native foundation pieces are bounded")
		native.append_array(pose*draw.mesh.get_faces())
	await get_tree().physics_frame;await get_tree().physics_frame
	check(parts==74 and triangles==8444,"foundation exports each union triangle once")
	var masonry_exclude: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in root.get_node("ExteriorMasonry").find_children("*","CollisionObject3D",true,false):masonry_exclude.append(body.get_rid())
	var trial_exclude: Array[RID]=masonry_exclude.duplicate()
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):trial_exclude.append(body.get_rid())
	var closed:=0;var new_contacts:=0;var reproduced:=0
	for station: Dictionary in data.stations:
		var complete:=true
		for sample: Dictionary in station.samples:
			if bool(sample.original_covered):continue
			var p: Array=sample.point;var point:=Vector3(p[0],p[1],p[2]);var ray:=point+Vector3.UP*.05
			var distance:=_mesh_distance(native,ray,Vector3.DOWN)
			if not is_finite(distance) or absf(distance-.05)>.00003:complete=false;continue
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(ray),root.to_global(point-Vector3.UP*.1),1,masonry_exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.get_parent()==owner and root.to_local(hit.position).distance_to(point)<.00003,"new stem reaches the original deficient ground wall-base sample")
			new_contacts+=1
			query.exclude=trial_exclude;hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(hit.is_empty() or absf(root.to_local(hit.position).y-point.y)>.0001,"excluding only the foundation reproduces the missing source wall-base seat")
			reproduced+=1
		if complete:closed+=1
	check(closed==61,"foundation closes the 61 original exterior foundation stations without filling the basement")
	var isolated_exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not owner.is_ancestor_of(body):isolated_exclude.append(body.get_rid())
	var source_bounds: Array=data.basement_bounds
	var footing_contacts:=0
	var footing_top: float=root.level_y["B1"]-root.layout.dimensions.slab_thickness
	for record: Dictionary in source_bounds:
		var r: Array=record.bounds
		check(absf(r[1]-footing_top)<.00001,"earlier basement profile uses the retained floor datum")
		var axis:=0 if r[3]-r[0]>r[5]-r[2] else 2
		var count:=maxi(1,int(ceilf((r[axis+3]-r[axis])/1.5)))
		for i in count:
			var point:=Vector3((r[0]+r[3])*.5,footing_top,(r[2]+r[5])*.5)
			point[axis]=lerpf(r[axis],r[axis+3],(i+.5)/count)
			var ray:=point+Vector3.UP*.05
			var distance:=_mesh_distance(native,ray,Vector3.DOWN)
			check(is_finite(distance) and absf(distance-.05)<.00003,"native footing reaches the original basement masonry base")
			var query:=PhysicsRayQueryParameters3D.create(root.to_global(ray),root.to_global(point-Vector3.UP*.08),1,isolated_exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.get_parent()==owner and root.to_local(hit.position).distance_to(point)<.00003,"named foundation collision matches its native footing contact; other structural owners are separately excluded")
			footing_contacts+=1
	var penetrations:=0;var masks:=0
	for room: Dictionary in root.layout.spaces:
		if str(room.level)!="B1":continue
		var r: Array=room.rect
		var mask:=AABB(Vector3(r[0]+.08,-3.15,r[1]+.08),Vector3(r[2]-r[0]-.16,2.9,r[3]-r[1]-.16))
		for i in range(0,native.size(),3):
			var a:=native[i];var b:=native[i+1];var c:=native[i+2]
			var lo:=Vector3(minf(a.x,minf(b.x,c.x)),minf(a.y,minf(b.y,c.y)),minf(a.z,minf(b.z,c.z)))
			var hi:=Vector3(maxf(a.x,maxf(b.x,c.x)),maxf(a.y,maxf(b.y,c.y)),maxf(a.z,maxf(b.z,c.z)))
			if lo.x>=mask.end.x or hi.x<=mask.position.x or lo.y>=mask.end.y or hi.y<=mask.position.y or lo.z>=mask.end.z or hi.z<=mask.position.z:continue
			penetrations+=1
		masks+=1
	check(penetrations==0,"actual native surfaces preserve every occupied basement volume")
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view: Array in [["west_foundation",Vector3(-16.2,-1.1,-5),Vector3(-15.75,-.5,-5)],
		["front_foundation",Vector3(-7,-1.1,-14),Vector3(-7,-.5,-12.35)],
		["west_footing",Vector3(-17,-3.05,-6),Vector3(-15.8,-3.4,-5)],
		["rear_setback",Vector3(-7,1.524,14),Vector3(-7,3.5,10.2)]]:
		camera.global_position=root.to_global(view[1]);camera.look_at(root.to_global(view[2]))
		world.player.global_position=camera.global_position-Vector3.UP*world.player.STANDING_EYE
		world.player.camera.global_transform=camera.global_transform;world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0]))
	print("ORISON FOUNDATIONS: parts=%d triangles=%d closed_stations=%d new_contacts=%d reproduced=%d footing_contacts=%d basement_masks=%d penetrations=%d checks=%d failures=%d" % [parts,triangles,closed,new_contacts,reproduced,footing_contacts,masks,penetrations,checks,failures.size()])
	for failure: String in failures:print("FOUNDATION FAIL: ",failure)
	print("FOUNDATION OBSERVATION: startup_ms=%.3f visible_draws=%d visible_primitives=%d; one diagnostic view, not performance acceptance" % [world.startup_ms,get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)])
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
