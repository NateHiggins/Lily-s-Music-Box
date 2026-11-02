extends "res://tests/carried_case_route_test.gd"
## The parcel wall in the production V2 root with real input: a resident gives a ticket, a wrong
## parcel can be drawn out and slides back, the right one comes off into the case, and the door
## takes it. Every ticketed place can be reached from open floor in front of the wall.

const FLOOR_DROP := 1.05
const STAND_ACROSS := 5.75
const STAND_NEAREST := -40.5
const STAND_FARTHEST := -43.4

var wall: Node3D


func _init() -> void:
	route_label = "PARCEL ROUTE"


func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame


func _draw_out(pixels: float) -> void:
	for _step in int(absf(pixels) / 6.0):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, signf(pixels) * 6.0)
		player._unhandled_input(motion)
		await get_tree().physics_frame


## Stands on open floor level with the parcel's column and looks at its tag.
func _face(parcel: String) -> Dictionary:
	var slot: Dictionary = wall.slots[parcel]
	var floor_y: float = world.laundry_bundle.global_position.y - FLOOR_DROP
	var along := clampf(-float(slot.rest.z), STAND_FARTHEST, STAND_NEAREST)
	player.global_position = wall.to_global(Vector3(STAND_ACROSS, 0, -along)) * Vector3(1, 0, 1) + Vector3.UP * floor_y
	await get_tree().create_timer(0.15).timeout
	var at: Vector3 = wall.to_global(slot.rest + Vector3.RIGHT * float(slot.half_depth))
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	return player._grab.find_target()


