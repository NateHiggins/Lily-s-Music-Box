extends "res://tests/orison_v2_passage_route_test.gd"

var _moved_cart: PassagePushcart
var _initial_cart_position: Vector3
var _surface_signature: Dictionary = {}
var _receiver_signature: Dictionary = {}
var _diner_probe: WeakRef
var _diner_probe_id: int

func _init() -> void:
	route_label = "V2 PASSAGE RESIDENCY"

func _capture(identity: String, target: Vector3) -> void:
	await super._capture(identity, target)
	if identity != "nave": return
	if not _check_specialist_fittings():return
	var probe:=world.passage_region.cell_nodes.shop_luncheonette.get_node("DinerBackbar/DinerFinishReflection") as ReflectionProbe
	_diner_probe=weakref(probe);_diner_probe_id=probe.get_instance_id()
	_receiver_signature = _receiver_values()
	if not _require(_receiver_signature.size()==(7 if world.passage_region.cabinets_enabled else 0),"receiving actor count follows the fixed cabinet policy before reconstruction"):return
	_check_ceiling_detail()
	_surface_signature = _surface_values()
	_moved_cart = world.passage_region.finish.pushcarts[0]
	_initial_cart_position = _moved_cart.global_position
	if not await _walk_world(_moved_cart.global_position + Vector3(0, -_moved_cart.global_position.y, -1.3)): return
	if not await _use(_moved_cart, _moved_cart.global_position+Vector3.UP*0.6, "handcart"): return
	await get_tree().create_timer(1.0).timeout
	_require(_moved_cart.global_position.distance_to(_initial_cart_position) > 0.05,
			"ordinary input physically moves the handcart")
	await _walk_world(Vector3(14, 0, 32))

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	var passage := world.passage_region
	var cart_position := _moved_cart.global_position
	var cart_id := _moved_cart.get_instance_id()
	var door: DoorProp = passage.doors.SITE_SHOP_DOOR_HARDWARE_PAINT
	var door_id := door.get_instance_id()
	var door_open := door.open
	var inventory := var_to_bytes(RealityState.data.maintenance_items)
	if not await _walk(Vector3(1.925, 0, -3.5)): return
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var dormant: Dictionary = passage.residency.snapshot()
	print("RESIDENCY_DORMANT ", JSON.stringify(dormant))
	if not _require(dormant.state == "DORMANT" and dormant.cell_count == 1
			and dormant.pending_requests == 0 and dormant.retired_geometry_roots_alive == 0
			and dormant.retired_mesh_resources_alive == 0,
			"dormancy releases imported nodes and mesh resources"): return
	if not _require(_diner_probe!=null and _diner_probe.get_ref()==null,
			"dormancy releases the Diner room reflection owner"):return
	if not _require(world.shop_service.counter("hardware_paint") == null
			and _moved_cart.freeze and _moved_cart.collision_layer == 0,
			"dormancy unregisters counter and suspends cart physics"): return
	if not _require(_receiver_values()==_receiver_signature,
			"dormancy preserves receiver identities, cards, variants and graph bindings"):return
	for receiver: ArcadeCabinetProp in passage.receiving_row.cabinets:
		if not _require(not receiver.machine.is_booted() and receiver.machine.package==null
				and receiver.machine.render_target_update_mode==SubViewport.UPDATE_DISABLED,
				"dormancy releases inactive receiving world: "+str(receiver.name)):return
	for point in [Vector3(1.925, 0, -6.5), Vector3(0, 0, -8.5), Vector3(0, 0, -10.2)]:
		if not await _walk(point): return
	var started := Time.get_ticks_msec()
	while passage.residency.state == "LOADING" and Time.get_ticks_msec()-started < 5000:
		await get_tree().process_frame
	var resumed: Dictionary = passage.residency.snapshot()
	print("RESIDENCY_RESUMED ", JSON.stringify(resumed))
	if not _require(resumed.state == "RESIDENT" and resumed.cell_count == 13
			and resumed.load_cycles >= 2 and resumed.unload_cycles >= 2,
			"vestibule prefetch reconstructs a second geometry cycle"): return
	if not _check_specialist_fittings():return
	if not _require(passage.cell_nodes.shop_luncheonette.get_node("DinerBackbar/DinerFinishReflection").get_instance_id()!=_diner_probe_id,
			"reconstruction creates a fresh one-time Diner reflection owner"):return
	_require(_receiver_values()==_receiver_signature,
			"geometry reconstruction preserves the chosen receiving actor population")
	_require(door.get_instance_id() == door_id and door.open == door_open
			and _moved_cart.get_instance_id() == cart_id
			and _moved_cart.global_position.distance_to(cart_position) < 0.03
			and _moved_cart.global_position.distance_to(_initial_cart_position) > 0.05,
			"open leaf and physically moved cart survive residency unchanged")
	_require(world.shop_service.counter("hardware_paint") != null
			and var_to_bytes(RealityState.data.maintenance_items) == inventory
			and not world.shop_service.acquire("carbon_transmitter_capsule", "hardware_paint"),
			"counter remount preserves acquisition and duplicate protection")
	_require(not _surface_signature.is_empty() and _surface_values() == _surface_signature,
			"all shader values and texture paths survive geometry reconstruction")
	_check_ceiling_detail()

