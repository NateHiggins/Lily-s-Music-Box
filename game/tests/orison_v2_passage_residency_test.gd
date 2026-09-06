extends "res://tests/orison_v2_passage_route_test.gd"

var _moved_cart: PassagePushcart
var _initial_cart_position: Vector3
var _surface_signature: Dictionary = {}

func _init() -> void:
	route_label = "V2 PASSAGE RESIDENCY"

func _capture(identity: String, target: Vector3) -> void:
	await super._capture(identity, target)
	if identity != "nave": return
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
	if not await _walk(Vector3(2.3, 0, -3.5)): return
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
	for point in [Vector3(2.3, 0, -6.5), Vector3(0, 0, -8.5), Vector3(0, 0, -10.2)]:
		if not await _walk(point): return
	var started := Time.get_ticks_msec()
	while passage.residency.state == "LOADING" and Time.get_ticks_msec()-started < 5000:
		await get_tree().process_frame
	var resumed: Dictionary = passage.residency.snapshot()
	print("RESIDENCY_RESUMED ", JSON.stringify(resumed))
	if not _require(resumed.state == "RESIDENT" and resumed.cell_count == 13
			and resumed.load_cycles >= 2 and resumed.unload_cycles >= 2,
			"vestibule prefetch reconstructs a second geometry cycle"): return
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
