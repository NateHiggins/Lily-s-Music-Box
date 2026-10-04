extends "res://tests/orison_v2_roof_membrane_test.gd"
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"actual city starts with original mast-head beacon housings")
	if world.startup_failed:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var city: Node3D=world.get_node("CityShells")
	var model: Node3D=city.get_node("RooftopBeacons")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_beacons.json"))
	check(FileAccess.get_sha256("res://assets/props/city_beacons.glb")==fixture.asset_sha256,"installed original beacons bind the native export")
	check(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json").replace("\r\n","\n").sha256_text()==fixture.source_bindings["game/data/orison_v2_blockout.json"],"current geometry registration binds the current blockout")
	var parts:=0;var triangles:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;triangles+=draw.mesh.get_faces().size()/3
		_check_cap_mapping(draw.mesh,true)
		var key:=str(draw.name).split("__")[-1]
		var material:=draw.material_override as StandardMaterial3D
		check(material!=null and material.albedo_texture!=null and material.roughness_texture!=null and material.normal_texture!=null and not material.uv1_triplanar,"all original beacons receive existing catalogue maps with native metre charts")
		check(material!=MatLib.get_mat(key) and MatLib.get_mat(key).uv1_triplanar,"each local native chart preserves its shared catalogue projection")
		check(material.albedo_texture==MatLib.get_mat(key).albedo_texture and material.roughness_texture==MatLib.get_mat(key).roughness_texture and material.normal_texture==MatLib.get_mat(key).normal_texture,"installed local finish uses all three exact catalogue maps")
		check(draw.get_node("BeaconCollision/Surface").shape is ConcavePolygonShape3D,"visible beacon partition has native triangle collision")
		var shape: CollisionShape3D=draw.get_node("BeaconCollision/Surface")
		var physical_mesh:=shape.shape as ConcavePolygonShape3D
		check(physical_mesh!=null and physical_mesh.get_faces()==draw.mesh.get_faces(),"every installed beacon triangle has identical physical backing")
		check(shape.global_transform.is_equal_approx(draw.global_transform),"beacon collision and visible triangles share the actual world pose")
		var size: Vector3=draw.mesh.get_aabb().size
		check(size.x<4.0001 and size.y<4.0001 and size.z<4.0001,"actual partition stays in its four metre cell")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"actual imported counts bind source inventory")
	check(MatLib.get_mat("metal").uv1_triplanar,"shared metal cache projection is unchanged")
	var old_ids: Dictionary={};var all_ids: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		all_ids.append(body.get_rid())
		if city.get_node("RooftopMasts").is_ancestor_of(body):old_ids[body.get_rid()]=true
	var exclude: Array[RID]=[]
	for rid: RID in all_ids:
		if not old_ids.has(rid):exclude.append(rid)
	var bad_supports:=0
	var footprint_checks:=0
	var source_records: Dictionary={}
	for record: Dictionary in fixture.original_records:source_records[record.id]=record
	for contact: Dictionary in fixture.contacts:
		var n: Vector3=city.global_basis*Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
		for sample: Array in [contact.point]+contact.footprint:
			var p: Vector3=city.to_global(Vector3(sample[0],sample[2],-sample[1]))
			# The actual renderer/physics diagnostic misses narrow cap triangles
			# with 3 mm segments. Both longer brackets must meet the same exact
			# bearing requirement; neither the target nor tolerance is changed.
			for reach: float in [.01,.03]:
				var query:=PhysicsRayQueryParameters3D.create(p+n*reach,p-n*reach,1,exclude)
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or not old_ids.has(hit.collider.get_rid()) or hit.position.distance_to(p)>=.0001:
					if bad_supports<8:print("CITY BEACON SUPPORT DIAGNOSTIC: ",contact.id," reach=",reach," point=",p," normal=",n," hit=",hit.get("collider")," distance=",hit.position.distance_to(p) if not hit.is_empty() else INF," old_bodies=",old_ids.size())
					bad_supports+=1
				check(not hit.is_empty() and old_ids.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"actual beacon footprint bears on the original mast head under both query brackets")
			footprint_checks+=1
	for beacon: Dictionary in fixture.beacons:
		var base:=city.to_global(Vector3(beacon.base[0],beacon.base[2],-beacon.base[1]))
		check(float(beacon.foot_radius)<float(beacon.original_mast_radius),"housing pedestal footprint stays within the original mast head")
		check(absf(float(beacon.height)-.22)<.00000001 and absf(float(beacon.radius)-.13)<.00000001,"housing retains the original bounding envelope")
		var offset: Array=fixture.capture_offsets_godot.head
		world.player.global_position=base+Vector3(offset[0],offset[1],offset[2])-Vector3.UP*world.player.STANDING_EYE
		world.player.face_world_point(base+Vector3.UP*.1);world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(beacon.id)+"_head")
		if beacon==fixture.beacons[0] or beacon==fixture.beacons[-1]:
			offset=fixture.capture_offsets_godot.mast
			world.player.global_position=base+Vector3(offset[0],offset[1],offset[2])-Vector3.UP*world.player.STANDING_EYE
			world.player.face_world_point(base-Vector3.UP*.7)
			await _settled_optics();await shot(str(beacon.id)+"_mast")
	var root: Node3D=world.adapter.root
	for view: Dictionary in fixture.skyline_views_godot:
		var at: Array=view.at;var target: Array=view.target
		world.player.global_position=root.to_global(Vector3(at[0],at[1],at[2]));world.player.face_world_point(root.to_global(Vector3(target[0],target[1],target[2])));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id);var after:=_visible_counts()
		model.hide();await _settled_optics();await shot(view.id+"_before");var before:=_visible_counts();model.show()
		print("CITY BEACON OBSERVATION: ",view.id," before=",before," after=",after)
	print("CITY BEACONS: checks=",checks," parts=",parts," triangles=",triangles," supports=",fixture.contacts.size()," bearing_samples=",footprint_checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
