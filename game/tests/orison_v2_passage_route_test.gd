extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## One player, street crossing, arcade doorway and actual hardware purchase.

func _init() -> void:
	route_label = "V2 PASSAGE ROUTE"

func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _prepared_shop_id() -> String:
	return "keys_cut"


func _prepared_door_id() -> String:
	return "SITE_SHOP_DOOR_KEYS_CUT"


func _route_prepared() -> void:
	var passage := world.passage_region
	var shop := _prepared_shop_id()
	var identity := _prepared_door_id()
	var door: DoorProp = passage.doors.get(identity)
	if not _require(passage.uses_prepared_geometry() and door != null and door.width == 2.0
		and door.motion_leaves().size() == 2,
		"the prepared arcade retains the native two-leaf shop door"): return
	await get_tree().create_timer(passage.residency.DORMANCY_GRACE_SECONDS+.1).timeout
	# Use the actual easy-motion doorway contract at the house entrance.
	for point: Vector3 in [Vector3(1.925,0,-6.5),Vector3(0,0,-7.65),Vector3(0,0,-10.2),Vector3(0,0,-12.2)]:
		if not await _walk(point): return
	var outward := [Vector3(0,0,3),Vector3(14,0,3),Vector3(14,0,4.2),Vector3(14,-.1,8),
		Vector3(14,-.1,13.6),Vector3(14,0,15),Vector3(14,0,17.3),Vector3(14,0,20),
		Vector3(14,0,27.5),Vector3(14,0,32)]
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	var residency: Dictionary = passage.residency.snapshot()
	if not _require(residency.state == "RESIDENT" and residency.load_cycles >= 1 and residency.unload_cycles >= 1
		and passage.doors[identity] == door, "walking the original house and street retires and reloads the arcade with the same door"): return
	var cell: Node3D = passage.cell_nodes.get("shop_" + shop)
	if not _require(cell != null and cell.has_meta("arcade_retained_shop_admitted"),
		"the occupied arcade mounts the selected shop's retained fittings"): return
	await _capture("prepared_nave",passage.to_global(Vector3(14,2.8,58)))
	# A door facing down the aisle has its turning pocket beyond the last cart.
	# Side doors can use the wider approach across the aisle.
	var normal := door.global_basis.z
	var stand_off := 1.0 if absf(normal.z) > absf(normal.x) else 1.8
	var approach := door.to_global(Vector3(door.width * .5,0,stand_off))
	var aisle := Vector3(14,0,approach.z)
	for point: Vector3 in [aisle, approach, door.to_global(Vector3(door.width * .5,0,-1.0))]:
		if not await _walk_world(point): return
	if not _require(door.open and door.motion_leaves().size() == 2,
		"walking in opens both fitted shop leaves"): return
	var records: Dictionary = world.household_state.snapshot().get("records",{})
	if not _require(records.get(identity,{}).get("value") == door.mechanism_snapshot(),
		"the original household mechanism identity captures the pair angle"): return
	if not await _prepared_trade(door): return
	if not await _walk_world(approach): return
	if not await _walk_world(aisle): return
	outward.reverse()
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	for point: Vector3 in [Vector3(0,0,-13.15),Vector3(0,0,-10.2),Vector3(0,0,-8.5),Vector3(1.925,0,-6.5)]:
		if not await _walk(point): return
	if not _require(door.open, "both shop leaves stay open after the player returns home"): return
	if OS.get_environment("ORISON_ARCADE_SAVE_AFTER_RELOAD") == "1":
		await _prepared_save_roundtrip(identity,door)

## Storage qualification uses a measured counter stance and a known partial
## angle. The full movement route independently covers street and shop access.
func _prepared_save_fixture() -> void:
	var identity := "SITE_SHOP_DOOR_KEYS_CUT"
	var door: DoorProp = world.passage_region.doors.get(identity)
	var counter: Node3D = world.shop_counters.get("keys_cut")
	if not _require(door != null and counter != null,"prepared control and Keys Cut counter mounted"): return
	door.restore_mechanism({"angle":PI/3})
	if not _require(door.open and door.motion_leaves().size() == 2,
		"snapshot fixture has a partially open physical pair"): return
	var stand := counter.to_global(Vector3(0,0,-.95))
	stand.y = .02
	player.global_position = stand
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if await _prepared_settle_blank(counter):
		await _prepared_save_roundtrip(identity,door)

