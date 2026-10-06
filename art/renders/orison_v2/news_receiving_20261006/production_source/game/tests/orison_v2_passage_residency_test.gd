extends "res://tests/orison_v2_passage_route_test.gd"

var _moved_cart: PassagePushcart
var _initial_cart_position: Vector3
var _surface_signature: Dictionary = {}
var _receiver_signature: Dictionary = {}

func _init() -> void:
	route_label = "V2 PASSAGE RESIDENCY"

func _capture(identity: String, target: Vector3) -> void:
	await super._capture(identity, target)
	if identity != "nave": return
	if not _check_specialist_fittings():return
	_receiver_signature = _receiver_values()
	if not _require(_receiver_signature.size()==7,"all seven passage receiving actors exist before reconstruction"):return
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
	_require(_receiver_values()==_receiver_signature,
			"geometry reconstruction preserves the same seven receiving owners")
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

func _check_specialist_fittings() -> bool:
	# Both observed reconstruction cycles must carry the same native owners
	# as startup, rather than quietly reverting to retired source boxes.
	for spec: Array in [
		["shop_funeral_parlour","FuneralFittings","funeral_fittings"],
		["shop_funeral_parlour","FuneralDrapes","funeral_drapes"],
		["shop_funeral_parlour","FuneralFoliage","funeral_foliage"],
		["shop_radio_service","RadioBench","radio_bench"],
		["shop_radio_service","RadioApparatus","radio_apparatus"],
		["shop_radio_service","RadioStock","radio_stock"],
		["shop_radio_service","RadioBattery","radio_battery"],
		["shop_radio_service","RadioWire","radio_wire"],
		["shop_radio_service","RadioDisplay","radio_display"]]:
		var cell: Node3D=world.passage_region.cell_nodes[spec[0]]
		var model:=cell.get_node_or_null(str(spec[1])) as Node3D
		if not _require(model!=null,"reloaded native owner exists: "+str(spec[1])):return false
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_"+str(spec[2])+".json"))
		if not _require(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"reloaded native source export binds: "+str(spec[1])):return false
		var retired: Dictionary=model.get_meta("removed_triangles")
		var expected: Dictionary=fixture.runtime.cells.filter(func(row):return row.id==spec[0])[0]
		for box: Dictionary in expected.replace:
			if not _require(int(retired.get(box.id,-1))==int(box.expected_triangles),"reloaded source boundary stays retired: "+str(box.id)):return false
		var draws:=model.find_children("*","MeshInstance3D",true,false)
		if not _require(draws.size()==fixture.parts.size(),"reloaded native partitions remain: "+str(spec[1])):return false
		for draw: MeshInstance3D in draws:
			var shapes:=draw.find_children("*","CollisionShape3D",true,false)
			if not _require(shapes.size()==1 and shapes[0].shape is ConcavePolygonShape3D and shapes[0].shape.get_faces()==draw.mesh.get_faces() and shapes[0].global_transform.is_equal_approx(draw.global_transform),"reloaded native visible/physical faces agree: "+str(draw.name)):return false
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
	return true

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
