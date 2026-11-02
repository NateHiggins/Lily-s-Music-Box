extends RefCounted
## Installed passive context checks and one posed view, never played access proof.
func run(world: OrisonV2RuntimeRoot, suite: Node, camera: Camera3D) -> void:
	var horizon := world.get_node("CityShells/CityHorizon") as Node3D
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
	suite.check(horizon != null and horizon.global_transform.is_equal_approx(world.adapter.root.global_transform), "distant city uses the actual retained building/grade frame")
	if horizon == null: return
	var expected_parts: Dictionary = {}
	var expected_lower: Dictionary = {}
	for asset: Dictionary in source.assets.values():
		var role := str(asset.get("role", ""))
		suite.check(role in ["base", "body_lod"], "known native inventory role")
		for part: Dictionary in asset.parts:
			var roster: Dictionary = expected_lower if role == "body_lod" else expected_parts
			suite.check(not roster.has(str(part.name)), "unique native part within its inventory role")
			roster[str(part.name)] = part
		suite.check(FileAccess.get_sha256("res://"+str(asset.asset).trim_prefix("game/"))==str(asset.sha256), "installed distant city asset matches current native export")
	var bodies: Dictionary = {}
	var materials: Dictionary = {}
	var parts := 0
	var seen: Dictionary = {}
	var lower_seen := 0
	var expected_hands: Dictionary = {}
	for face: Dictionary in source.get("clock_faces",[]):
		for kind: String in ["hour","minute"]:
			expected_hands[str(face.id)+"_"+kind+"_hand"]={"building":str(face.building),"part":"south_"+kind+"_hand"}
	var hands_seen: Dictionary = {}
	var hand_stock: Node3D = null
	if not expected_hands.is_empty(): hand_stock=preload("res://assets/props/arcade_clock.glb").instantiate()
	for draw: MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
		var identity := str(draw.name)
		if draw.get_meta("city_clock_hand",false):
			suite.check(expected_hands.has(identity) and not hands_seen.has(identity),"unique generated moving clock hand: "+identity)
			hands_seen[identity]=true
			if expected_hands.has(identity) and hand_stock!=null:
				var spec: Dictionary=expected_hands[identity]
				suite.check(str(draw.get_meta("city_clock_building",""))==str(spec.building) and str(draw.get_meta("city_clock_source_part",""))==str(spec.part),"clock hand retains generated owner and native identity")
				var original:=hand_stock.find_child(str(spec.part),true,false) as MeshInstance3D
				suite.check(original!=null,"moving hand has actual native source")
				if original!=null:
					var native:=original.mesh.surface_get_arrays(0);var actual:=draw.mesh.surface_get_arrays(0)
					for channel: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:suite.check(native[channel]==actual[channel],"composed moving hand preserves native physical arrays")
				suite.check(draw.get_node_or_null("HorizonCollision")==null and not draw.has_meta("v2_city_horizon_body_lod"),"moving hands are presentation, not static collision or body replacements")
		else:
			parts += 1
			suite.check(expected_parts.has(identity) and not seen.has(identity), "installed base part retains unique source identity: " + identity)
			seen[identity] = true
			var lower_installed := bool(draw.get_meta("v2_city_horizon_body_lod", false))
			suite.check(lower_installed == expected_lower.has(identity), "complete-body replacement remains attached to its base draw: " + identity)
			if lower_installed: lower_seen += 1
			var body := draw.get_node_or_null("HorizonCollision") as StaticBody3D
			suite.check(body!=null and body.get_child_count()==1,"static distant stock retains its actual collision body: "+identity)
			if body==null or body.get_child_count()!=1:continue
			var shape := body.get_child(0) as CollisionShape3D
			var physical := shape.shape as ConcavePolygonShape3D
			suite.check(physical!=null and physical.get_faces()==preload("res://scripts/building/orison_v2_native_faces.gd").read(draw.mesh) and shape.global_transform.is_equal_approx(draw.global_transform), "distant stock has identical actual visible and physical faces: "+str(draw.name))
			bodies[body.get_rid()] = draw
		var loaded: Material = draw.get_meta("v2_city_roof_source", draw.material_override)
		if draw.has_meta("v2_window_source_material"):
			suite.check(preload("res://scripts/building/v2_background_window_material.gd").glazing_is_bound(draw), "distant optical glazing retains original PBR maps and physical chart scale")
			loaded = draw.get_meta("v2_window_source_material")
		var stock: StandardMaterial3D = loaded.get_meta("v2_weather_source", loaded) as StandardMaterial3D if loaded != null else null
		suite.check(stock!=null and stock.normal_enabled and not stock.uv1_triplanar, "distant stock samples authored charts and enabled normal maps")
		if draw.get_meta("city_clock_hand",false) and stock!=null:suite.check(stock.uv1_scale.is_equal_approx(Vector3.ONE*9.),"composed native hand retains physical material scale")
		if stock != null and not materials.has(stock.get_instance_id()):
			materials[stock.get_instance_id()] = true
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				suite.check(texture!=null and texture.get_image().has_mipmaps(), "distant custom PBR has an actual loaded mip chain")
	if hand_stock!=null:hand_stock.free()
	suite.check(hands_seen.size()==expected_hands.size(),"complete generated moving-hand inventory is separate from static body stock")
	suite.check(parts==expected_parts.size() and seen.size()==expected_parts.size(), "complete installed distant base inventory")
	suite.check(lower_seen==expected_lower.size(), "complete replacement inventory is integrated without duplicate scene draws")
	var stations: Dictionary = {}
	for row: Dictionary in source.window_rows:
		# New authored bays carry their true normals, including angled returns;
		# a legacy cardinal side is neither required nor a valid substitute.
		var n: Array = row.get("normal", [])
		var valid_normal := n.size()==3
		if valid_normal: valid_normal = Vector3(n[0], n[1], n[2]).is_normalized()
		suite.check(valid_normal, "distant pane station carries an authored unit normal")
		if not valid_normal: continue
		var key := "%s/%.6f/%.6f/%.6f" % [str(row.building), n[0], n[1], n[2]]
		if not stations.has(key) or float(row.point[2])>float(stations[key].point[2]):stations[key]=row
	var probes: Array=stations.values()
	var affected_panes:=0
	if not expected_hands.is_empty():
		for row: Dictionary in source.window_rows:
			if str(row.building) in ["HORIZON_NEAR_3_0_P0R2","HORIZON_NEAR_3_0_P2"]:
				probes.append(row);affected_panes+=1
		suite.check(affected_panes==237,"all237 panes in both corrected neighbor bodies included, covering the75 new witnesses")
	for row: Dictionary in probes:
		var p: Array = row.point
		var n: Array = row.normal
		var point := horizon.to_global(Vector3(p[0],p[2],-p[1]))
		var normal := horizon.global_basis*Vector3(n[0],n[2],-n[1])
		var expected := point-normal*float(row.recess_m)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.03,point-normal*.25,1,[world.player.get_rid()]))
		var draw: MeshInstance3D = bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
		suite.check(draw!=null and str(draw.get_meta("v2_city_horizon_building"))==str(row.building) and str(draw.name).ends_with("__mirror_aged") and hit.position.distance_to(expected)<.0001, "actual composed recessed distant pane: "+str(row.building)+"/"+str(row.normal))
	var eyes: Array[Vector3] = [camera.global_position]
	var city_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	for view: Dictionary in city_source.skyline_views_godot:
		var p: Array = view.at
		eyes.append(world.adapter.root.to_global(Vector3(p[0],float(p[1])+1.6,p[2])))
	var excluded: Array[RID]=[world.player.get_rid()]
	var view := preload("res://tests/v2_city_context_review.gd").capture_station(world.get_world_3d().direct_space_state,horizon,stations.values(),bodies,eyes,excluded)
	var found := not view.is_empty()
	if found:
		camera.global_position=view.eye
		camera.look_at(view.target)
		await suite.get_tree().create_timer(.6).timeout
		await suite.shot("city_horizon_context")
		print("CITY HORIZON CAMERA: retained_pose=",view.retained_camera," source_building=",view.building,"; posed context only, no played access")
	suite.check(found, "distant context capture has an actual clear first-hit pane sightline")
	print("CITY HORIZON REVIEW: %d buildings; %d static parts; %d moving hands; %d facade stations plus %d affected neighbor panes; clear_capture=%s" % [source.buildings.size(),parts,hands_seen.size(),stations.size(),affected_panes,found])
