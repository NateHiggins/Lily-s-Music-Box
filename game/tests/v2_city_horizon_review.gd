extends RefCounted
## Installed passive context checks and one posed view, never played access proof.
func run(world: OrisonV2RuntimeRoot, suite: Node, camera: Camera3D) -> void:
	var horizon := world.get_node("CityShells/CityHorizon") as Node3D
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
	suite.check(horizon != null and horizon.global_transform.is_equal_approx(world.adapter.root.global_transform), "distant city uses the actual retained building/grade frame")
	if horizon == null: return
	var expected_parts := 0
	for asset: Dictionary in source.assets.values():
		expected_parts += asset.parts.size()
		suite.check(FileAccess.get_sha256("res://"+str(asset.asset).trim_prefix("game/"))==str(asset.sha256), "installed distant city asset matches current native export")
	var bodies: Dictionary = {}
	var materials: Dictionary = {}
	var parts := 0
	for draw: MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
		parts += 1
		var body := draw.get_node("HorizonCollision") as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		var physical := shape.shape as ConcavePolygonShape3D
		suite.check(physical!=null and physical.get_faces()==preload("res://scripts/building/orison_v2_native_faces.gd").read(draw.mesh) and shape.global_transform.is_equal_approx(draw.global_transform), "distant stock has identical actual visible and physical faces: "+str(draw.name))
		bodies[body.get_rid()] = draw
		var stock: StandardMaterial3D = draw.get_meta("v2_city_roof_source", draw.material_override) as StandardMaterial3D
		suite.check(stock!=null and stock.normal_enabled and not stock.uv1_triplanar, "distant stock samples authored charts and enabled normal maps")
		if stock != null and not materials.has(stock.get_instance_id()):
			materials[stock.get_instance_id()] = true
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				suite.check(texture!=null and texture.get_image().has_mipmaps(), "distant custom PBR has an actual loaded mip chain")
	suite.check(parts==expected_parts, "complete installed distant native inventory")
	var stations: Dictionary = {}
	for row: Dictionary in source.window_rows:
		var key := str(row.building)+"/"+str(row.side)
		if not stations.has(key) or float(row.point[2])>float(stations[key].point[2]):stations[key]=row
	for row: Dictionary in stations.values():
		var p: Array = row.point
		var n: Array = row.normal
		var point := horizon.to_global(Vector3(p[0],p[2],-p[1]))
		var normal := horizon.global_basis*Vector3(n[0],n[2],-n[1])
		var expected := point-normal*float(row.recess_m)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.03,point-normal*.25,1,[world.player.get_rid()]))
		var draw: MeshInstance3D = bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
		suite.check(draw!=null and str(draw.get_meta("v2_city_horizon_building"))==str(row.building) and str(draw.name).ends_with("__mirror_aged") and hit.position.distance_to(expected)<.0001, "actual composed recessed distant pane: "+str(row.building)+"/"+str(row.side))
	var eyes: Array[Vector3] = [camera.global_position]
	var city_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	for view: Dictionary in city_source.skyline_views_godot:
		var p: Array = view.at
		eyes.append(world.adapter.root.to_global(Vector3(p[0],float(p[1])+1.6,p[2])))
	var found := false
	for eye: Vector3 in eyes:
		for row: Dictionary in stations.values():
			var p: Array = row.point
			var n: Array = row.normal
			var point := horizon.to_global(Vector3(p[0],p[2],-p[1]))
			var normal := horizon.global_basis*Vector3(n[0],n[2],-n[1])
			var target := point-normal*float(row.recess_m)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target-normal*.04,1,[world.player.get_rid()]))
			if hit.is_empty() or not bodies.has(hit.collider.get_rid()) or hit.position.distance_to(target)>.001:continue
			camera.global_position=eye
			camera.look_at(target)
			await suite.get_tree().create_timer(.6).timeout
			await suite.shot("city_horizon_context")
			found=true
			break
		if found:break
	suite.check(found, "distant context capture has an actual clear first-hit pane sightline")
	print("CITY HORIZON REVIEW: %d buildings; %d parts; %d composed pane stations; clear_capture=%s" % [source.buildings.size(),parts,stations.size(),found])
