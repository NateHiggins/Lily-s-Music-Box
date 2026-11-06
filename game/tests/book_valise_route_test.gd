extends "res://tests/carried_case_route_test.gd"
## A real player hand, case input and isolated primary generation.

const Book := preload("res://scripts/props/v2_readable_book.gd")


func _init() -> void:
	route_label = "BOOK VALISE ROUTE"


func _route() -> void:
	var view: Node = world.carried_case_view
	var collections := get_tree().get_nodes_in_group("v2_library_collections")
	var copies: Array[Book] = []
	for collection: Node in collections:
		var by_title := {}
		for copy: Book in collection._books.values():
			if copy.opening != 0.0:
				continue
			if by_title.has(copy.title_id):
				copies = [by_title[copy.title_id], copy]
				break
			by_title[copy.title_id] = copy
		if not copies.is_empty():
			break
	if not _require(copies.size() == 2, "the installed nook supplies two physical copies of a title"):
		return
	var original := copies[0]
	var sibling := copies[1]
	var collection := str(original.shelf.name)
	var item := CarriedCase.library_item(collection, original.stock_id)
	var sibling_item := CarriedCase.library_item(collection, sibling.stock_id)
	var sibling_pose := sibling.transform
	var path := "user://book_valise_%s.save" % Time.get_ticks_usec()
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	if not _require(PersonInventory.carry_goods(PersonInventory.PLAYER, "route_tin", "Pipe tobacco", "tin") \
			and RealityState.save_game(), "the isolated primary contains ordinary goods"):
		return

	# Use a clear station near the normal runtime spawn. Setup moves the
	# original stock, then the ordinary player ray and click pick it up.
	var camera_pose := player.camera.global_transform
	original.global_transform = Transform3D(camera_pose.basis,
		camera_pose * Vector3(0.0, 0.0, -0.62) - camera_pose.basis * original.pickup_centre())
	original.shelf_slot = -1
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.use_primary_interaction()
	if not _require(player.held_stock_body() == original, "ordinary player ray takes the original copy"):
		return
	RealityState.flush_background_saves()
	var before := FileAccess.get_file_as_bytes(path)
	var fault := {"hits": 0}
	RealityState.storage_operation_override = func(stage: String, operation: String, arguments: Dictionary) -> Variant:
		if stage != "temp_write" or operation != "write" or arguments.get("path") != path + ".tmp":
			return null
		var bytes: PackedByteArray = arguments.bytes
		var candidate: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if candidate is not Dictionary or not candidate.get(CarriedCase.KEY, {}).get("places", {}).has(item):
			return null
		fault.hits += 1
		return {"ok":false, "error":ERR_FILE_CANT_WRITE}
	await _key(KEY_TAB)
	RealityState.storage_operation_override = Callable()
	if not _require(fault.hits == 1 and not view.opened and player.held_stock_body() == original \
			and original.visible and CarriedCase.place_of(item).is_empty() \
			and FileAccess.get_file_as_bytes(path) == before, "refused write retains the original hand and primary"):
		return

	await _key(KEY_TAB)
	await get_tree().create_timer(0.65).timeout
	if not _require(view.opened and view.settled and view._stacks.has(item) and original.valise_packed \
			and not original.visible and player.held_stock_body() == null \
			and sibling.visible and sibling.transform.is_equal_approx(sibling_pose) \
			and CarriedCase.place_of(sibling_item).is_empty(), "Tab packs only the original copy"):
		return
	await _capture_interaction("original_copy_in_valise")
	var place := CarriedCase.place_of(item).duplicate()
	var size := CarriedCase.form_size(str(place.form), bool(place.turned))
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(place.y) + size.y * 0.5))
	var tin := CarriedCase.place_of("route_tin")
	await _press(_screen(view, float(tin.x) + 0.5, float(tin.y) + 0.5))
	if not _require(view.held_item == item and CarriedCase.place_of(item) == place,
			"ordinary goods refuse an occupied placement and keep the book in the case hand"):
		return
	await _press(_pointer_free(view), MOUSE_BUTTON_RIGHT)
	if not _require(view._held_turned != bool(place.turned), "ordinary turn input rotates the carried binding"):
		return
	await _press(_pointer_free(view))
	if not _require(view.held_item.is_empty(), "the rotated book can settle on legal cells"):
		return
	place = CarriedCase.place_of(item).duplicate()
	await _key(KEY_TAB)
	await get_tree().create_timer(0.45).timeout
	RealityState.load_game()
	await get_tree().physics_frame
	if not _require(RealityState.can_continue() and CarriedCase.place_of(item) == place \
			and original.valise_packed and not original.visible and sibling.visible, "disk reload restores one packed copy"):
		return

	var obstruction := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(0.12, 0.12, 0.12)
	collider.shape = block
	obstruction.add_child(collider)
	world.add_child(obstruction)
	obstruction.global_position = player.camera.global_transform * Vector3(0.17, -0.16, -0.48)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var packed_primary := FileAccess.get_file_as_bytes(path)
	await _take_through_case(view, place)
	if not _require(player.held_stock_body() == null and original.valise_packed \
			and CarriedCase.place_of(item) == place and FileAccess.get_file_as_bytes(path) == packed_primary,
			"blocked handoff preserves packed custody, placement and primary"):
		return
	obstruction.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _take_through_case(view, place)
	_require(player.held_stock_body() == original and original.visible and not original.valise_packed \
		and CarriedCase.place_of(item).is_empty() and sibling.visible, "ordinary take-out restores the same native body")
	await _capture_interaction("original_copy_returned_to_hand")


func _take_through_case(view: Node, place: Dictionary) -> void:
	await _key(KEY_TAB)
	await get_tree().create_timer(0.65).timeout
	if not _require(view.opened and view.settled, "case opens for the take-out input"):
		return
	var size := CarriedCase.form_size(str(place.form), bool(place.turned))
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(place.y) + size.y * 0.5))
	await _press(_screen(view, float(place.x) + size.x * 0.5, CarriedCase.grid().y + 0.65))
	await get_tree().create_timer(0.45).timeout
