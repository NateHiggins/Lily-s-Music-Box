extends "res://tests/orison_v2_roof_membrane_test.gd"
## Actual retained bearings, original light authority and clear capture stations.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	var bar: OrisonV2BarRegion=world.bar_region
	check(bar!=null and not world.startup_failed and not bar.startup_failed,"retained independent bar composes with native fixture mounts")
	if bar==null or world.startup_failed or bar.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var cell: Node3D=bar.get_node("RetainedBarGeometry");var model: Node3D=cell.get_node("BarFixtureMounts")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_fixture_mounts.json"))
	check(FileAccess.get_sha256("res://assets/props/bar_fixture_mounts.glb")==fixture.asset_sha256,"installed mounts bind the native export")
	var transferred: bool=world.adapter.root.has_meta("v2_native_fixed_lighting_factory")
	var expected_parts: Array=fixture.parts.filter(func(p):return not transferred or str(p.name).begins_with("CanopyStay"))
	var expected_triangles:=0
	for part: Dictionary in expected_parts:expected_triangles+=int(part.triangles)
	var parts:=0;var triangles:=0;var exclude: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):exclude.append(body.get_rid())
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
		var identity:=str(draw.get_meta("bar_fixture_mount_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==identity)[0]
		check(count==int(expected.triangles),"native partition retains its triangle count: "+identity)
		_check_cap_mapping(draw.mesh,true)
		var material:=draw.mesh.surface_get_material(0) as StandardMaterial3D;var library:=MatLib.get_mat(str(expected.key))
		check(material!=null and material!=library and library.uv1_triplanar and not material.uv1_triplanar,"local metre chart leaves shared library policy intact: "+identity)
		check(material.albedo_texture==library.albedo_texture and material.roughness_texture==library.roughness_texture and material.normal_texture==library.normal_texture,"three unchanged catalogue maps reach the mount: "+identity)
		check(material.metallic==library.metallic and material.roughness==library.roughness and material.normal_scale==library.normal_scale,"mount retains the catalogue optical calibration: "+identity)
		var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native collision agrees with visible faces: "+identity)
	check(parts==expected_parts.size() and triangles==expected_triangles,"all native mounts have one physical owner")
	var count:=0;var sconces:=0
	for marker: Dictionary in fixture.original_markers:
		var actor:=bar.actors.get_node(str(marker.id)) as LightFixtureProp;count+=1
		check(actor!=null and actor.prop_type==str(marker.kind) and actor.position.distance_to(GameBoot.b2g(marker.pos))<.000001,"original light identity, kind and anchor remain: "+str(marker.id))
		check(actor.range_clamp==float(marker.get("range",0.0)) and actor.energy_scale==float(marker.get("energy",1.0)) and actor.standby_scale==float(marker.get("standby",0.0)) and actor.navigation_light==bool(marker.get("navigation",false)),"original authored lighting settings remain: "+str(marker.id))
		var yaw_sign:=1. if str(marker.kind)=="sconce_globe" else -1.
		check(absf(angle_difference(actor.rotation.y,deg_to_rad(float(marker.yaw_deg)*yaw_sign)))<.000001,"fixture orientation fits its original fabric: "+str(marker.id))
		if str(marker.kind)=="sconce_globe":
			sconces+=1;var front:=actor.basis*Vector3.FORWARD*-1.
			check((front.x<-.99) if float(marker.pos[0])>0. else (front.x>.99),"sconce globe faces inward from its supporting wall: "+str(marker.id))
	check(count==18 and sconces==5,"all eighteen original lights retained; five wall orientations fitted")
	var bearing_samples:=0;var span_samples:=0
	for contact: Dictionary in fixture.contacts:
		# Complete native fixtures now own their mounts; this family retains canopy stays.
		if transferred and not str(contact.id).begins_with("CanopyStay"):continue
		var at:=_v(contact.bearing);var direction:=_v(contact.direction)
		var owner: MeshInstance3D
		for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
			if str(draw.name).trim_suffix("-col")==str(contact.owner).trim_suffix("-col"):owner=draw
		check(owner!=null,"original fabric bearing exists: "+str(contact.id))
		if owner==null:continue
		var faces:=PackedVector3Array()
		for point: Vector3 in owner.mesh.get_faces():faces.append(owner.transform*point)
		var seed:=Vector3.RIGHT if absf(direction.y)>.9 else Vector3.UP;var other:=direction.cross(seed)
		var points: Array[Vector3]=[]
		if contact.has("inline_source"):
			points.append(at)
			for i in 8:points.append(at+float(contact.bearing_radius_m)*.8*(seed*cos(i*TAU/8.)+other*sin(i*TAU/8.)))
		else:
			for u: float in [-.044,-.022,0.,.022,.044]:
				for v: float in [-.044,-.022,0.,.022,.044]:points.append(at+seed*u+other*v)
		for point: Vector3 in points:
			var distance:=_mesh_distance(faces,point-direction*.004,direction)
			if not is_finite(distance) or absf(distance-.004)>=.00003:print("BEARING DETAIL: ",contact.id," point=",point," distance=",distance," owner=",owner.name)
			check(is_finite(distance) and absf(distance-.004)<.00003,"actual retained face seats the entire bearing: "+str(contact.id));bearing_samples+=1
		if str(contact.id).contains("DECK") or str(contact.id).contains("WEST"):
			var fixture_actor:=bar.actors.get_node(str(contact.id)) as LightFixtureProp
			var rear:=_v(contact.get("original_fixture_endpoint",contact.fixture_endpoint));var fixture_faces:=PackedVector3Array()
			for draw: MeshInstance3D in fixture_actor.find_children("*","MeshInstance3D",true,false):
				for vertex: Vector3 in draw.mesh.get_faces():fixture_faces.append(bar.to_local(draw.to_global(vertex)))
			var rear_distance:=_mesh_distance(fixture_faces,rear+direction*.004,-direction)
			check(is_finite(rear_distance) and absf(rear_distance-.004)<.00003,"actual original sconce back plate meets its fitted bracket: "+str(contact.id))
		var routes: Array=[[_v(contact.fixture_endpoint),at]]
		if contact.has("free_offset_riser"):routes.append([_v(contact.free_offset_riser[0]),_v(contact.free_offset_riser[1])])
		for route: Array in routes:
			var start: Vector3=route[0];var end: Vector3=route[1];var forward: Vector3=(end-start).normalized()
			var side:=Vector3.RIGHT if absf(forward.y)>.9 else Vector3.UP;var across:=forward.cross(side)
			for offset: Vector3 in [Vector3.ZERO,side*.006,-side*.006,across*.006,-across*.006]:
				var query:=PhysicsRayQueryParameters3D.create(cell.to_global(start+forward*.014+offset),cell.to_global(end-forward*.016+offset),1,exclude)
				check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"fitted stem clears retained physical fabric: "+str(contact.id));span_samples+=1
	for retained: Dictionary in fixture.retained_rods:
		var source: Array=bar.source_layout.floors.filter(func(row):return row.id=="F01")[0].furniture.filter(func(row):return row.id==retained.rod.id)
		check(source.size()==1 and source[0]==retained.rod,"already connected original suspension rod remains byte-identical")
	await _mount_views(world,bar,model)
	print("BAR FIXTURE MOUNTS: checks=",checks," parts=",parts," triangles=",triangles," lights=",count," sconces=",sconces," bearing_samples=",bearing_samples," span_samples=",span_samples," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _mount_views(world: OrisonV2RuntimeRoot, bar: Node3D, model: Node3D) -> void:
	var views: Array=[
		["pool",Vector3(-7.4,-2.775,33.25),Vector3(-7.4,-.28,31.25)],
		["canopy",Vector3(-5.5,-2.775,32.0),Vector3(-2.,-.45,29.7)],
		["west_gallery",Vector3(-9.3,-2.775,35.4),Vector3(-11.4,-.5,35.4)],
		["west_scoreboard",Vector3(-9.4,-2.775,31.3),Vector3(-11.4,-.5,31.3)],
		["well",Vector3(-3.8,-2.775,33.5),Vector3(-2.6,1.64,33.4)],
		["stage",Vector3(-3.5,-2.775,35.85),Vector3(-.7,-.4,36.55)],
		["stair",Vector3(4.8,-2.775,34.55),Vector3(5.3,1.8,32.6)]]
	for view: Array in views:
		var feet:=bar.to_global(view[1]);var shape:=CapsuleShape3D.new();shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
		var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=shape;capsule.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*shape.height*.5);capsule.collision_mask=1;capsule.exclude=[world.player.get_rid()]
		var clear:=world.get_world_3d().direct_space_state.intersect_shape(capsule,1).is_empty()
		check(clear,"ordinary standing capture clears mounted fabric: "+str(view[0]))
		if not clear:continue
		var floor_query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.02,feet-Vector3.UP*.15,1,[world.player.get_rid()])
		var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(floor_query)
		check(not floor_hit.is_empty() and bar.get_node("RetainedBarGeometry").is_ancestor_of(floor_hit.collider),"standing capture has retained floor support: "+str(view[0]))
		if floor_hit.is_empty():continue
		world.player.global_position=feet;world.player.face_world_point(bar.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0])+"_fitted")
		if world.adapter.root.has_meta("v2_native_fixed_lighting_factory"):continue
		model.hide()
		for actor: LightFixtureProp in bar.actors.find_children("*","LightFixtureProp",true,false):
			if actor.prop_type=="sconce_globe":actor.rotation.y=-actor.rotation.y
		await _settled_optics();await shot(str(view[0])+"_original")
		for actor: LightFixtureProp in bar.actors.find_children("*","LightFixtureProp",true,false):
			if actor.prop_type=="sconce_globe":actor.rotation.y=-actor.rotation.y
		model.show()