func _receiver_values() -> Dictionary:
	var result := {}
	for receiver: ArcadeCabinetProp in world.passage_region.receiving_row.cabinets:
		result[str(receiver.name)]={"instance":receiver.get_instance_id(),
			"card":receiver.cabinet.duplicate(true),"variant":receiver.variant,
			"graph":receiver.graph_node_id,"pose":receiver.transform,
			"infection":receiver._infection}
	return result

var _photo_lamp_instance := 0

func _check_specialist_fittings() -> bool:
	# Both observed reconstruction cycles must carry the same native owners
	# as startup, rather than quietly reverting to retired source boxes.
	var specialist_specs: Array=[
		["shop_model_laundry","LaundryTrade","laundry_trade"],
		["shop_luncheonette","DinerCounter","diner_counter"],
		["shop_luncheonette","DinerTill","diner_till"],
		["shop_luncheonette","DinerBackbar","diner_backbar"],
		["shop_luncheonette","DinerUrns","diner_urns"],
		["shop_luncheonette","DinerApparatus","diner_apparatus"],
		["shop_luncheonette","DinerOverhead","diner_overhead"],
		["shop_pawnbroker","PawnClocks","pawn_clocks"],
		["shop_pawnbroker","PawnDisplay","pawn_display"],
		["shop_pawnbroker","PawnFittings","pawn_fittings"],
		["shop_funeral_parlour","FuneralFittings","funeral_fittings"],
		["shop_funeral_parlour","FuneralDrapes","funeral_drapes"],
		["shop_funeral_parlour","FuneralFoliage","funeral_foliage"],
		["shop_radio_service","RadioBench","radio_bench"],
		["shop_radio_service","RadioApparatus","radio_apparatus"],
		["shop_radio_service","RadioStock","radio_stock"],
		["shop_radio_service","RadioBattery","radio_battery"],
		["shop_radio_service","RadioWire","radio_wire"],
		["shop_radio_service","RadioDisplay","radio_display"]]
	var clerestories: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_shop_clerestories.json"))
	for record: Dictionary in clerestories.runtime.cells:specialist_specs.append([str(record.id),"ShopClerestories","shop_clerestories"])
	var joinery: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_shop_joinery.json"))
	for record: Dictionary in joinery.runtime.cells:specialist_specs.append([str(record.id),"ShopJoinery","shop_joinery"])
	var photo_radio: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_radio_fittings.json"))
	for record: Dictionary in photo_radio.runtime.cells:specialist_specs.append([str(record.id),"PhotoRadioFittings","photo_radio_fittings"])
	for spec: Array in specialist_specs:
		var cell: Node3D=world.passage_region.cell_nodes[spec[0]]
		var model:=cell.get_node_or_null(str(spec[1])) as Node3D
		if not _require(model!=null,"reloaded native owner exists: "+str(spec[1])):return false
		if spec[1]=="DinerBackbar":
			var probe:=model.get_node_or_null("DinerFinishReflection") as ReflectionProbe
			if not _require(probe!=null and probe.update_mode==ReflectionProbe.UPDATE_ONCE and probe.box_projection and probe.interior,
					"reloaded Diner fitting owns one bounded room reflection"):return false
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_"+str(spec[2])+".json"))
		if not _require(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"reloaded native source export binds: "+str(spec[1])):return false
		var retired: Dictionary=model.get_meta("removed_triangles")
		var expected: Dictionary=fixture.runtime.cells.filter(func(row):return row.id==spec[0])[0]
		for box: Dictionary in expected.replace:
			if not _require(int(retired.get(box.id,-1))==int(box.expected_triangles),"reloaded source boundary stays retired: "+str(box.id)):return false
		var draws:=model.find_children("*","MeshInstance3D",true,false)
		if not _require(draws.size()==expected.parts.size(),"reloaded native partitions remain: "+str(spec[1])):return false
		for draw: MeshInstance3D in draws:
			var shapes:=draw.find_children("*","CollisionShape3D",true,false)
			if not _require(shapes.size()==1 and shapes[0].shape is ConcavePolygonShape3D and shapes[0].shape.get_faces()==draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform),"reloaded native visible/physical faces agree: "+str(draw.name)):return false
	var photo_lamp = world.passage_region._actors.get_node("SITE_SHOP_DARKROOM_PHOTO_SUPPLIES")
	if _photo_lamp_instance == 0: _photo_lamp_instance = photo_lamp.get_instance_id()
	if not _require(photo_lamp.get_instance_id() == _photo_lamp_instance and photo_lamp.get_script() == preload("res://scripts/props/photo_darkroom_light.gd"), "streamed geometry preserves original Photo electrical actor"): return false
	if not _require(photo_lamp.native_parts.size() == photo_radio.runtime.actor_parts.size(), "streaming preserves one complete actor-owned native lamp"): return false
	for draw: MeshInstance3D in photo_lamp.native_parts.values():
		if not _require(draw.owner == null, "persistent lamp draw has no retired imported-scene owner"): return false
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if not _require(shapes.size() == 1 and shapes[0].shape.get_faces() == draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform), "persistent Photo lamp retains native physical pose"): return false
	if not world.passage_region.cabinets_enabled:
		return _check_removed_cabinets()
	var radio_cell: Node3D = world.passage_region.cell_nodes.shop_radio_service
	var receiving := radio_cell.get_node_or_null("RadioReceiving") as Node3D
	if not _require(receiving != null, "reconstructed native receiving chassis exists"): return false
	var receiving_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_receiving.json"))
	if not _require(FileAccess.get_sha256(str(receiving_fixture.runtime.asset)) == receiving_fixture.asset_sha256, "reconstructed receiving chassis binds its native export"): return false
	var receiving_retired: Dictionary = receiving.get_meta("removed_triangles")
	for source_draw: Dictionary in receiving_fixture.runtime.original_draws:
		var original := radio_cell.get_node(str(source_draw.name)) as MeshInstance3D
		if not _require(not original.visible and int(receiving_retired.get(source_draw.name, -1)) == int(source_draw.expected_triangles), "reconstructed assembled source draw stays retired: " + str(source_draw.name)): return false
	var old_hull := receiving.get_meta("original_hull") as StaticBody3D
	if not _require(old_hull.collision_layer == 0 and old_hull.collision_mask == 0 and old_hull.get_child(0).disabled and int(receiving_retired.get(receiving_fixture.runtime.hull_name, -1)) == 12, "reconstructed exact source hull remains disabled"): return false
	var receiving_draws := receiving.find_children("*", "MeshInstance3D", true, false)
	if not _require(receiving_draws.size() == receiving_fixture.parts.size(), "reconstructed native receiving partitions remain complete"): return false
	for draw: MeshInstance3D in receiving_draws:
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if not _require(shapes.size() == 1 and shapes[0].shape.get_faces() == draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform), "reconstructed receiving physical faces match visible faces: " + str(draw.name)): return false
	var photo_cell: Node3D = world.passage_region.cell_nodes.shop_photo_supplies
	var photo_receiving := photo_cell.get_node_or_null("PhotoReceiving") as Node3D
	if not _require(photo_receiving != null, "reconstructed native photo_receiving chassis exists"): return false
	var photo_receiving_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_receiving.json"))
	if not _require(FileAccess.get_sha256(str(photo_receiving_fixture.runtime.asset)) == photo_receiving_fixture.asset_sha256, "reconstructed photo_receiving chassis binds its native export"): return false
	var photo_receiving_retired: Dictionary = photo_receiving.get_meta("removed_triangles")
	for source_draw: Dictionary in photo_receiving_fixture.runtime.original_draws:
		var original := photo_cell.get_node(str(source_draw.name)) as MeshInstance3D
		if not _require(not original.visible and int(photo_receiving_retired.get(source_draw.name, -1)) == int(source_draw.expected_triangles), "reconstructed assembled source draw stays retired: " + str(source_draw.name)): return false
	var photo_old_hull := photo_receiving.get_meta("original_hull") as StaticBody3D
	if not _require(photo_old_hull.collision_layer == 0 and photo_old_hull.collision_mask == 0 and photo_old_hull.get_child(0).disabled and int(photo_receiving_retired.get(photo_receiving_fixture.runtime.hull_name, -1)) == 12, "reconstructed exact source hull remains disabled"): return false
	var photo_receiving_draws := photo_receiving.find_children("*", "MeshInstance3D", true, false)
	if not _require(photo_receiving_draws.size() == photo_receiving_fixture.parts.size(), "reconstructed native photo_receiving partitions remain complete"): return false
	for draw: MeshInstance3D in photo_receiving_draws:
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if not _require(shapes.size() == 1 and shapes[0].shape.get_faces() == draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform), "reconstructed photo_receiving physical faces match visible faces: " + str(draw.name)): return false
	var news_cell: Node3D = world.passage_region.cell_nodes.shop_news_cigars
	var news_receiving := news_cell.get_node_or_null("NewsReceiving") as Node3D
	if not _require(news_receiving != null, "reconstructed native news_receiving chassis exists"): return false
	var news_receiving_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_news_receiving.json"))
	if not _require(FileAccess.get_sha256(str(news_receiving_fixture.runtime.asset)) == news_receiving_fixture.asset_sha256, "reconstructed news_receiving chassis binds its native export"): return false
	var news_receiving_retired: Dictionary = news_receiving.get_meta("removed_triangles")
	for source_draw: Dictionary in news_receiving_fixture.runtime.original_draws:
		var original := news_cell.get_node(str(source_draw.name)) as MeshInstance3D
		if not _require(not original.visible and int(news_receiving_retired.get(source_draw.name, -1)) == int(source_draw.expected_triangles), "reconstructed assembled source draw stays retired: " + str(source_draw.name)): return false
	var news_old_hull := news_receiving.get_meta("original_hull") as StaticBody3D
	if not _require(news_old_hull.collision_layer == 0 and news_old_hull.collision_mask == 0 and news_old_hull.get_child(0).disabled and int(news_receiving_retired.get(news_receiving_fixture.runtime.hull_name, -1)) == 12, "reconstructed exact source hull remains disabled"): return false
	var news_receiving_draws := news_receiving.find_children("*", "MeshInstance3D", true, false)
	if not _require(news_receiving_draws.size() == news_receiving_fixture.parts.size(), "reconstructed native news_receiving partitions remain complete"): return false
	for draw: MeshInstance3D in news_receiving_draws:
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if not _require(shapes.size() == 1 and shapes[0].shape.get_faces() == draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform), "reconstructed news_receiving physical faces match visible faces: " + str(draw.name)): return false
	var pawn_cell: Node3D = world.passage_region.cell_nodes.shop_pawnbroker
	var pawn_receiving := pawn_cell.get_node_or_null("PawnReceiving") as Node3D
	if not _require(pawn_receiving != null, "reconstructed native pawn_receiving chassis exists"): return false
	var pawn_receiving_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_pawn_receiving.json"))
	if not _require(FileAccess.get_sha256(str(pawn_receiving_fixture.runtime.asset)) == pawn_receiving_fixture.asset_sha256, "reconstructed pawn_receiving chassis binds its native export"): return false
	var pawn_receiving_retired: Dictionary = pawn_receiving.get_meta("removed_triangles")
	for source_draw: Dictionary in pawn_receiving_fixture.runtime.original_draws:
		var original := pawn_cell.get_node(str(source_draw.name)) as MeshInstance3D
		if not _require(not original.visible and int(pawn_receiving_retired.get(source_draw.name, -1)) == int(source_draw.expected_triangles), "reconstructed assembled source draw stays retired: " + str(source_draw.name)): return false
	var pawn_old_hull := pawn_receiving.get_meta("original_hull") as StaticBody3D
	if not _require(pawn_old_hull.collision_layer == 0 and pawn_old_hull.collision_mask == 0 and pawn_old_hull.get_child(0).disabled and int(pawn_receiving_retired.get(pawn_receiving_fixture.runtime.hull_name, -1)) == 12, "reconstructed exact source hull remains disabled"): return false
	var pawn_receiving_draws := pawn_receiving.find_children("*", "MeshInstance3D", true, false)
	if not _require(pawn_receiving_draws.size() == pawn_receiving_fixture.parts.size(), "reconstructed native pawn_receiving partitions remain complete"): return false
	for draw: MeshInstance3D in pawn_receiving_draws:
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if not _require(shapes.size() == 1 and shapes[0].shape.get_faces() == draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform), "reconstructed pawn_receiving physical faces match visible faces: " + str(draw.name)): return false
	var diner_cell: Node3D = world.passage_region.cell_nodes.shop_luncheonette
	var diner_receiving := diner_cell.get_node_or_null("DinerReceiving") as Node3D
	if not _require(diner_receiving != null, "reconstructed native diner_receiving chassis exists"): return false
	var diner_receiving_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_diner_receiving.json"))
	if not _require(FileAccess.get_sha256(str(diner_receiving_fixture.runtime.asset)) == diner_receiving_fixture.asset_sha256, "reconstructed diner_receiving chassis binds its native export"): return false
	var diner_receiving_retired: Dictionary = diner_receiving.get_meta("removed_triangles")
	for source_draw: Dictionary in diner_receiving_fixture.runtime.original_draws:
		var original := diner_cell.get_node(str(source_draw.name)) as MeshInstance3D
		if not _require(not original.visible and int(diner_receiving_retired.get(source_draw.name, -1)) == int(source_draw.expected_triangles), "reconstructed assembled source draw stays retired: " + str(source_draw.name)): return false
	var diner_old_hull := diner_receiving.get_meta("original_hull") as StaticBody3D
	if not _require(diner_old_hull.collision_layer == 0 and diner_old_hull.collision_mask == 0 and diner_old_hull.get_child(0).disabled and int(diner_receiving_retired.get(diner_receiving_fixture.runtime.hull_name, -1)) == 24, "reconstructed exact source hull remains disabled"): return false
	var diner_receiving_draws := diner_receiving.find_children("*", "MeshInstance3D", true, false)
	if not _require(diner_receiving_draws.size() == diner_receiving_fixture.parts.size(), "reconstructed native diner_receiving partitions remain complete"): return false
	for draw: MeshInstance3D in diner_receiving_draws:
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if not _require(shapes.size() == 1 and shapes[0].shape.get_faces() == draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform), "reconstructed diner_receiving physical faces match visible faces: " + str(draw.name)): return false
	return true

