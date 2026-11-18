extends "res://tests/orison_v2_vertical_route_test.gd"
## Same live movement driver, starting inside the actual connected V2 root.

func _init() -> void:
	route_label = "V2 BODEGA RECEIVING ROUTE"

func _scope() -> String:
	return OS.get_environment("ORISON_BODEGA_ROUTE_SCOPE")

func _prepare_player_start() -> void:
	var scope := _scope()
	if scope.is_empty():
		super._prepare_player_start()
		return
	var route: Dictionary = world.exterior_cell.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	player.global_position = route.nodes[3 if scope == "storefront" else 0].placement.position
	player.velocity = Vector3.ZERO

func _route() -> void:
	var exterior := world.exterior_cell
	var cell = exterior.instance_node("SHOP_BODEGA")
	var receiving = exterior.interaction_leaf("SHOP_BODEGA_RECEIVING_LEAF")
	var room = world.get_node("BodegaReceiving")
	if not _require(not room.startup_failed and room.global_transform.is_equal_approx(cell.global_transform),
			"receiving room uses the actual registered bodega frame"):return
	if not _require(receiving != null and receiving.get_parent()==cell,
			"existing exterior owner mounts one semantic receiving leaf"):return
	var meshes=room.find_children("*","MeshInstance3D",true,false)
	if not _require(meshes.size()==6,"six mapped receiving partitions compose"):return
	for draw in meshes:
		var key=str(draw.name).split("__")[-1]
		if not _require(MatLib.SETS.has(key) and draw.material_override.albedo_texture!=null,
				"valid runtime texture mapping for "+key):return
		for surface in draw.mesh.get_surface_count():
			var arrays=draw.mesh.surface_get_arrays(surface)
			if not _require(arrays[Mesh.ARRAY_TEX_UV].size()>0 and arrays[Mesh.ARRAY_NORMAL].size()>0
					and arrays[Mesh.ARRAY_TANGENT].size()>0,"active UVs normals tangents for "+key):return
	for sample in [[Vector3(.65,.35,-11.65),Vector3(.65,-.35,-11.65)],
			[Vector3(-1.5,1.5,-11.6),Vector3(-2.5,1.5,-11.6)],
			[Vector3(1.5,1.5,-11.6),Vector3(2.5,1.5,-11.6)],
			[Vector3(.65,1.5,-12.2),Vector3(.65,1.5,-13)],
			[Vector3(.65,2.9,-11.65),Vector3(.65,3.5,-11.65)],
			[Vector3(-1.5,1.3,-11.8),Vector3(-1.5,.6,-11.8)]]:
		var ray=PhysicsRayQueryParameters3D.create(cell.to_global(sample[0]),cell.to_global(sample[1]))
		ray.exclude=[player.get_rid()]
		var hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not _require(not hit.is_empty() and room.is_ancestor_of(hit.collider),
				"receiving owner supplies fitted structural contact "+str(sample[0])):return
	if not _require(exterior.player == player and exterior.work_orders == world.work_orders
			and exterior.maintenance_inventory == world.maintenance_inventory
			and exterior.shop_service == world.shop_service
			and world.shop_service.inventory == world.maintenance_inventory
			and world.shop_service.work_orders == world.work_orders, "shared world authorities"): return
	if not _require(world.shop_service.stock_record("carbon_transmitter_capsule").get("shop_id") == "hardware_paint",
			"shared service loads the actual authored hardware stock"): return
	var scope := _scope()
	if not _require(scope in ["", "street", "storefront"], "known route scope"): return
	if scope.is_empty() and not await _leave_front_entrance():return
	var outbound: Dictionary = exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	var returning: Dictionary = exterior.route("ROUTE_SHOP_BODEGA_TO_ORISON")
	if not _require(outbound.get("nodes", []).size() == 5 and returning.get("nodes", []).size() == 5,
			"both semantic routes resolve"): return
	for record: Dictionary in outbound.nodes.slice(3 if scope == "storefront" else 0, 4):
		if not await _walk_world(record.placement.position): return
	var door := exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
	if not _require(door != null and not door.open, "shop starts with a real closed leaf"): return
	if not await _walk_world(outbound.nodes[4].placement.position): return
	if not _require(door.is_ready_for_passage(), "ordinary movement opened both storefront leaves and left them open"): return
	if not await _verify_storefront_save(door): return
	var stance: Dictionary = exterior.spatial_resolver.resolve_placement("SHOP_BODEGA", "service_stance")
	if not await _walk_world(stance.position): return
	var route_placements=["delivery_aisle_entry","delivery_aisle_center","delivery_aisle_end","delivery_turn","receiving_before"]
	for identity in route_placements:
		var position=exterior.spatial_resolver.resolve_placement("SHOP_BODEGA",identity)
		if not await _walk_world(position.position):return
	if not await _use(receiving,receiving.to_global(Vector3(.475,1.15,0)),"receiving_open"):return
	await get_tree().create_timer(.6).timeout
	var arrival=exterior.spatial_resolver.resolve_placement("SHOP_BODEGA","receiving_arrival")
	if not await _walk_world(arrival.position):return
	player.camera.look_at(cell.to_global(Vector3(-1.4,1.1,-11.4)))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("receiving_inside.png"))
	# The arrival stance lies in the closing sweep. Move to the jamb side
	# where the click can close the receiving leaf without hitting the player.
	var hinge: Vector3 = receiving._body.global_position
	var along: Vector3 = receiving.global_basis.x.normalized()
	var opened: Vector3 = receiving._body.global_basis.x
	var into_room: Vector3 = (opened - along * opened.dot(along)).normalized()
	var clear: Vector3 = hinge + along * (receiving.width + .5) + into_room * .6
	clear.y = player.global_position.y
	if not await _walk_world(clear):return
	var edge := [receiving._body.to_global(Vector3(receiving.width * .8, 1.15, -.026)),
			receiving._body.to_global(Vector3(receiving.width * .8, 1.15, .026))]
	edge.sort_custom(func(a: Vector3, b: Vector3): return a.distance_to(clear) < b.distance_to(clear))
	if not await _use(receiving,edge[0],"receiving_close_inside"):return
	await get_tree().create_timer(.6).timeout
	if not _require(not receiving.open,"receiving door closes from its supported room"):return
	if not await _use(receiving,receiving.to_global(Vector3(.475,1.15,0)),"receiving_reopen_inside"):return
	await get_tree().create_timer(.6).timeout
	route_placements.reverse()
	for identity in route_placements:
		var position=exterior.spatial_resolver.resolve_placement("SHOP_BODEGA",identity)
		if not await _walk_world(position.position):return
	if not await _walk_world(stance.position):return
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
	for record: Dictionary in returning.nodes.slice(0, 2 if scope == "storefront" else returning.nodes.size()):
		if not await _walk_world(record.placement.position): return
	if scope == "storefront":
		var right: AnimatableBody3D = door.motion_leaves()[1].body
		if not await _click_door(door, right.to_global(Vector3(-.45,1.15,0)), "right storefront leaf closes both leaves"): return
		if not _require(is_zero_approx(right.rotation.y) and is_zero_approx(door._body.rotation.y), "both leaves meet after the right-side click"): return
	if scope.is_empty():
		for point in [Vector3(0, 0, -10.2), Vector3(0, 0, -8.5), Vector3(1.925, 0, -6.5)]:
			if not await _walk(point): return
	_require(world.work_orders.job_state(job) == job_before, "return route retains the same job owner and facts")

