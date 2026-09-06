extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## One player, street crossing, arcade doorway and actual hardware purchase.

func _init() -> void:
	route_label = "V2 PASSAGE ROUTE"

func _route() -> void:
	var passage := world.passage_region
	if not _require(passage != null and not passage.startup_failed
			and passage.cell_nodes.has("gateway") and passage.shop_service == world.shop_service,
			"arcade composes in the same production world"): return
	if not _require(world.shop_service.inventory == world.maintenance_inventory
			and world.shop_service.work_orders == world.work_orders
			and not world.shop_service.stock_record("carbon_transmitter_capsule").is_empty(),
			"hardware stock uses initialized shared authorities"): return
	for point in [Vector3(2.3, 0, -6.5), Vector3(0, 0, -8.5),
			Vector3(0, 0, -10.2), Vector3(0, 0, -12.2)]:
		if not await _walk(point): return
	var outward := [Vector3(0, 0, 3), Vector3(14, 0, 3), Vector3(14, 0, 4.2),
		Vector3(14, -0.1, 8), Vector3(14, -0.1, 13.6), Vector3(14, 0, 15),
		Vector3(14, 0, 17.3), Vector3(14, 0, 20), Vector3(14, 0, 27.5),
		Vector3(14, 0, 32)]
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	var residency: Dictionary = passage.residency.snapshot()
	print("RESIDENCY_AT_NAVE ", JSON.stringify(residency))
	if not _require(residency.state == "RESIDENT" and residency.load_cycles >= 1
			and residency.unload_cycles >= 1, "arcade geometry reloads asynchronously after leaving the core"): return
	await _capture("nave", passage.to_global(Vector3(14, 2.5, 63)))
	var door: DoorProp = passage.doors.get("SITE_SHOP_DOOR_HARDWARE_PAINT")
	if not _require(door != null, "authored hardware shop door exists"): return
	var door_center := door.to_global(Vector3(door.width*0.5, 0, 0))
	for point in [Vector3(14, 0, door_center.z), Vector3(12.4, 0, door_center.z)]:
		if not await _walk_world(point): return
	if not await _use(door, door.to_global(Vector3(door.width*0.5, 1.15, 0)), "hardware_door"): return
	await get_tree().create_timer(0.6).timeout
	if not _require(door.open, "hardware door opens through ordinary input"): return
	if not await _walk_world(Vector3(10.8, 0, door_center.z)): return
	# The inward leaf occupies the narrow customer aisle while open. Step
	# beyond its sweep and close it using the real panel before turning north.
	if not await _walk_world(Vector3(9.7, 0, door_center.z)): return
	if not await _use(door, door._body.to_global(Vector3(door.width*0.5, 1.15, 0)), "hardware_door_close"): return
	await get_tree().create_timer(0.6).timeout
	if not _require(not door.open, "customer closes the inward leaf before passing the counter"): return
	var counter := world.shop_service.counter("hardware_paint")
	if not _require(counter != null, "actual source-anchored hardware counter exists"): return
	# The public end of the counter is accessible from the door's turning
	# space. Its long front is separated by the fitted display furniture.
	if not await _walk_world(Vector3(counter.global_position.x, 0, door_center.z-0.18)): return
	var counter_target := counter.global_position + Vector3(0, 0.12, 1.2)
	if not _prepare_procurement(): return
	if not _require(world.shop_service.pending_item("hardware_paint") == "carbon_transmitter_capsule",
			"right shop offers the awaited part"): return
	if not await _use(counter, counter_target, "hardware_counter"): return
	if not _require(not world.maintenance_inventory.item_state("carbon_transmitter_capsule").is_empty()
			and world.shop_service.pending_item("hardware_paint").is_empty(),
			"physical counter grants the part exactly once"): return
	var saved_items := var_to_bytes(RealityState.data.maintenance_items)
	if not await _use(counter, counter_target, "hardware_counter_repeat"): return
	if not _require(var_to_bytes(RealityState.data.maintenance_items) == saved_items,
			"repeated counter input cannot duplicate the part"): return
	for point in [Vector3(9.7, 0, door_center.z)]:
		if not await _walk_world(point): return
	if not await _use(door, door._body.to_global(Vector3(door.width*0.5, 1.15, 0)), "hardware_door_exit"): return
	await get_tree().create_timer(0.6).timeout
	for point in [Vector3(10.8, 0, door_center.z), Vector3(12.4, 0, door_center.z), Vector3(14, 0, door_center.z)]:
		if not await _walk_world(point): return
	outward.reverse()
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	for point in [Vector3(0, 0, -10.2), Vector3(0, 0, -8.5), Vector3(2.3, 0, -6.5)]:
		if not await _walk(point): return
	_require(var_to_bytes(RealityState.data.maintenance_items) == saved_items,
			"return indoors retains the physically acquired part")

func _capture(identity: String, target: Vector3) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	player.camera.look_at(target)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity+".png"))

func _prepare_procurement() -> bool:
	var job := "vantry_chirp_2a"
	var orders := world.work_orders
	return _require(orders.issue_job(job, "reported") and orders.acknowledge_job(job)
			and orders.diagnose_job(job) and orders.mark_job_awaiting_part(job),
			"maintenance job awaits authored capsule")