func _prepared_save_roundtrip(identity: String, door: DoorProp) -> void:
	var original_path := RealityState.save_path
	var expected_angle := float(door.mechanism_snapshot().angle)
	var expected_cash := int(world.get_node("CaretakerEconomy").book().cash)
	var scratch := "user://tests/arcade_roundtrip_%d.json" % OS.get_process_id()
	if not _require(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests")) == OK
		and not FileAccess.file_exists(scratch),"fresh isolated disk-save destination"): return
	RealityState.save_path = scratch
	var written := RealityState.save_game()
	if not _require(written and FileAccess.file_exists(scratch),"normal household snapshot reaches the disk"):
		RealityState.save_path = original_path
		return
	var document := _read(scratch)
	var records: Dictionary = document.get("v2_household_controls",{}).get("records",{})
	var saved_angle: float = records.get(identity,{}).get("value",{}).get("angle",INF)
	if not _require(is_equal_approx(saved_angle,expected_angle)
		and not records.has("ARCADE_STOCK_DOOR_KEYS_CUT"),"disk document keeps the original storefront angle and mechanism ID"):
		RealityState.save_path = original_path
		return
	if not _require(document.get("keys_book",{}).get("paid",{}).get("2A",false)
		and not document.get("door_keys",{}).has("copies"),"disk document retains the paid blank in the current key schema"):
		RealityState.save_path = original_path
		return

	var replacement := _instantiate_world()
	if not _require(replacement != null,"fresh prepared runtime can reconstruct the saved world"):
		RealityState.save_path = original_path
		return
	var retired: WeakRef = weakref(door)
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	world = replacement
	await get_tree().process_frame
	_require(retired.get_ref() == null,"original door and world were released before continuing")

	RealityState.reset_campaign_for_tests()
	_require(not KeysSales.waiting().has("2A"),"fresh in-memory state does not retain the purchased blank")
	RealityState.load_game()
	var scene_requests: Array[String] = []
	GameBoot.set_scene_change_for_tests(func(path: String) -> Error:
		scene_requests.append(path)
		return OK)
	var admitted := GameBoot.begin_game(GameBoot.LaunchMode.CINEMATIC,false)
	GameBoot.set_scene_change_for_tests(Callable())
	var loaded := RealityState.load_status()
	RealityState.save_path = original_path
	_require(admitted and loaded.status == "loaded" and scene_requests == [GameBoot.GAME_SCENE],
		"normal Continue gate admits the actual reloaded disk campaign")
	add_child(world)
	if not _require(not world.startup_failed and world.player != null
		and not world.household_state._blocked,"fresh composed world accepts the saved household"):
		return
	if OS.get_environment("ORISON_ARCADE_EXPECT_FIRST_LOAD") == "baked" and not _require(
		world.passage_region.started_from_bake, "Continue uses verified baked geometry on first mount"): return
	player = world.player
	await get_tree().physics_frame
	var restored: DoorProp = world.passage_region.doors.get(identity)
	if not _require(restored != null and restored.open and restored.motion_leaves().size() == 2,
		"Continue reconstructs the paired storefront under its original identity"): return
	var leaves := restored.motion_leaves()
	_require(is_equal_approx(leaves[0].body.rotation.y,expected_angle)
		and is_equal_approx(leaves[1].body.rotation.y,-expected_angle),
		"Continue restores both physical leaf angles from one saved record")
	_require(KeysSales.waiting().has("2A") and not DoorKeyring.book().copies.has("2A")
		and int(world.get_node("CaretakerEconomy").book().cash) == expected_cash,
		"Continue preserves one paid blank and the exact cash without cutting a key or charging again")

func _prepared_trade(door: DoorProp) -> bool:
	var passage := world.passage_region
	var service_points: Dictionary = world.shop_counters
	var counter: Node3D = service_points.keys_cut
	var fitted := passage.shop_fitting("shop_keys_cut","LocksmithFittings")
	var top := fitted.find_child("*counter__countertop",true,false) as MeshInstance3D if fitted != null else null
	if not _require(top != null,"the relocated Keys Cut countertop is loaded"): return false
	var bounds: AABB = top.global_transform * top.mesh.get_aabb()
	var at := counter.global_position
	if not _require(absf(at.y-bounds.end.y)<.001
		and at.x>bounds.position.x and at.x<bounds.end.x and at.z>bounds.position.z and at.z<bounds.end.z,
		"Keys Cut terminal rests on the moved physical countertop"): return false
	var stand := counter.to_global(Vector3(0,0,-.95))
	stand.y = 0
	var inside := door.to_global(Vector3(1,0,-1.62))
	for point: Vector3 in [inside,Vector3(inside.x,0,stand.z),stand]:
		if not await _walk_world(point): return false
	if not await _prepared_settle_blank(counter): return false
	await _capture("prepared_keys_settled",counter.global_position + Vector3.UP*.1)
	for point: Vector3 in [Vector3(inside.x,0,stand.z),inside]:
		if not await _walk_world(point): return false
	return true

func _prepared_settle_blank(counter: Node3D) -> bool:
	var economy := world.get_node("CaretakerEconomy")
	economy.book().cash = 300
	if not _require(not DoorKeyring.request_copy("mina_vale").is_empty(),"tenant permission still reaches the moved counter"): return false
	counter.refresh_list()
	var spare: int = counter.item_ids.find("spare_2A")
	if not _require(spare >= 0,"original Keys Cut quote appears at the new position"): return false
	counter.select(spare)
	if not world.service_set_carrier.radio_is_powered():
		Input.action_press("radio_toggle")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("radio_toggle")
		await get_tree().physics_frame
	var hand := preload("res://tests/v2_fire_maintenance_hand_bench.gd").new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	var paid: bool = await hand._stroke(counter.terminal,counter.terminal.TRAVEL)
	hand.free()
	if not _require(paid and counter.flag.text == "SETTLED" and int(economy.book().cash) == 300 - KeysSales.SPARE_CENTS
		and KeysSales.waiting().has("2A") and not DoorKeyring.book().copies.has("2A"),
		"real lever settles exactly one spare blank through the original cash and key owners"): return false
	return true