func _route() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(1929, 2, 1, 12 * 60)
	wall = world.parcel_wall
	var talk: ResidentConversations = world.conversations
	if not _require(wall != null and talk.errands != null, "the wall and the errands are mounted"): return
	wall.refresh()
	var today := LaundrySales.day()
	var drawn := 0
	for parcel: String in wall.slots:
		drawn += wall.slots[parcel].draws.size()
	_require(drawn > 40, "the wall holds the shop's own meshes: %d" % drawn)

	var tickets := {}
	for parcel: String in wall.slots:
		tickets[ParcelErrands.ticket(parcel)] = true
	_require(tickets.size() == ParcelErrands.ROWS * ParcelErrands.COLUMNS, "every parcel has its own ticket")
	var missing := 0
	for parcel: String in wall.slots:
		if not ParcelErrands.on_wall(parcel, today):
			missing += 1
			_require(not wall.slots[parcel].draws[0].visible, "a place that's empty shows empty: %s" % parcel)
	_require(missing > 0 and missing < 16, "the wall has gaps but is mostly full: %d" % missing)
	for column in ParcelErrands.COLUMNS:
		_require(ParcelErrands.on_wall(ParcelErrands.parcel_id(ParcelErrands.UNCLAIMED_ROW, column), today), "the top row never moves")

	var unreachable: PackedStringArray = []
	for row in range(ParcelErrands.FIRST_TICKET_ROW, ParcelErrands.UNCLAIMED_ROW):
		for column in ParcelErrands.COLUMNS:
			var parcel := ParcelErrands.parcel_id(row, column)
			if not ParcelErrands.on_wall(parcel, today):
				continue
			var grip := await _face(parcel)
			if grip.get("owner") != wall or grip.get("part") != wall.slots[parcel].part:
				unreachable.append(parcel)
	_require(unreachable.is_empty(), "every ticketed place can be taken hold of: %s" % [unreachable])

	var resident := ""
	for candidate: String in talk.trees.keys():
		if ParcelErrands.can_ask(candidate):
			resident = candidate
			break
	if not _require(resident != "", "somebody in the house has a parcel this week"): return
	var parcel := ParcelErrands.chosen(resident)
	_require(parcel != "", "and it's on the wall")
	var tree: Dictionary = talk.with_parcel(resident, {"entries": {"first_stable": "home"}, "nodes": {"home": {"line": "", "choices": []}}})
	_require(tree.nodes.has(talk.PARCEL_ASK) and str(ParcelErrands.ticket(parcel)) in str(tree.nodes[talk.PARCEL_ASK].line), "the door says the ticket number")
	talk._record(resident, talk.PARCEL_ASK, 0)
	_require(ParcelErrands.has_open(resident) and str(ParcelErrands.book().open.parcel) == parcel, "taking it down opens the errand")
	for other: String in ["omar_bell", "cal_dwyer", "iris_bell"]:
		if other != resident:
			_require(not ParcelErrands.can_ask(other), "and nobody else gives one while it's out")
	tree = talk.with_parcel(resident, {"entries": {"first_stable": "home"}, "nodes": {"home": {"line": "", "choices": []}}})
	_require(tree.nodes.has(talk.PARCEL_WAIT), "the door repeats the number if you ask")

	var wrong := ""
	var row_of_right := parcel.get_slice("_", 0)
	for column in ParcelErrands.COLUMNS:
		var candidate := "%s_%d" % [row_of_right, column]
		if candidate != parcel and ParcelErrands.on_wall(candidate, today):
			wrong = candidate
			break
	var grip := await _face(wrong)
	_require(grip.get("part") == wall.slots[wrong].part, "the ray reaches a wrong parcel: %s" % [grip])
	await _click()
	_require(player._grab.active() and is_zero_approx(wall.slots[wrong].along), "a click grabs and doesn't move it")
	await _capture_interaction("parcel_wall")
	var before_x: float = wall.slots[wrong].draws[0].global_position.x
	await _draw_out(260.0)
	_require(float(wall.slots[wrong].along) >= wall.TRAVEL * wall.TAKEN_AT, "motion draws it out: %f" % wall.slots[wrong].along)
	_require(wall.slots[wrong].draws[0].global_position.x > before_x + 0.2, "and the mesh itself moves")
	await _capture_interaction("parcel_drawn")
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, ParcelErrands.ITEM) == 0, "a wrong parcel doesn't come off")
	await get_tree().create_timer(0.8).timeout
	_require(is_zero_approx(wall.slots[wrong].along), "it slides back to the shelf")

	grip = await _face(parcel)
	_require(grip.get("part") == wall.slots[parcel].part, "the ray reaches the right parcel: %s" % [grip])
	await _click()
	await _draw_out(60.0)
	await _click()
	_require(not bool(ParcelErrands.book().open.taken), "part way doesn't take it")
	await get_tree().create_timer(0.8).timeout
	grip = await _face(parcel)
	await _click()
	await _draw_out(260.0)
	await _click()
	await get_tree().physics_frame
	_require(bool(ParcelErrands.book().open.taken), "the whole way takes it: %s" % [ParcelErrands.book()])
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, ParcelErrands.ITEM) == 1, "into the case")
	_require(not wall.slots[parcel].draws[0].visible and not wall.slots[parcel].words.visible, "and leaves a gap on the wall")
	await _capture_interaction("parcel_gap")

	tree = talk.with_parcel(resident, {"entries": {"first_stable": "home"}, "nodes": {"home": {"line": "", "choices": []}}})
	_require(tree.nodes.has(talk.PARCEL_THANKS), "the door takes it")
	var book: Dictionary = world.get_node("CaretakerEconomy").book()
	var tips: int = book.tips.size()
	talk._record(resident, talk.PARCEL_THANKS, 0)
	_require(ParcelErrands.book().open.is_empty(), "handing it over closes the errand")
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, ParcelErrands.ITEM) == 0, "and it's out of the case")
	_require(book.tips.size() == tips + 1, "and the resident tips")
	_require(not ParcelErrands.can_ask(resident), "and doesn't ask again this week")
	wall.refresh()
	_require(not wall.slots[parcel].draws[0].visible, "the place stays empty")
	clock.configure_date(1929, 2, 16, 12 * 60)
	wall.refresh()
	var later := LaundrySales.day()
	_require(later >= int(ParcelErrands.book().gone[parcel]), "a fortnight on the claim has run out")
	_require(wall.slots[parcel].draws[0].visible == ParcelErrands.on_wall(parcel, later), "and the wall follows the book")

	_require(ParcelErrands.valid(ParcelErrands.book()), "the book is valid for a save")
	_require(not ParcelErrands.valid({"open": {"resident": 3}, "last": {}, "gone": {}}), "and a made-up one isn't")
