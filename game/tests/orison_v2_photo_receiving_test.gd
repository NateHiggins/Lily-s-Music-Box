extends "res://tests/orison_v2_radio_receiving_test.gd"
## Native Photo chassis, ordinary COUNTY LEAGUE input and inherited Radio checks.
var photo_exercised := false

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	_check_photo_chassis(world)
	await _photo_chassis_views(world)
	await _exercise_photo_receiver(world)
	await super._retail_detail_views(world, fixture)

func _check_photo_chassis(world: OrisonV2RuntimeRoot) -> void:
	var cell: Node3D = world.passage_region.cell_nodes.shop_photo_supplies
	var model := cell.get_node_or_null("PhotoReceiving") as Node3D
	check(model != null, "one fitted native period chassis is mounted in Photo Supplies")
	if model == null: return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_receiving.json"))
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
		var name := str(draw.get_meta("photo_receiving_part", ""))
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
	check(not world.passage_region.PhotoReceiving.mount_cell(cell, world.passage_region.source_layout), "repeat native chassis mount refuses duplicate geometry")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("native_photo_chassis.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "original_draws":originals.size(), "retired_drawn_triangles":count, "retired_hull_triangles":12, "parts":draws.size(), "triangles":triangles, "protected_draws":protected.size(), "protected_collisions":shapes.size(), "failures":failures}, "\t"))

func _photo_chassis_views(world: OrisonV2RuntimeRoot) -> void:
	var cell: Node3D = world.passage_region.cell_nodes.shop_photo_supplies
	var observations: Array=[]
	for spec: Dictionary in [
		{"id":"photo_chassis_front", "feet":[20.35,.03,60.1], "target":[21.45,1.20,59.736]},
		{"id":"photo_chassis_service_side", "feet":[22.25,.03,59.9], "target":[21.776,.58,59.35]},
		{"id":"photo_chassis_floor_feet", "feet":[22.25,.03,59.9], "target":[21.72,.05,59.65]},
		{"id":"photo_chassis_circular_scope", "feet":[20.35,.03,60.1], "target":[21.45,1.20,59.736]}]:
		var requested := _v(spec.feet); var selected := requested; var distance := INF
		if not _city_clear_station(world,cell.to_global(requested)):
			var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_receiving.json"))
			var r: Array=fixture.assemblies[0].floor.rect
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(requested)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(requested)
		var feet := cell.to_global(selected)
		check(_city_clear_station(world, feet), "native detail floor/capsule observation: " + str(spec.id))
		world.player.global_position = feet; world.player.velocity = Vector3.ZERO
		world.player.face_world_point(cell.to_global(_v(spec.target))); world.player.set_lamp_enabled(true)
		await _settled_optics(); await shot(str(spec.id))
		observations.append({"id":spec.id,"requested_feet":spec.feet,"feet":[selected.x,selected.y,selected.z],"target":spec.target,"image":str(spec.id)+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("photo_chassis_views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Actual retained floor/capsule observations. Preferred side station selects the nearest clear floor sample if obstructed; no continuous route, service-hatch interaction, sightline or human acceptance."},"\t"))

func _exercise_photo_receiver(world: OrisonV2RuntimeRoot) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies
	var prop:=world.passage_region._actors.get_node_or_null("Arcade_storm_shopcab_photo_supplies0") as ArcadeCabinetProp
	check(prop!=null and prop.cabinet.title=="COUNTY LEAGUE", "native Photo chassis retains its COUNTY LEAGUE programme owner")
	if prop==null:return
	world.player.global_position=cell.to_global(Vector3(20.35,.03,60.1));world.player.velocity=Vector3.ZERO
	check(_city_clear_station(world,world.player.global_position),"Photo keyboard station has actual source floor and clear standing capsule")
	world.player.face_world_point(prop._screen.global_position);world.player.set_lamp_enabled(true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await _settled_optics()
	check(prop.machine.is_booted() and (prop._screen.mesh as QuadMesh).size.is_equal_approx(Vector2(.36,.36))
		and prop._screen.position.is_equal_approx(Vector3(0,1.20,-.386)),"native circular aperture retains the original variant-2 live scope quad and centre")
	world.player._update_prompt()
	var ray:=PhysicsRayQueryParameters3D.create(world.player.camera.global_position,
		world.player.camera.global_position-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()])
	ray.collide_with_areas=true
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	var node: Node=hit.get("collider");var reached:=false
	while node!=null:
		reached=reached or node==prop;node=node.get_parent()
	check(reached and world.player._prompt.text.contains("COUNTY LEAGUE"),"actual Photo standing ray and prompt reach the unchanged receiving interaction")
	if not reached:return
	_track_board(prop)
	await _key_event(KEY_E)
	check(prop._playing() and world.player.call_locked and prop.machine.state==ArcadeMachine.State.PLAYING,
		"ordinary keyboard E enters COUNTY LEAGUE and locks outer movement")
	if not prop._playing():return
	var panel := prop._panel_ui as ArcadePanel
	for control in [panel,panel._picture]:owned_nodes.append(weakref(control))
	for label in panel.find_children("*","Label",true,false):owned_nodes.append(weakref(label))
	_track_board(prop)
	await shot("photo_receiving_play")
	await _key_event(KEY_ESCAPE)
	check(not prop._playing() and not world.player.call_locked and prop.machine.state==ArcadeMachine.State.ATTRACT
		and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"ordinary Escape returns COUNTY LEAGUE to attract and releases movement")
	await shot("photo_receiving_step_away")
	photo_exercised=true

func _write_receiving_contract(started: int, nodes: int, resources: int, playbacks: int) -> void:
	check(photo_exercised,"COUNTY LEAGUE ordinary standing keyboard cycle executed")
	super._write_receiving_contract(started,nodes,resources,playbacks)
	var path:=OS.get_environment("SHOT_DIR").path_join("runtime_contract.json")
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	receipt.scope=str(receipt.scope)+" Also executes ordinary COUNTY LEAGUE keyboard entry/exit after the native Photo fit. Native construction measurements remain inert."
	receipt.contracts.photo_keyboard={"executed":photo_exercised,"status":"PASS" if photo_exercised and failures.is_empty() else "FAIL"}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
