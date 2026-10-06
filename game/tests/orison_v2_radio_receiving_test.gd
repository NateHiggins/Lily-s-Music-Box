extends "res://tests/orison_v2_passage_receivers_test.gd"
## Native assembled chassis plus the inherited ordinary receiving input checks.

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	_check_native_chassis(world)
	await _chassis_views(world)
	await super._retail_detail_views(world, fixture)

func _check_native_chassis(world: OrisonV2RuntimeRoot) -> void:
	var cell: Node3D = world.passage_region.cell_nodes.shop_radio_service
	var model := cell.get_node_or_null("RadioReceiving") as Node3D
	check(model != null, "one fitted native period chassis is mounted in Radio Service")
	if model == null: return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_receiving.json"))
	var runtime: Dictionary = fixture.runtime
	check(FileAccess.get_sha256(str(runtime.asset)) == fixture.asset_sha256, "actual native glTF binds its construction fixture")
	check(fixture.original_records.size() == 1 and fixture.original_primitives.size() == 20, "one immutable assembler record retains twenty original source primitives")
	check(fixture.closed_stocks.size() == 417 and fixture.parts.size() == 11 and int(fixture.triangles) == 38040, "native inventory binds all closed stocks and exported partitions")
	var originals: Dictionary = model.get_meta("original_meshes")
	var retired: Dictionary = model.get_meta("removed_triangles")
	var count := 0
	for record: Dictionary in runtime.original_draws:
		var draw := cell.get_node(str(record.name)) as MeshInstance3D
		check(originals.has(draw) and originals[draw] == draw.mesh and not draw.visible, "exact original draw is hidden intact: " + str(record.name))
		check(draw.mesh.get_faces().size() == int(record.expected_triangles) * 3 and int(retired.get(record.name, -1)) == int(record.expected_triangles), "draw retirement uses complete original owner: " + str(record.name))
		count += int(record.expected_triangles)
	var hull := model.get_meta("original_hull") as StaticBody3D
	var hull_shape := hull.get_child(0) as CollisionShape3D
	check(count == 400 and originals.size() == 8 and int(retired.get(runtime.hull_name, -1)) == 12, "eight original draws and exactly twelve hull triangles retire")
	check(hull.collision_layer == 0 and hull.collision_mask == 0 and hull_shape.disabled and (hull_shape.shape as ConcavePolygonShape3D).get_faces().size() == 36, "exact original hull is disabled intact without changing neighboring collision")
	var protected: Dictionary = model.get_meta("protected_meshes")
	var snapshots: Dictionary = model.get_meta("protected_arrays")
	for draw: MeshInstance3D in protected:
		check(draw.mesh == protected[draw], "unrelated shipping draw retains its original mesh owner: " + str(draw.name))
		var arrays: Array = []
		for i in draw.mesh.get_surface_count(): arrays.append(draw.mesh.surface_get_arrays(i))
		check(arrays == snapshots[str(draw.name)], "unrelated shipping vertices, normals, UVs, indices and every array remain exact: " + str(draw.name))
	var shapes: Dictionary = model.get_meta("protected_shapes")
	for shape: CollisionShape3D in shapes:
		var before: Dictionary = shapes[shape]
		check(shape.shape == before.shape and shape.disabled == before.disabled and shape.transform == before.transform, "unrelated shipping collision retains its shape, state and pose: " + str(shape.get_parent().name))
	var triangles := 0
	var draws := model.find_children("*", "MeshInstance3D", true, false)
	check(draws.size() == fixture.parts.size(), "native partitions retain one imported owner each")
	for draw: MeshInstance3D in draws:
		var name := str(draw.get_meta("radio_receiving_part", ""))
		var part: Dictionary = runtime.parts.filter(func(row): return str(row.name) == name)[0]
		var mat := draw.mesh.surface_get_material(0) as StandardMaterial3D
		var library := MatLib.get_mat(str(part.catalog_key))
		check(mat != library and mat != null and not mat.uv1_triplanar and mat.albedo_texture == library.albedo_texture and mat.roughness_texture == library.roughness_texture and mat.normal_texture == library.normal_texture, "native period finish uses exact existing catalogue maps: " + name)
		check(mat.metallic == library.metallic and mat.roughness == library.roughness and mat.normal_scale == library.normal_scale and mat.uv1_scale.is_equal_approx(Vector3.ONE / float(part.tile)), "native local finish preserves catalogue values and metre charts: " + name)
		_check_cap_mapping(draw.mesh, true)
		var physical := draw.find_children("*", "CollisionShape3D", true, false)
		check(physical.size() == 1 and physical[0].shape is ConcavePolygonShape3D and physical[0].shape.get_faces() == draw.mesh.get_faces() and physical[0].global_transform.is_equal_approx(draw.global_transform), "native visible and physical triangles agree: " + name)
		triangles += draw.mesh.get_faces().size() / 3
		owned_nodes.append(weakref(draw)); owned_resources.append(weakref(draw.mesh)); owned_resources.append(weakref(mat))
		if physical.size() == 1: owned_resources.append(weakref(physical[0].shape))
	check(triangles == int(fixture.triangles), "actual installed native triangle inventory is complete")
	check(model.find_children("*", "Light3D", true, false).is_empty(), "native chassis adds no illumination or signal authority")
	for contact: Dictionary in fixture.contacts:
		var at := _v(contact.point); var direction := _v(contact.direction)
		var exclude: Array[RID] = [world.player.get_rid()]
		for body: CollisionObject3D in model.find_children("*", "CollisionObject3D", true, false): exclude.append(body.get_rid())
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cell.to_global(at + direction * .004), cell.to_global(at - direction * .004), 1, exclude))
		check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at) < .00003, "native foot meets actual retained source floor: " + str(contact.label))
	check(absf(float(fixture.fitted_datums.floor_top) - .01) < .000001 and fixture.fitted_datums.service_panel_closed, "source-derived floor top and closed passive hatch remain declared")
	check(not world.passage_region.RadioReceiving.mount_cell(cell, world.passage_region.source_layout), "repeat native chassis mount refuses duplicate geometry")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("native_chassis.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "original_draws":originals.size(), "retired_drawn_triangles":count, "retired_hull_triangles":12, "parts":draws.size(), "triangles":triangles, "protected_draws":protected.size(), "protected_collisions":shapes.size(), "failures":failures}, "\t"))

func _chassis_views(world: OrisonV2RuntimeRoot) -> void:
	var cell: Node3D = world.passage_region.cell_nodes.shop_radio_service
	for spec: Dictionary in [
		{"id":"chassis_front", "feet":[19.45,.03,57.5], "target":[21.08,1.20,57.2]},
		{"id":"chassis_service_side", "feet":[20.80,.03,57.94], "target":[21.45,.58,57.53]},
		{"id":"chassis_floor_feet", "feet":[20.80,.03,57.94], "target":[21.2,.05,57.49]},
		{"id":"chassis_circular_scope", "feet":[19.45,.03,57.5], "target":[21.08,1.20,57.2]}]:
		var feet := cell.to_global(_v(spec.feet))
		check(_city_clear_station(world, feet), "native detail floor/capsule observation: " + str(spec.id))
		world.player.global_position = feet; world.player.velocity = Vector3.ZERO
		world.player.face_world_point(cell.to_global(_v(spec.target))); world.player.set_lamp_enabled(true)
		await _settled_optics(); await shot(str(spec.id))
