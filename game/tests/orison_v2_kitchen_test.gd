extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The household kitchens in the production V2 root
## (design/ORISON_KITCHENS_2026-10-24.md): the residents' agenda and every
## household larder run; the house cookbook lies on 4B's work table, the
## player's ray reaches it and it opens on every dish; a household's shopping
## and cooking restock its icebox with native food stock. Windowed: the runtime
## refuses headless.

var _target: Node3D


func _init() -> void:
	route_label = "V2 KITCHENS"


func _prepare_player_start() -> void:
	player.velocity = Vector3.ZERO


func _route() -> void:
	var agenda: ResidentAgenda = world.resident_agenda
	if not _require(agenda != null and agenda.enabled, "the residents' agenda runs in the V2 root"): return
	var larder: KitchenLarder = agenda.larder
	if not _require(larder != null and larder.state.units.size() == 17, "all seventeen households keep a larder"): return
	var whereabouts: Dictionary = world.resident_whereabouts("lena_ortiz")
	_require(str(whereabouts.get("why", "")) != "" and whereabouts.has("source"),
			"a resident's whereabouts say why: %s" % [whereabouts])

	# The cookbook on 4B's work table, reached and read.
	var book := world.adapter.root.get_node_or_null("KitchenPrep_4B/Cookbook") as CookbookProp
	if not _require(book != null, "the house cookbook lies on 4B's work table"): return
	_target = book
	if not await _stand_before(book, "F04", 0.9, "4B"): return
	var control := book.get_node("CookbookControl") as Node3D
	_require(_reaches(control), "the player's ray reaches the cookbook")
	await _shot("kitchen_cookbook_table", book.global_position)
	book.interact_control("cookbook", player)
	await get_tree().process_frame
	var panel := get_tree().current_scene.get_node_or_null("CookbookPanel") as CookbookPanel
	if _require(panel != null, "the cookbook opens"):
		_require(panel._contents.item_count == 19, "the contents list the foreword and eighteen dishes")
		await _ui_shot("cookbook_foreword")
		panel.show_dish("sabbath_fijones")
		_require(panel.dish_id == "sabbath_fijones", "a dish page opens")
		await _ui_shot("cookbook_fijones")
		panel.show_dish("certain_sauerbraten")
		await _ui_shot("cookbook_sauerbraten")
		panel.close()
		await get_tree().process_frame

	# Lena shops and cooks: 2B's icebox shows the beef, and the pot of fijones.
	var icebox: FridgeProp = null
	for node: Node in world.adapter.root.find_children("*", "Node3D", true, false):
		if node is FridgeProp and str((node as FridgeProp).unit) == "2B":
			icebox = node
	if not _require(icebox != null, "2B has an icebox"): return
	var stamp := floorf(world.campaign_clock.elapsed_minutes())
	for shop: String in larder.groceries.shops:
		larder.shop("lena_ortiz", shop, stamp)
	_require(larder.can_cook("lena_ortiz"), "Lena's shopping covers her dish")
	_require(larder.cook("lena_ortiz", stamp + 1.0) == "dish", "Lena cooks the fijones")
	await get_tree().process_frame
	var rows := larder.icebox_rows("2B")
	var shown := 0
	var dressed := 0
	for child: Node in icebox.get_children():
		if child.has_meta("source_larder_item") and not child.is_queued_for_deletion():
			shown += 1
			if child.has_meta("native_larder_variant"):
				dressed += 1
	_require(rows.size() > 0 and shown == rows.size(), "2B's icebox shows its %d larder rows (%d shown)" % [rows.size(), shown])
	_require(dressed == shown, "every item is dressed in native food stock")
	var pantry := world.adapter.root.get_node_or_null("KitchenPrep_2B/Pantry") as PantryDisplay
	if _require(pantry != null, "2B's work table keeps a pantry"):
		var wanted := larder.pantry_rows("2B")
		var goods := 0
		for child: Node in pantry.get_children():
			if not child.is_queued_for_deletion():
				goods += 1
		_require(wanted.size() > 0 and goods == wanted.size(),
				"2B's pantry shows its %d dry goods (%d shown)" % [wanted.size(), goods])
	icebox.set_door_open(true, 0.0)
	_target = icebox
	if await _stand_before(icebox, "F02", 0.9, "2B"):
		await _shot("kitchen_icebox_2B", icebox.to_global(Vector3(0.0, 0.55, 0.0)))
		await _shot("kitchen_2B_wide", icebox.to_global(Vector3(0.0, 0.9, 0.0)), 2.6)
	if pantry != null:
		_target = pantry
		if await _stand_before(pantry.get_parent() as Node3D, "F02", 1.0, "2B"):
			await _shot("kitchen_pantry_2B", pantry.global_position)


## Stand in front of a thing, inside its own room, at eye level.
func _stand_before(thing: Node3D, level: String, distance: float, unit: String) -> bool:
	var floor_y: float = world.adapter.root.to_global(Vector3(0.0, float(world.adapter.root.level_y[level]), 0.0)).y
	for depth in [distance, -distance]:
		for side in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var at: Vector3 = thing.global_position + thing.global_basis * (side * absf(depth))
			if world.unit_of_room(world.room_at_world(at)) != unit:
				continue
			player.global_position = Vector3(at.x, floor_y + 0.02, at.z)
			player.velocity = Vector3.ZERO
			for _frame in 6:
				await get_tree().physics_frame
			if world.unit_of_room(world.room_at_world(player.global_position)) == unit:
				return true
	return _require(false, "found a place to stand before %s" % thing.name)


func _reaches(control: Node3D) -> bool:
	player.camera.look_at(control.global_position)
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("collider") == control


func _shot(identity: String, look: Vector3, back := 0.0) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	if back > 0.0:
		var away := (player.global_position - look)
		away.y = 0.0
		player.global_position += away.normalized() * back
		for _frame in 4:
			await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(output)
	player.camera.look_at(look)
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))


func _ui_shot(identity: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))
