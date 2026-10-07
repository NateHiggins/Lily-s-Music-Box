extends "res://tests/orison_v2_city_sweep.gd"
## Five native supports, unchanged furniture owners and actual floor bearings.
var batch_mode := true
var capture_enabled := true
var mounted_ids: Array[int] = []
func _ready() -> void: pass

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_work_tables.json"))
	check(FileAccess.get_sha256("res://assets/props/work_tables.glb") == fixture.asset_sha256, "table export matches native construction fixture")
	var count := 0
	var triangles := 0
	for row: Dictionary in fixture.runtime.assemblies:
		var body := world.adapter.resolve(str(row.id)) as StaticBody3D
		check(body != null and body.get_meta("v2_furniture_id", "") == row.id and body.get_meta("v2_native_work_table", "") == row.id, "existing actor owns native table: " + str(row.id))
		if body == null: continue
		mounted_ids.append(body.get_instance_id())
		for part: Dictionary in row.parts:
			var draw := body.find_child(str(part.name), true, false) as MeshInstance3D
			check(draw != null and draw.owner == null and draw.get_parent() == body, "existing actor owns unbound native part: " + str(part.name))
			if draw == null: continue
			var expected: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
			var faces := draw.mesh.get_faces()
			check(faces.size()/3 == int(expected.triangles), "exact native table partition")
			count += 1; triangles += faces.size()/3
			_check_cap_mapping(draw.mesh, true)
			var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
			var library := MatLib.get_mat(str(part.catalog_key))
			check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)), "table uses native metre charts")
			check(material != library and material.albedo_texture == library.albedo_texture and material.normal_texture == library.normal_texture and material.roughness_texture == library.roughness_texture, "catalogue material maps are instance local")
			if part.key == "oak_work_surface":
				for texture: Texture2D in [material.albedo_texture, material.normal_texture, material.roughness_texture]:
					check(texture.get_image().has_mipmaps(), "new runtime oak map has a real mip chain")
		var shapes := body.find_children("*", "CollisionShape3D", false, false)
		check(shapes.size() == row.parts.size(), "one exact collision per native partition")
		for shape: CollisionShape3D in shapes: check(shape.shape is ConcavePolygonShape3D, "table no longer has a broad source hull")
	check(count == fixture.parts.size() and triangles == int(fixture.triangles), "all table stock accounted for")
	for probe: Dictionary in fixture.contacts:
		var body := world.adapter.resolve(str(probe.assembly)) as StaticBody3D
		var p: Array = probe.point
		var at := body.to_global(Vector3(p[0],p[1],p[2]))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
		check(not hit.is_empty() and hit.position.distance_to(at)<.00003 and hit.normal.y>.99, "actual world floor meets table foot: " + str(probe.assembly) + " / " + str(probe.label))
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_surface_props.json"))
	for row: Dictionary in props.props:
		if not row.support in preload("res://scripts/building/orison_v2_work_tables.gd").IDS: continue
		var body := world.adapter.resolve(str(row.support)) as StaticBody3D
		var prop := body.get_node_or_null(str(row.id)) as Node3D
		check(prop != null and prop.get_parent() == body, "source tabletop stock retains its owner: " + str(row.id))
		if prop != null:
			check(prop.position.is_equal_approx(Vector3(row.position[0],row.position[1],row.position[2])) and is_equal_approx(prop.rotation.y,float(row.yaw)), "retained tabletop stock pose: " + str(row.id))
	if capture_enabled:
		for row: Dictionary in fixture.runtime.assemblies:
			var body := world.adapter.resolve(str(row.id)) as StaticBody3D
			# Use the established lamp stations where available; 6A faces its narrow edge.
			var stations := {"2A_desk":Vector3(-12.3,3.22,6.75),"3B_workbench":Vector3(13.65,6.42,-1.35),"4B_terminal_desk":Vector3(-9.9,9.62,.7),"5A_plantable":Vector3(-11,12.82,-4.6)}
			var feet: Vector3 = world.adapter.root.to_global(stations[str(row.id)]) if stations.has(row.id) else body.to_global(Vector3(-1.35,.02,-.65))
			check(_city_clear_station(world,feet), "standing capture station clears table: " + str(row.id))
			await _city_capture(world,feet,body.to_global(Vector3(0,.6,0)),str(row.id)+"_context","native working table",str(row.id))
	return {"checks":checks,"parts":count,"triangles":triangles,"failures":failures.duplicate()}

func validate_after_teardown() -> Dictionary:
	for id: int in mounted_ids: check(not is_instance_id_valid(id), "native table retires with existing actor")
	return {"checks":checks,"failures":failures.duplicate()}
