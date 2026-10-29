extends "res://tests/v2_front_restoration_review.gd"
## Street-start fixture, real collision-bearing walking, and loaded stock review.
## This does not claim a lobby-to-street route or whole-building acceptance.

func run(current: OrisonV2RuntimeRoot, suite: Node) -> void:
	world=current;host=suite;player=world.player
	var prior_position := player.global_position
	var prior_rotation := player.rotation
	var prior_camera := player.camera.rotation
	var prior_physics := player.is_physics_processing()
	var boundary := world.get_node("StreetBoundaries")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(boundary.SOURCE))
	var native := boundary.get_node("NativeConstructionStock") as Node3D
	host.check(native.position.is_equal_approx(Vector3(22.25,0,0)),"native shed keeps its source-frame export origin")
	for row: Dictionary in source.boxes:
		var body := boundary.get_node(str(row.id)) as StaticBody3D
		host.check(body!=null and body.position.is_equal_approx(Vector3(row.center[0],row.center[1],row.center[2])),"shed retains collision actor position: "+str(row.id))
		var shapes := body.find_children("*","CollisionShape3D",true,false)
		host.check(shapes.size()==1 and (shapes[0].shape as BoxShape3D).size.is_equal_approx(Vector3(row.size[0],row.size[1],row.size[2])),"shed retains collision envelope: "+str(row.id))
		host.check(is_equal_approx(body.rotation_degrees.z,float(row.get("roll_degrees",0))),"shed retains actor roll: "+str(row.id))
		host.check(body.find_children("*","MeshInstance3D",true,false).is_empty(),"shed retires old box draw: "+str(row.id))
	for row: Dictionary in source.lights:
		var light := boundary.get_node(str(row.id)) as LightFixtureProp
		host.check(light.position.is_equal_approx(Vector3(row.center[0],row.center[1],row.center[2])),"shed retains work lamp: "+str(row.id))
	host.check(boundary.get_node_or_null("ShedTemporaryClosure") == null and boundary.find_children("ContractorClosureNotice","Label3D",true,false).is_empty(),"retired closure and its misleading notice stay out of the open scaffold")
	var draws := native.find_children("*","MeshInstance3D",true,false)
	host.check(draws.size()==5,"open scaffold renders five shared native catalogue partitions")
	for draw: MeshInstance3D in draws:
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_active_material(surface) as StandardMaterial3D
			var key := str(material.get_meta("v2_surface_stock",""))
			host.check(not key.is_empty() and not material.uv1_triplanar and material.normal_enabled,"native shed uses authored UV and PBR: "+key)
			if key.begins_with("site_softwood"):
				host.check(not material.texture_repeat and material.uv1_scale.is_equal_approx(Vector3.ONE) and is_equal_approx(material.normal_scale,1.),"mirrored timber retains clamp, metre scale and calibrated normal: "+key)
				for texture: Texture2D in [material.albedo_texture,material.normal_texture,material.roughness_texture]:
					host.check(texture.get_image().has_mipmaps(),"new timber has a real loaded mip chain: "+texture.resource_path)
	# Fixture arrival is explicit. Every subsequent point uses the normal
	# controller, collision mask and locomotion inputs, with no noclip.
	player.global_position=Vector3(19.5,.025,3)
	player.velocity=Vector3.ZERO;player.set_physics_process(true)
	player.set_lamp_enabled(false)
	for point in [Vector3(21.5,0,3),Vector3(24,0,3),Vector3(24,0,0),Vector3(24,0,-2.1),Vector3(24,0,-4)]:
		if not await _walk(world.adapter.root.to_local(point)):break
	# Retain the failed probes as actual collider controls. The first ended
	# inside the player; the old diagonal also entered the retained shop.
	var legacy := PhysicsRayQueryParameters3D.create(Vector3(24,1.2,-2.1),Vector3(24,1.2,-4))
	var legacy_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(legacy)
	host.check(not legacy_hit.is_empty() and legacy_hit.collider==player,"unfiltered former-closure probe hits the player, not a closure")
	var legacy_player_path: String=str(legacy_hit.collider.get_path()) if not legacy_hit.is_empty() else "empty"
	var query := PhysicsRayQueryParameters3D.create(Vector3(24,1.2,-2.1),Vector3(24,1.2,-4),1,[player.get_rid()])
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
	host.check(hit.is_empty(),"former temporary closure now admits the real player route")
	legacy=PhysicsRayQueryParameters3D.create(Vector3(24,1.5,-2),Vector3(19,1.5,3),1,[player.get_rid()])
	legacy_hit=world.get_world_3d().direct_space_state.intersect_ray(legacy)
	host.check(not legacy_hit.is_empty(),"old diagonal remains occluded by retained world geometry")
	var legacy_diagonal_path: String=str(legacy_hit.collider.get_path()) if not legacy_hit.is_empty() else "empty"
	# This sightline still crosses both former hoarding footprints, while its
	# end stays outside the shop. Production collision and player masks stay on.
	query=PhysicsRayQueryParameters3D.create(Vector3(24,1.5,-2),Vector3(21,1.5,3),1,[player.get_rid()])
	host.check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"retired inner hoarding no longer closes the street view")
	var probe_controls: Dictionary={"legacy_player_hit":legacy_player_path,"legacy_diagonal_hit":legacy_diagonal_path,"corrected_world_mask":1,"shop_clear_endpoint":[21,1.5,3]}
	print("CONSTRUCTION PROBE CONTROLS: ",probe_controls)
	for point in [Vector3(24,0,0),Vector3(24,0,3),Vector3(21.5,0,3),Vector3(19.5,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)):break
	player.set_physics_process(false)
	for station in [["approach",Vector3(19.5,1.65,3.1),Vector3(24,1.8,1)],
		["framing",Vector3(24,1.7,2.8),Vector3(24,2.6,-.2)],
		["closure",Vector3(23.9,1.6,-1.7),Vector3(24,1.5,-3)],
		["joinery",Vector3(24.6,2.2,-.1),Vector3(25.27,2.6,-.55)]]:
		player.global_position=station[1]-Vector3.UP*1.524
		player.face_world_point(station[2])
		for carried in [false,true]:
			player.set_lamp_enabled(carried)
			await host.get_tree().create_timer(.3).timeout
			await _capture("construction_"+str(station[0])+("_carried" if carried else "_diffuse"),world.adapter.root.to_local(station[1]),world.adapter.root.to_local(station[2]))
	player.set_lamp_enabled(false)
	var directory := OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("construction_route_trace.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","fixture":"Street arrival at (19.5,0.025,3); capture stances are camera fixtures; no lobby route claim.","waypoints":trace,"probe_controls":probe_controls},"\t"))
	player.global_position=prior_position;player.rotation=prior_rotation;player.camera.rotation=prior_camera
	player.velocity=Vector3.ZERO;player.set_physics_process(prior_physics)
