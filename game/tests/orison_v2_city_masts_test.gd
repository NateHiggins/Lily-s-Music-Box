extends "res://tests/orison_v2_roof_membrane_test.gd"
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"actual city starts with fitted original aerials")
	if world.startup_failed:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var city: Node3D=world.get_node("CityShells")
	var model: Node3D=city.get_node("RooftopMasts")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_masts.json"))
	check(FileAccess.get_sha256("res://assets/props/city_masts.glb")==fixture.asset_sha256,"installed original masts bind the native export")
	check(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n").sha256_text()==fixture.source_bindings["game/data/orison_v2_blockout.json"],"current geometry registration binds the current blockout")
	var parts:=0;var triangles:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		_check_cap_mapping(draw.mesh,true)
		var material:=draw.material_override as StandardMaterial3D
		check(material!=null and material.albedo_texture!=null and material.roughness_texture!=null and material.normal_texture!=null and not material.uv1_triplanar,"all original aerials receive existing metal maps with native metre charts")
		check(draw.get_node("MastCollision/Surface").shape is ConcavePolygonShape3D,"visible aerial partition has native triangle collision")
		var shape: CollisionShape3D=draw.get_node("MastCollision/Surface")
		var physical_mesh:=shape.shape as ConcavePolygonShape3D
		check(physical_mesh!=null and physical_mesh.get_faces()==draw.mesh.get_faces(),"every installed mast triangle has identical physical backing")
		check(shape.global_transform.is_equal_approx(draw.global_transform),"mast collision and visible triangles share the actual world pose")
		var size: Vector3=draw.mesh.get_aabb().size
		check(size.x<4.0001 and size.y<4.0001 and size.z<4.0001,"actual partition stays in its four metre cell")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"actual imported counts bind source inventory")
	check(MatLib.get_mat("metal").uv1_triplanar,"shared metal cache projection is unchanged")
	var old_ids: Dictionary={};var all_ids: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		all_ids.append(body.get_rid())
		if city.is_ancestor_of(body) and not model.is_ancestor_of(body):old_ids[body.get_rid()]=true
	var exclude: Array[RID]=[]
	for rid: RID in all_ids:
		if not old_ids.has(rid):exclude.append(rid)
	var bad_supports:=0
	var footprint_checks:=0
	var wire_checks:=0
	var source_records: Dictionary={}
	for record: Dictionary in fixture.original_records:source_records[record.id]=record
	for contact: Dictionary in fixture.contacts:
		var n: Vector3=city.global_basis*Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
		for sample: Array in [contact.point]+contact.footprint:
			var p: Vector3=city.to_global(Vector3(sample[0],sample[2],-sample[1]))
			var query:=PhysicsRayQueryParameters3D.create(p+n*.003,p-n*.003,1,exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or not old_ids.has(hit.collider.get_rid()) or hit.position.distance_to(p)>=.0001:
				if bad_supports<8:print("CITY MAST SUPPORT DIAGNOSTIC: ",contact.id," point=",p," normal=",n," hit=",hit.get("collider")," distance=",hit.position.distance_to(p) if not hit.is_empty() else INF," old_bodies=",old_ids.size())
				bad_supports+=1
			footprint_checks+=1
			check(not hit.is_empty() and old_ids.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"actual mast or guy plate centre and corners bear on original registered city geometry")
		if contact.role=="guy_anchor":
			var record: Dictionary=source_records[contact.id]
			var high:=city.to_global(Vector3(record.p0[0]+record.registration_offset_x,record.p0[2],-record.p0[1]))
			var low:=city.to_global(Vector3(contact.fitted_endpoint[0],contact.fitted_endpoint[2],-contact.fitted_endpoint[1]))
			var direction: Vector3=(low-high).normalized()
			var query:=PhysicsRayQueryParameters3D.create(high,low-direction*.001,1,exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(hit.is_empty(),"installed guy span clears retained city solids between its mast and supported anchor")
			wire_checks+=1
	var root: Node3D=world.adapter.root
	for view: Array in [["west_roof",Vector3(14,19.2,-7.5),Vector3(26.4,26,-8)],
		["north_roof",Vector3(0,19.2,10.5),Vector3(15,30,20)],
		["east_roof",Vector3(-14,19.2,-7.5),Vector3(-26.5,30,-8)],
		["street_skyline",Vector3(-6,0,-13.8),Vector3(28,22,-2)]]:
		world.player.global_position=root.to_global(view[1]);world.player.face_world_point(root.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0]);var after:=_visible_counts()
		model.hide();await _settled_optics();await shot(view[0]+"_before");var before:=_visible_counts();model.show()
		print("CITY MAST OBSERVATION: ",view[0]," before=",before," after=",after)
	print("CITY MASTS: checks=",checks," parts=",parts," triangles=",triangles," supports=",fixture.contacts.size()," bearing_samples=",footprint_checks," wire_spans=",wire_checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
