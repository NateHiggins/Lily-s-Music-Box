extends "res://tests/carried_case_route_test.gd"
## Photo Supplies in the V2 root with the real hand: the terminal sells a plate; an hour in the
## darkroom takes a plate, a sheet and the chemicals; the tray rocks; the sheet lifts out thin, good
## or lost; the counter prints in whoever's hand keeps the shop; sittings stop with her; the
## register reads to today; the window changes by date and a card can be read from the street.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

func _init() -> void:
	route_label = "PHOTO ROUTE"

func _date(month: int, day: int, year := 1929) -> void:
	CampaignClock.new().configure_date(year, month, day, 12 * 60)
	world.passage_region.finish.hours_director.apply_for_minute(12 * 60)
	await get_tree().process_frame

func _stand_at(point: Vector3, look: Vector3) -> void:
	player.global_position = point
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(look)
	await get_tree().physics_frame

func _stand_before(prop: Node3D, away := 0.95) -> void:
	var front: Vector3 = prop.global_position + prop.global_basis.z * away
	front.y = _floor_y()
	await _stand_at(front, prop.global_position)

func _floor_y() -> float:
	return world.shop_counters.get("photo_supplies").global_position.y - 1.43

func _seed_darkroom() -> void:
	for pair: Array in [["single_dry_plate", "Single dry plate", "packet"], ["printing_paper_sheet", "Printing paper, sheet", "tin"],
			["developer_and_fixer", "Developer and fixer", "bottle"]]:
		PersonInventory.carry_goods(PersonInventory.PLAYER, pair[0], pair[1], pair[2])

func _buy(counter: Node3D, hand: Node, item: String) -> void:
	counter.refresh_list()
	counter.select(counter.item_ids.find(item))
	await _stand_counter(counter)
	await hand._stroke(counter.terminal, counter.terminal.TRAVEL)

func _stand_counter(counter: Node3D) -> void:
	var front: Vector3 = counter.global_position - counter.global_basis.z * 0.95
	front.y = _floor_y()
	await _stand_at(front, counter.global_position)