func _route() -> void:
	if world.passage_region != null and world.passage_region.uses_prepared_geometry():
		route_label = "V2 EXPANDED ARCADE ROUTE"
		if OS.get_environment("ORISON_ARCADE_EXPECT_FIRST_LOAD") == "baked" and not _require(
			world.passage_region.started_from_bake, "production first mount uses verified baked geometry"): return
		if OS.get_environment("ORISON_ARCADE_SAVE_ROUNDTRIP") == "1":
			await _prepared_save_fixture()
		else:
			await _route_prepared()
		return
	var passage := world.passage_region
	if not _require(passage != null and not passage.startup_failed
			and passage.cell_nodes.has("gateway") and passage.shop_service == world.shop_service,
			"arcade composes in the same production world"): return
	if not _require(world.shop_service.inventory == world.maintenance_inventory
			and world.shop_service.work_orders == world.work_orders
			and not world.shop_service.stock_record("carbon_transmitter_capsule").is_empty(),
			"hardware stock uses initialized shared authorities"): return
	# This route explicitly qualifies a reconstruction, not a brief core transit.
	await get_tree().create_timer(passage.residency.DORMANCY_GRACE_SECONDS+.1).timeout
	if not await _leave_front_entrance():return
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
	# Stand clear of the leaf's outward sweep into the arcade before grabbing it.
	for point in [Vector3(14, 0, door_center.z), Vector3(12.75, 0, door_center.z)]:
		if not await _walk_world(point): return
	if not await _use(door, door.to_global(Vector3(door.width*0.5, 1.15, 0)), "hardware_door"): return
	await get_tree().create_timer(0.6).timeout
	if not _require(door.open, "hardware door opens through ordinary input"): return
	if not await _walk_world(Vector3(10.8, 0, door_center.z)): return
	# Step through the source opening and close the leaf using its real
	# panel before turning north along the fitted customer counter aisle.
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
	if not _check_requisition_duplicate_refusal():return
	if not _require(var_to_bytes(RealityState.data.maintenance_items) == saved_items,
			"duplicate refusal preserves the exact acquired inventory"): return
	for point in [Vector3(9.7, 0, door_center.z)]:
		if not await _walk_world(point): return
	if not await _use(door, door._body.to_global(Vector3(door.width*0.5, 1.15, 0)), "hardware_door_exit"): return
	await get_tree().create_timer(0.6).timeout
	for point in [Vector3(10.8, 0, door_center.z), Vector3(12.8, 0, door_center.z), Vector3(14, 0, door_center.z)]:
		if not await _walk_world(point): return
	outward.reverse()
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	# The slow closer can finish while the customer visits the hardware shop.
	# Reopen the real front leaf from its exterior stance before returning.
	if not await _walk(Vector3(0,0,-13.15)):return
	if not await _open_front_entrance():return
	for point in [Vector3(0, 0, -10.2), Vector3(0, 0, -8.5), Vector3(1.925, 0, -6.5)]:
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

func _use(owner_node: Node3D,target: Vector3,label: String) -> bool:
	if owner_node is MaintenanceShopCounter:
		# V2 retains this semantic owner with collision disabled. The native
		# radio terminal lever owns actual input and delegates settlement.
		var terminal: Node3D=world.fire_maintenance_counter.terminals.carbon_transmitter_capsule
		if not world.service_set_carrier.radio_is_powered():
			Input.action_press("radio_toggle")
			await get_tree().physics_frame;await get_tree().physics_frame
			Input.action_release("radio_toggle")
			await get_tree().physics_frame
		if not _require(world.service_set_carrier.radio_is_powered(),"actual radio input powers the requisition carrier"):return false
		var hand:=RouteHand.new()
		add_child(hand);hand.player=player;player.set_mouse_released(false)
		var moved: bool=await hand.operate(terminal.lever.to_global(Vector3(0,.094,-.025)),terminal.TRAVEL,terminal)
		var follows: bool=hand.follows_cursor
		hand.free()
		return _require(moved and follows,"actual grab, mouse motion and release settle the native requisition lever: "+label)
	if owner_node is DoorProp:
		var door:=owner_node as DoorProp
		# Use the exposed original hinge stile from both sides of the native leaf.
		target=door._body.to_global(Vector3(.065,1.35,door._hinge_offset+.0275))
		# RUL-018: a full-size leaf answers a click; there is no grip to drag.
		return await _hand_door(door,target,label)
	return await super._use(owner_node,target,label)

func _check_requisition_duplicate_refusal() -> bool:
	# Pure negative-control assertion, separate from timed traversal. Successful
	# acquisition above still requires actual mouse input through the lever.
	return _require(not world.shop_service.acquire("carbon_transmitter_capsule", "hardware_paint")
		and world.fire_maintenance_counter.terminals.carbon_transmitter_capsule.grip().is_empty(),
		"settled requisition refuses duplicates and retires the exact lever target")
