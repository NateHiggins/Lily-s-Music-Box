extends "res://tests/orison_v2_roof_membrane_test.gd"
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"actual city starts with fitted original tanks")
	if world.startup_failed:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var city: Node3D=world.get_node("CityShells")
	var model: Node3D=city.get_node("RooftopTanks")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_tanks.json"))
	check(FileAccess.get_sha256("res://assets/props/city_tanks.glb")==fixture.asset_sha256,"installed original tanks bind the native export")
	check(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n").sha256_text()==fixture.source_bindings["game/data/orison_v2_blockout.json"],"current geometry registration binds the current blockout")
	var parts:=0;var triangles:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		_check_cap_mapping(draw.mesh,true)
		var key:=str(draw.name).split("__")[-1]
		var material:=draw.material_override as StandardMaterial3D
		check(material!=null and material.albedo_texture!=null and material.roughness_texture!=null and material.normal_texture!=null and not material.uv1_triplanar,"all original tanks receive existing catalogue maps with native metre charts")
		check(material!=MatLib.get_mat(key) and MatLib.get_mat(key).uv1_triplanar,"each local native chart preserves its shared catalogue projection")
		check(draw.get_node("TankCollision/Surface").shape is ConcavePolygonShape3D,"visible tank partition has native triangle collision")
		var shape: CollisionShape3D=draw.get_node("TankCollision/Surface")
		var physical_mesh:=shape.shape as ConcavePolygonShape3D
		check(physical_mesh!=null and physical_mesh.get_faces()==draw.mesh.get_faces(),"every installed tank triangle has identical physical backing")
		check(shape.global_transform.is_equal_approx(draw.global_transform),"tank collision and visible triangles share the actual world pose")
		var size: Vector3=draw.mesh.get_aabb().size
		check(size.x<4.0001 and size.y<4.0001 and size.z<4.0001,"actual partition stays in its four metre cell")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"actual imported counts bind source inventory")
	check(MatLib.get_mat("metal").uv1_triplanar,"shared metal cache projection is unchanged")
	var old_ids: Dictionary={};var all_ids: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		all_ids.append(body.get_rid())
		if city.is_ancestor_of(body) and body.get_meta("retained_city_shell",false):old_ids[body.get_rid()]=true
	var exclude: Array[RID]=[]
	for rid: RID in all_ids:
		if not old_ids.has(rid):exclude.append(rid)
	var bad_supports:=0
	var footprint_checks:=0
	var span_checks:=0
	var source_records: Dictionary={}
	for record: Dictionary in fixture.original_records:source_records[record.id]=record
	for contact: Dictionary in fixture.contacts:
		var n: Vector3=city.global_basis*Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
		for sample: Array in [contact.point]+contact.footprint:
			var p: Vector3=city.to_global(Vector3(sample[0],sample[2],-sample[1]))
			var query:=PhysicsRayQueryParameters3D.create(p+n*.003,p-n*.003,1,exclude)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or not old_ids.has(hit.collider.get_rid()) or hit.position.distance_to(p)>=.0001:
				if bad_supports<8:print("CITY TANK SUPPORT DIAGNOSTIC: ",contact.id," point=",p," normal=",n," hit=",hit.get("collider")," distance=",hit.position.distance_to(p) if not hit.is_empty() else INF," old_bodies=",old_ids.size())
				bad_supports+=1
			footprint_checks+=1
			check(not hit.is_empty() and old_ids.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"actual tank support plate centre and corners bear on original registered city geometry")
	for span: Dictionary in fixture.clear_spans:
		var high:=city.to_global(Vector3(span.high[0],span.high[2],-span.high[1]))
		var low:=city.to_global(Vector3(span.low[0],span.low[2],-span.low[1]))
		var direction: Vector3=(low-high).normalized()
		var query:=PhysicsRayQueryParameters3D.create(high,low-direction*.001,1,exclude)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(hit.is_empty(),"installed tank span clears original city solids")
		span_checks+=1
	for tank: Dictionary in fixture.tanks:
		var bottom:=city.to_global(Vector3(tank.bottom[0],tank.bottom[2],-tank.bottom[1]))
		var top:=city.to_global(Vector3(tank.top[0],tank.top[2],-tank.top[1]))
		check(float(tank.fitted_cap_radius)>float(tank.radius) and float(tank.original_cap_radius)<float(tank.radius),"fitted weather cap closes the undersized original proxy above the retained barrel")
		check(float(tank.wall_thickness)>.0 and float(tank.skirt_top)>float(tank.top[2]),"closed barrel and weather skirt retain positive construction thickness")
		world.player.global_position=bottom+Vector3(7,2.3,8)-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(bottom+Vector3.UP*.1);world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(tank.id)+"_assembly")
		if tank==fixture.tanks[0] or tank==fixture.tanks[-1]:
			world.player.global_position=top+Vector3(2.5,1,3)-Vector3.UP*world.player.STANDING_EYE
			world.player.face_world_point(top-Vector3.UP*.4)
			await _settled_optics();await shot(str(tank.id)+"_cap")
	for contact: Dictionary in [fixture.contacts[0],fixture.contacts[-1]]:
		var at:=city.to_global(Vector3(contact.point[0],contact.point[2],-contact.point[1]))
		world.player.global_position=at+Vector3(.65,.45,.75)-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(at+Vector3.UP*.10)
		await _settled_optics();await shot(str(contact.id)+"_foot")
	var root: Node3D=world.adapter.root
	for view: Array in [["west_roof",Vector3(14,19.2,-7.5),Vector3(26.4,26,-8)],
		["north_roof",Vector3(0,19.2,10.5),Vector3(15,30,20)],
		["east_roof",Vector3(-14,19.2,-7.5),Vector3(-26.5,30,-8)],
		["street_skyline",Vector3(-6,0,-13.8),Vector3(28,22,-2)]]:
		world.player.global_position=root.to_global(view[1]);world.player.face_world_point(root.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0]);var after:=_visible_counts()
		model.hide();await _settled_optics();await shot(view[0]+"_before");var before:=_visible_counts();model.show()
		print("CITY TANK OBSERVATION: ",view[0]," before=",before," after=",after)
	print("CITY TANKS: checks=",checks," parts=",parts," triangles=",triangles," supports=",fixture.contacts.size()," bearing_samples=",footprint_checks," clear_spans=",span_checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
