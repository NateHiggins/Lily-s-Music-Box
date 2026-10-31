extends "res://tests/carried_case_route_test.gd"
## Keys Cut in the V2 root with the real hand: a permission puts a spare on the list; the
## counter takes the money and readies a blank; a partial pass at the cutter cuts nothing;
## a full pass cuts the key; a closed shop can't cut. Being behind on the rent stops tenants
## signing, except those with a case, and sends a notice to the box.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

func _init() -> void:
	route_label = "KEYS ROUTE"

func _stand(point: Node3D, hand: Node) -> void:
	player.global_position = point.global_position - point.global_basis.z * 0.95 + Vector3.DOWN * 1.1
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame

func _route() -> void:
	var counter: Node3D = world.shop_counters.get("keys_cut")
	var cutter: Node3D = world.key_cutter
	if not _require(counter != null and cutter != null, "the counter and cutter are mounted"): return
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	world.passage_region.finish.hours_director.set_process(false)
	world.passage_region.finish.hours_director.apply_for_minute(12 * 60)
	var unit := "2A"
	_require(not counter.sales.listing().has("spare_" + unit), "no spare on the list without permission")
	_require(not DoorKeyring.request_copy("mina_vale").is_empty(), "the tenant signs")
	var originals: Dictionary = DoorKeyring.book().originals.duplicate(true)
	counter.refresh_list()
	if not _require(counter.item_ids.has("spare_" + unit), "the permission puts a spare on the list"): return
	counter.select(counter.item_ids.find("spare_" + unit))
	await _stand(counter, hand)
	await _capture_interaction("keys_counter")
	var cash := int(economy.book().cash)
	_require(await hand._stroke(counter.terminal, counter.terminal.TRAVEL), "the real hand pays")
	_require(int(economy.book().cash) == cash - KeysSales.SPARE_CENTS, "for the spare: " + counter.flag.text)
	_require(KeysSales.waiting().has(unit), "a blank is ready")
	_require(not DoorKeyring.book().copies.has(unit), "and nothing is cut yet")

	await _stand(cutter, hand)
	await _capture_interaction("keys_cutter")
	# Partial pass.
	await hand.aim(cutter.carriage.to_global(Vector3(0, .094, -.025)))
	hand.click()
	if not _require(player._grab.active() and player._grab.target.part == cutter.carriage, "the hand takes the carriage"): return
	await hand._gesture_to(0.05)
	hand.click()
	_require(not DoorKeyring.book().copies.has(unit), "a partial pass cuts nothing")
	await get_tree().create_timer(0.9).timeout
	_require(cutter.travel < 0.01, "the carriage springs back")
	# A closed shop.
	world.passage_region.finish.hours_director.apply_for_minute(180)
	_require(cutter.grip().is_empty(), "a closed shop can't cut")
	world.passage_region.finish.hours_director.apply_for_minute(12 * 60)
	# A full pass.
	await hand.aim(cutter.carriage.to_global(Vector3(0, .094, -.025)))
	hand.click()
	_require(player._grab.active(), "the hand takes it again")
	await hand._gesture_to(cutter.TRAVEL)
	if player._grab.active():
		hand.click()
	_require(DoorKeyring.book().copies.get(unit) == "mina_vale", "a full pass cuts the spare")
	_require(DoorKeyring.book().originals == originals, "the original stays with the tenant")
	_require(KeysSales.waiting().is_empty(), "the blank is used")
	_require(not DoorKeyring.make_copy(unit), "a second spare is refused")
	await _capture_interaction("keys_cut_done")

	# Rent.
	var other := ""
	for resident: String in DoorKeyring.residents():
		var case_id := RealityCases.case_for_resident(resident)
		if resident != "mina_vale" and DoorKeyring.copy_prompt(resident) != "" \
				and not bool(RealityCases.definition(case_id).get("enabled", false)):
			other = resident
			break
	if not _require(other != "", "someone without an enabled case is on the copy list"): return
	var ledger: Dictionary = economy.book()
	ledger.started = float(ledger.started) - 2.0 * economy.MONTH - 10.0
	_require(economy.rent_cycles_due() >= 2, "the rent is two months behind")
	_require(DoorKeyring.copy_prompt(other).contains("rent"), "a tenant won't sign: " + DoorKeyring.copy_prompt(other))
	var refused := DoorKeyring.request_copy(other)
	_require(not DoorKeyring.book().permissions.has(DoorKeyring.residents()[other]), "and no permission is given")
	_require(str(refused.get("body", "")).contains("RENT"), "the slip says why")
	var enabled_case := ""
	for resident: String in DoorKeyring.residents():
		if bool(RealityCases.definition(RealityCases.case_for_resident(resident)).get("enabled", false)) \
				and not DoorKeyring.book().permissions.has(DoorKeyring.residents()[resident]):
			enabled_case = resident
			break
	print("[KEYS] an enabled case without a permission yet: ", enabled_case)
	if enabled_case != "":
		_require(not DoorKeyring.copy_prompt(enabled_case).contains("rent"), "a tenant with a live case still signs")
	_require(not DoorKeyring.copy_prompt("mina_vale").contains("rent"), "Mina's existing permission stands")
	var bank: MailBankProp = null
	for found: Node in get_tree().get_nodes_in_group("mail_bank"):
		bank = found
	if _require(bank != null, "the mail bank is in the world"):
		var due: Array = bank.pending().map(func(item): return str(item.id))
		_require(due.has("rent_notice_1") and due.has("rent_notice_2"), "the notices are in the box: %s" % [due])
		_require(not due.has("rent_notice_3"), "the third waits")
	_require(KeysSales.valid(RealityState.data[KeysSales.KEY]), "the book stays valid")
