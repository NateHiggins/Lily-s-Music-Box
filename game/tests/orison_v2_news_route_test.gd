extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The papers in the production V2 root: out of the front door, along the
## arcade, through the News & Cigars door by hand, today's Record bought over
## the counter through the player's own ray and prompt, read, the day's
## then the kept paper on the 4B bookshelf.

const ARCADE_AISLE_X := 14.0             # the arcade centre line the passage route walks

func _init() -> void:
	route_label = "V2 NEWS ROUTE"

func _route() -> void:
	var passage := world.passage_region
	var catalog: NewspaperCatalog = world.newspapers
	if not _require(passage != null and not passage.startup_failed and catalog != null
			and catalog.errors.is_empty(), "arcade and newspaper catalogue are live"): return
	var stand := passage.get_node_or_null("PassageActors/NewsStand") as NewsRackProp
	if not _require(stand != null and not stand.shuttered(), "the news stand is mounted and open at 20:00"): return
	var today := catalog.today()
	if not _require(today == "1928-11-10", "the rack is on the campaign's first day (%s)" % today): return
	var door: DoorProp = passage.doors.get("SITE_SHOP_DOOR_NEWS_CIGARS")
	if not _require(door != null and door.leaf_state == "closed", "the News & Cigars door is closed, not locked"): return
	# Every point from the real objects: the door's own centre, the arcade's
	# centre line (the passage route walks x = 14), and the stand and its rack.
	var centre := door.to_global(Vector3(door.width * 0.5, 0.0, 0.0))
	var aisle := Vector3(ARCADE_AISLE_X, centre.y, centre.z)
	var inward := Vector3(centre.x - aisle.x, 0.0, 0.0).normalized()
	var venue := centre + inward * 0.9

	# Out of the front entrance (the passage prefetch begins at the vestibule),
	# wait for the arcade to be fully resident, then step to the shop: the
	# street crossing is the passage route's contract, not this one.
	if not await _leave_front_entrance(): return
	var resident := false
	for _frame in 1800:
		await get_tree().physics_frame
		if passage.residency != null and str(passage.residency.snapshot().state) == "RESIDENT":
			resident = true
			break
	print("[NEWS ROUTE] residency ", passage.residency.snapshot().state if passage.residency != null else "none")
	if not _require(resident, "the arcade is resident before the player enters it"): return
	player.global_position = Vector3(aisle.x, aisle.y + 0.02, aisle.z)
	player.velocity = Vector3.ZERO
	for _frame in 20:
		await get_tree().physics_frame
	if not _require(player.global_position.distance_to(aisle) < 0.4,
			"the player stands in the arcade aisle outside the shop (%s vs %s)" % [player.global_position, aisle]): return
	# Within reach of the leaf but clear of its sweep: this leaf swings out
	# into the arcade, so the customer stands back from it.
	var approach := centre - inward * 1.35
	if not await _walk_world(Vector3(approach.x, centre.y, approach.z)): return
	if not await _use(door, door.to_global(Vector3(door.width * 0.5, 1.15, 0)), "news_door"): return
	if not await _wait_for_door(door): return
	if not _require(door.open, "the shop door opens by hand"): return
	if not await _walk_world(Vector3(venue.x, centre.y, venue.z)): return
	# The customer stands in front of the counter, at its door end and clear of
	# the proprietor's stool further in, on the door's own centre line, which
	# runs about 0.8 m in front of the counter.
	var counter_stance := Vector3((venue.x + stand.global_position.x) * 0.5, centre.y, centre.z)
	if not await _walk_world(Vector3(counter_stance.x, centre.y, counter_stance.z)): return

	# Over the counter: the rack's offer, today's Record taken and read.
	if not await _use(stand, stand.global_position + Vector3.UP * 0.05, "news_counter"): return
	await get_tree().create_timer(0.3).timeout
	var chooser: CaseDialoguePanel = stand._chooser
	var offered := chooser.offered_labels()
	print("[NEWS ROUTE] offered ", offered)
	if not _require(chooser.attention_active() and player.call_locked
			and offered.size() == 3 and str(offered[0]).begins_with("The Borough Record, Sat 10 Nov"),
			"the counter offers both of today's papers and a way out"): return
	await _capture_now("news_counter_offer")
	chooser.choose(0)
	for _frame in 8:
		await get_tree().process_frame
	var reading := _open_paper()
	if not _require(reading != null and reading.paper_id == "record" and reading.date == today
			and catalog.is_collected("record", today), "taking the Record keeps it and opens it"): return
	await _capture_now("news_record_in_shop")
	reading.close()
	await get_tree().process_frame
	if not _require(not player.call_locked, "closing the paper hands the player back"): return

	# Home to 4B: the kept paper is on the player's own bookshelf.
	var shelf := world.get_node_or_null("ShelfPapers") as NewsRackProp
	if not _require(shelf != null, "the 4B bookshelf carries the kept papers"): return
	var side := await _stand_facing(shelf)
	if not _require(side != Vector3.ZERO, "the player can stand at the bookshelf and aim at it"): return
	if not await _use(shelf, shelf.global_position, "shelf_papers"): return
	for _frame in 8:
		await get_tree().process_frame
	var kept := _open_paper()
	if not _require(kept != null and kept._shelf.visible and kept._shelf.item_count == 1
			and kept.paper_id == "record" and kept.date == today,
			"the bookshelf lists the one kept paper and opens it"): return
	await _capture_now("shelf_papers")
	kept.close()


## Stand 0.9 m from the shelf on whichever horizontal side the player's ray
## reaches its papers control from; returns that offset, or ZERO.
func _stand_facing(target: Node3D) -> Vector3:
	var floor_y := target.global_position.y - 1.0
	for offset in [Vector3(0, 0, 0.9), Vector3(0, 0, -0.9), Vector3(0.9, 0, 0), Vector3(-0.9, 0, 0)]:
		player.global_position = Vector3(target.global_position.x + offset.x, floor_y + 0.02,
				target.global_position.z + offset.z)
		player.velocity = Vector3.ZERO
		for _frame in 4:
			await get_tree().physics_frame
		player.camera.look_at(target.global_position)
		await get_tree().process_frame
		var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
				player.camera.global_position - player.camera.global_basis.z * 2.1)
		ray.collide_with_areas = true
		ray.exclude = [player.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		var node := hit.get("collider") as Node
		if node != null and node.name == "PapersControl":
			return offset
	return Vector3.ZERO


func _use(owner_node: Node3D, target: Vector3, label: String) -> bool:
	if owner_node is DoorProp:
		var leaf := owner_node as DoorProp
		var hand := preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new()
		add_child(hand)
		hand.player = player
		player.set_mouse_released(false)
		# A storefront leaf swinging out meets its own shopfront a little short of
		# the nominal 100 degrees; 86 is a full walk-through opening.
		var moved: bool = await hand.operate(target, 0.0 if leaf.open else leaf.motion_target_angle(true) * 0.86, leaf)
		hand.free()
		return _require(moved, "actual grab, mouse motion and release: " + label)
	return await super._use(owner_node, target, label)


func _open_paper() -> NewspaperPanel:
	for node in get_tree().current_scene.get_children():
		if node is NewspaperPanel and not node.is_queued_for_deletion():
			return node
	return null


func _marker(identity: String) -> Dictionary:
	for floor: Dictionary in world.layout.get("floors", []):
		for marker: Dictionary in floor.get("markers", []):
			if str(marker.get("id", "")) == identity:
				return marker
	return {}


func _capture_now(identity: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))