func _verify_storefront_save(door: DoorProp) -> bool:
	var directory := OS.get_environment("SHOT_DIR")
	if not _require(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK,
			"storefront save check has an isolated report directory"): return false
	var previous_path := RealityState.save_path
	var path := directory.path_join("bodega_storefront_campaign.json")
	if not _require(not FileAccess.file_exists(path), "storefront test will create a fresh campaign file"): return false
	var angle: float = door.mechanism_snapshot().angle
	var identity := String(door.name)
	RealityState.save_path = path
	var wrote := RealityState.save_game()
	var record: Dictionary = RealityState.data.get(world.household_state.KEY, {}).get("records", {}).get(identity, {})
	var captured: bool = record.get("kind") == "mechanism" and record.get("value", {}) == {"angle": angle}
	if wrote and captured:
		door.restore_mechanism({"angle": 0.0})
		RealityState.load_game()
	RealityState.save_path = previous_path
	if not _require(wrote and captured and RealityState.can_continue(), "campaign storage saves and validates the original storefront identity and one angle"): return false
	await get_tree().physics_frame
	var leaves := door.motion_leaves()
	return _require(door.is_ready_for_passage() and is_equal_approx(leaves[0].body.rotation.y,angle)
		and is_equal_approx(leaves[1].body.rotation.y,-angle), "disk load restores matching opposite angles and live passage readiness")

func _walk_world(target: Vector3) -> bool:
	return await _walk(world.adapter.root.to_local(target))

func _open_apartment_door(identity: String) -> bool:
	var opening := world.adapter.resolve(identity) as Node3D
	var door := opening.get_node_or_null(identity + "_Leaf") as DoorProp if opening != null else null
	if not _require(door != null, "physical apartment door exists: " + identity): return false
	if not await _wait_for_door(door): return false
	if door.open: return true
	if not await _use(door, door.to_global(Vector3(door.width * .5, 1.1, 0)), identity + "_open"): return false
	if not await _wait_for_door(door): return false
	return _require(door.is_ready_for_passage(), "apartment door opens through player input: " + identity)

func _wait_for_door(door: DoorProp) -> bool:
	# Residents use the same leaf. Observe its real tween rather than assume
	# it was stationary on arrival or that an opening always takes .6 seconds.
	for frame in 180:
		await get_tree().physics_frame
		if not door._moving: return true
	return _require(false, "door motion did not settle: " + str(door.name))

func _require(ok: bool, label: String) -> bool:
	print("CONNECTED EXTERIOR CHECK: ", label, " = ", ok)
	if not ok:
		failures.append(label)
		push_error(route_label + ": " + label)
	return ok

func _use(owner_node: Node3D, target: Vector3, label: String) -> bool:
	if owner_node is DoorProp:
		return await _click_door(owner_node as DoorProp, target, label)
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

## Exercise the actual click dispatch for traversable doors (RUL-018).
func _click_door(leaf: DoorProp, target: Vector3, label: String) -> bool:
	var was_open := leaf.open
	player.set_mouse_released(false)
	player.camera.look_at(target)
	await get_tree().physics_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame
	if not await _wait_for_door(leaf): return false
	return _require(leaf.open != was_open and not player._grab.active(), "primary click operates the actual door: " + label)