func _check_removed_cabinets() -> bool:
	var passage := world.passage_region
	if not _require(passage.receiving_row.cabinets.is_empty() and passage._actors.find_children("Arcade_*", "", true, false).is_empty(),
			"cabinet-free shops have no board actors, play prompts or screen owners"): return false
	var total := 0
	for spec: Array in [["radio","shop_radio_service","RadioReceiving"],
		["laundry","shop_model_laundry","LaundryReceiving"],["photo","shop_photo_supplies","PhotoReceiving"],
		["news","shop_news_cigars","NewsReceiving"],["pawn","shop_pawnbroker","PawnReceiving"],
		["diner","shop_luncheonette","DinerReceiving"]]:
		var cell: Node3D = passage.cell_nodes[spec[1]]
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/"+str(spec[0])+"_receiving.json"))
		if not _require(not cell.has_node(str(spec[2])), "replacement cabinet meshes stay absent: "+str(spec[1])): return false
		for record: Dictionary in data.original_draws:
			var draw := cell.get_node(str(record.name)) as MeshInstance3D
			if not _require(not draw.visible and draw.mesh.get_faces().size()==int(record.expected_triangles)*3,
					"temporarily hidden original cabinet draw remains intact: "+str(record.name)): return false
		var hull := cell.get_node(str(data.hull_name)) as StaticBody3D
		var shapes := hull.find_children("*","CollisionShape3D",true,false)
		if not _require(hull.collision_layer==0 and hull.collision_mask==0 and shapes.size()==1 and shapes[0].disabled
				and shapes[0].shape.get_faces().size()==int(data.hull_triangles)*3,
				"removed cabinets leave no source collision: "+str(spec[1])): return false
		var sources: Array = data.get("source_records", [data.get("source_record", {})])
		for source: Dictionary in sources:
			var matches: Array = passage.source_layout.floors.filter(func(row):return row.id=="F01")[0].furniture.filter(func(row):return row.id==source.id)
			if not _require(matches.size()==1 and matches[0]==source, "cabinet removal retains its exact authored record: "+str(source.id)): return false
			var center := GameBoot.b2g([source.at[0],source.at[1],1.0])
			var ray := PhysicsRayQueryParameters3D.create(cell.to_global(center-Vector3.RIGHT*.02),cell.to_global(center+Vector3.RIGHT*.02),1,[player.get_rid()])
			if not _require(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),
					"former cabinet centre has no invisible collision: "+str(source.id)): return false
			total += 1
	return _require(total==7, "all seven shop cabinets remain removed after geometry reconstruction")

func _check_ceiling_detail() -> void:
	var cell: Node3D = world.passage_region.cell_nodes.passage
	var details := cell.find_children("V2_PASSAGE_finish_ceiling_*", "MeshInstance3D", true, false)
	_require(details.size() == 3, "all three ceiling detail batches survive passage residency")
	for mesh: MeshInstance3D in details:
		_require(mesh.mesh != null and mesh.mesh.get_surface_count() == 1,
				"ceiling ornaments remain single batched surfaces")
		var material := mesh.get_active_material(0) as ShaderMaterial
		_require(material != null, "ceiling detail receives the architectural surface pass")

func _surface_values() -> Dictionary:
	var result := {}
	for identity: String in world.passage_region.CELLS:
		var cell: Node3D = world.passage_region.cell_nodes[identity]
		for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
			for index in draw.mesh.get_surface_count():
				var material := draw.get_surface_override_material(index) as ShaderMaterial
				if material == null: continue
				var values := {}
				for parameter: Dictionary in material.shader.get_shader_uniform_list():
					var value: Variant = material.get_shader_parameter(parameter.name)
					values[parameter.name] = value.resource_path if value is Resource else value
				result["%s/%s/%d" % [identity, cell.get_path_to(draw), index]] = values
	return result
