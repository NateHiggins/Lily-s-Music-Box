extends "res://tests/orison_v2_vertical_route_test.gd"
## Same live movement driver, starting inside the actual connected V2 root.

func _init() -> void:
	route_label = "CONNECTED EXTERIOR ROUTE"

func _route() -> void:
	var exterior := world.exterior_cell
	if not _require(exterior.player == player and exterior.work_orders == world.work_orders
			and exterior.maintenance_inventory == world.maintenance_inventory
			and exterior.shop_service == world.shop_service
			and world.shop_service.inventory == world.maintenance_inventory
			and world.shop_service.work_orders == world.work_orders, "shared world authorities"): return
	if not _require(world.shop_service.stock_record("carbon_transmitter_capsule").get("shop_id") == "hardware_paint",
			"shared service loads the actual authored hardware stock"): return
	for point in [Vector3(2.3, 0, -6.5), Vector3(0, 0, -8.5),
			Vector3(0, 0, -10.2), Vector3(0, 0, -12.2)]:
		if not await _walk(point): return
	var outbound: Dictionary = exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	var returning: Dictionary = exterior.route("ROUTE_SHOP_BODEGA_TO_ORISON")
	if not _require(outbound.get("nodes", []).size() == 5 and returning.get("nodes", []).size() == 5,
			"both semantic routes resolve"): return
	for record: Dictionary in outbound.nodes.slice(0, 4):
		if not await _walk_world(record.placement.position): return
	var door := exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
	if not _require(door != null and not door.open, "shop starts with a real closed leaf"): return
	if not await _use(door, door.to_global(Vector3(door.width * 0.5, 1.15, 0)), "door"): return
	await get_tree().create_timer(0.6).timeout
	if not _require(door.open, "real storefront opens through input"): return
	if not await _walk_world(outbound.nodes[4].placement.position): return
	var stance: Dictionary = exterior.spatial_resolver.resolve_placement("SHOP_BODEGA", "service_stance")
	if not await _walk_world(stance.position): return
	var orders := world.work_orders
	var job := "vantry_chirp_2a"
	if not _require(orders.issue_job(job, "reported") and orders.acknowledge_job(job)
			and orders.diagnose_job(job) and orders.mark_job_awaiting_part(job),
			"existing maintenance job awaits its authored part"): return
	var items_before := var_to_bytes(RealityState.data.maintenance_items)
	var job_before: Dictionary = orders.job_state(job).duplicate(true)
	var counter := exterior.service_counter("SHOP_BODEGA")
	if not await _use(counter, counter.global_position + Vector3.UP * 0.12, "counter"): return
	if not _require(items_before == var_to_bytes(RealityState.data.maintenance_items)
			and orders.job_state(job) == job_before and world.shop_service.pending_item("SHOP_BODEGA").is_empty(),
			"bodega cannot supply the hardware shop's part or mutate shared inventory"): return
	for record: Dictionary in returning.nodes:
		if not await _walk_world(record.placement.position): return
	for point in [Vector3(0, 0, -10.2), Vector3(0, 0, -8.5), Vector3(2.3, 0, -6.5)]:
		if not await _walk(point): return
	_require(world.work_orders.job_state(job) == job_before, "interior return retains the same job owner and facts")

func _walk_world(target: Vector3) -> bool:
	return await _walk(world.adapter.root.to_local(target))

func _open_apartment_door(identity: String) -> bool:
	var opening := world.adapter.resolve(identity) as Node3D
	var door := opening.get_node_or_null(identity + "_Leaf") as DoorProp if opening != null else null
	if not _require(door != null, "physical apartment door exists: " + identity): return false
	if door.open: return true
	if not await _use(door, door.to_global(Vector3(door.width * .5, 1.1, 0)), identity + "_open"): return false
	await get_tree().create_timer(.6).timeout
	return _require(door.open, "apartment door opens through player input: " + identity)

func _require(ok: bool, label: String) -> bool:
	print("CONNECTED EXTERIOR CHECK: ", label, " = ", ok)
	if not ok:
		failures.append(label)
		push_error(route_label + ": " + label)
	return ok

func _use(owner_node: Node3D, target: Vector3, label: String) -> bool:
	player.camera.look_at(target)
	await get_tree().process_frame
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	var hit_node := hit.get("collider") as Node
	var matched := false
	while hit_node != null:
		if hit_node == owner_node: matched = true
		hit_node = hit_node.get_parent()
	player._update_prompt()
	if not matched or player._prompt.text.is_empty():
		print("INTERACTION_DIAGNOSTIC ", JSON.stringify({"label": label,
			"player": str(player.global_position), "camera": str(player.camera.global_position),
			"target": str(target), "forward": str(-player.camera.global_basis.z),
			"distance": player.camera.global_position.distance_to(target),
			"hit": str(hit.get("collider")), "prompt": player._prompt.text}))
	if not _require(matched and not player._prompt.text.is_empty(), "actual player ray/prompt reaches " + label): return false
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	await get_tree().process_frame
	Input.action_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().create_timer(0.15).timeout
	return true