func _route() -> void:
	var counter: Node3D = world.shop_counters.get("photo_supplies")
	var photo: Dictionary = world.photo_supplies
	if not _require(counter != null and not photo.is_empty(), "counter, tray, register and window are mounted"): return
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 5000
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	await _date(3, 10)
	var tray: Node3D = photo.tray

	# The counter.
	counter.refresh_list()
	_require(counter.item_ids.has("portrait_sitting"), "she sits you before July")
	await _stand_counter(counter)
	await _capture_interaction("photo_counter")
	var cash := int(economy.book().cash)
	await _buy(counter, hand, "single_dry_plate")
	_require(int(economy.book().cash) == cash - 75, "the real hand buys a plate: " + counter.flag.text)
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, "single_dry_plate") == 1, "and it's in the case")
	await _buy(counter, hand, "darkroom_hour")
	_require(counter.flag.text == "PAPER AND CHEMICALS", "an hour wants paper and chemicals: " + counter.flag.text)
	await _buy(counter, hand, "plate_developed_and_printed_here")
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, "own_print") == 1, "the counter prints your plate")
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, "single_dry_plate") == 0, "and it took the plate")

	# The tray, too early.
	_seed_darkroom()
	await _buy(counter, hand, "darkroom_hour")
	_require(bool(PhotoSales.book().waiting), "a print waits in the tray: " + counter.flag.text)
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, "printing_paper_sheet") == 0, "the hour took the paper")
	await _stand_before(tray, 0.75)
	await _capture_interaction("photo_tray_blank")
	await hand.aim(tray.tray.global_position + Vector3.RIGHT * 0.12 + Vector3.UP * 0.3)
	hand.click()
	if not _require(player._grab.active(), "the hand takes the tray"): return
	await hand._gesture_to(0.9)
	await hand._gesture_to(0.1)
	await hand._gesture_to(0.8)
	hand.click()
	_require(tray.progress > 0.0, "rocking brings it up: %s" % tray.progress)
	_require(absf(tray.tray.rotation.z) > 0.01, "the tray has tilted")
	await _lift_out(hand, tray)
	_require(not bool(PhotoSales.book().waiting), "the sheet is out")
	var before := PersonInventory.goods_count(PersonInventory.PLAYER, "own_print")
	_require(before == 2, "a thin print is still a print")

	# Good, then lost.
	_seed_darkroom()
	await _buy(counter, hand, "darkroom_hour")
	await _stand_before(tray, 0.75)
	tray.started = true
	tray.progress = 0.9
	tray._show()
	await _capture_interaction("photo_tray_good")
	await _lift_out(hand, tray)
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, "own_print") == before + 1, "a good print goes in the case")
	_seed_darkroom()
	await _buy(counter, hand, "darkroom_hour")
	await _stand_before(tray, 0.75)
	tray.started = true
	tray.progress = 1.3
	tray._show()
	await _lift_out(hand, tray)
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, "own_print") == before + 1, "too late is lost")

	# The register.
	var register: Node3D = photo.register
	await _date(3, 10)
	await _stand_before(register, 0.7)
	await _capture_interaction("photo_register")
	var body := await _draw_register(hand, register)
	_require(body.contains("CERTIFICATE PLATES") and not body.contains("DEED"), "in March it stops at March: " + body)
	_require(RealityState.has_knowledge("m_register"), "reading it is the clue")
	_require(not RealityState.has_knowledge("m_backup_ledger"), "the duplicate isn't entered yet")
	await _date(7, 25)
	body = await _draw_register(hand, register)
	_require(body.contains("DEED") and RealityState.has_knowledge("m_backup_ledger"), "in July it has the deed and the duplicate")
	world.passage_region.finish.hours_director.apply_for_minute(180)
	_require(register.grip().is_empty(), "a closed shop's register stays shut")
	await _date(7, 25)

	# After her.
	counter.refresh_list()
	_require(not counter.item_ids.has("portrait_sitting"), "no sittings after July")

	# The window.
	var window: Node3D = photo.window
	for row: Array in [[1, 31, "n3_supper"], [6, 13, "n8_tea"], [7, 25, "n9_wills"], [8, 19, "n10_aviation"], [8, 21, "crosson"], [10, 20, "qualified"]]:
		await _date(row[0], row[1])
		window.refresh()
		_require(window.showing().has(row[2]), "%s on %s/%s: %s" % [row[2], row[0], row[1], window.showing()])
	await _date(8, 19)
	window.refresh()
	RealityState.data.knowledge_flags.erase("m_aviation_card")
	var street: Vector3 = window.global_position + window.global_basis.z * 1.5
	street.y = _floor_y()
	await _stand_at(street, window.global_position)
	await get_tree().create_timer(0.7).timeout
	_require(RealityState.has_knowledge("m_aviation_card"), "standing at the glass reads the card")
	await _capture_interaction("photo_window_aviation")
	await _date(6, 13)
	window.refresh()
	await get_tree().create_timer(0.8).timeout
	await _capture_interaction("photo_window_tea")
	_require(PhotoSales.valid(RealityState.data[PhotoSales.KEY]), "the bench stays valid")

func _lift_out(hand: Node, tray: Node3D) -> void:
	await hand.aim(tray.sheet.global_position)
	hand.click()
	if _require(player._grab.active() and player._grab.target.part == tray.sheet, "the hand takes the sheet"):
		await hand._gesture_to(tray.LIFT)
		if player._grab.active():
			hand.click()

func _draw_register(hand: Node, register: Node3D) -> String:
	await hand.aim(register.part.global_position + register.global_basis.z * 0.06 + Vector3.UP * 0.007)
	hand.click()
	if not _require(player._grab.active(), "the hand takes the register"):
		return ""
	var captured: Array = [""]
	var original: Callable = register.reader
	register.reader = func():
		var note: Dictionary = original.call()
		captured[0] = str(note.body)
		return note
	await hand._gesture_to(register.reach)
	if player._grab.active():
		hand.click()
	register.reader = original
	await get_tree().create_timer(0.6).timeout
	return captured[0]
