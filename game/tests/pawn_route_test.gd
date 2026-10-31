extends "res://tests/carried_case_route_test.gd"
## The Pawnbroker in the V2 root with real input: carried off the shelf at the grille, a
## good is pledged for cash; the real hand redeems it for a little more; a ticket past
## its days goes on the shelf and sells; a dated pledge appears on its date and sells
## once; a cheap thing isn't taken and stays in the hand.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

func _init() -> void:
	route_label = "PAWN ROUTE"

func _off_front(view: Node) -> Vector2:
	return view._camera.unproject_position(Vector3(0.0, 0.0, 0.15 + float(CarriedCase.data().cell)))

func _take_out(view: Node, item: String) -> void:
	var place: Dictionary = CarriedCase.place_of(item)
	var size := CarriedCase.form_size(str(place.form), bool(place.turned))
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(place.y) + size.y * 0.5))
	await _motion(_off_front(view))
	await _capture_interaction("pawn_" + item)
	await _press(_off_front(view))

func _route() -> void:
	CampaignClock.new().configure_date(1929, 2, 1, 12 * 60)
	var view: Node = world.carried_case_view
	var point: Node3D = world.shop_counters.get("pawnbroker")
	if not _require(point != null, "the Pawnbroker has a counter"): return
	var sales: PawnSales = point.sales
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player
	player.global_position = point.global_position - point.global_basis.z * 0.95 + Vector3.DOWN * 1.1
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame
	await _capture_interaction("pawn_counter")
	_require(view.item_use.at_pawn(), "the grille is in reach")
	_require(not sales.listing().has("wedding_ring"), "a later pledge isn't on the shelf yet")

	PersonInventory.carry_goods("player", "briar_pipe", "Briar pipe", "tool")
	PersonInventory.carry_goods("player", "pencil", "Pencil", "tool")
	RealityState.commit()
	await _key(KEY_TAB)
	await get_tree().create_timer(0.8).timeout
	var cash := int(economy.book().cash)
	await _take_out(view, "briar_pipe")
	_require(PersonInventory.goods_count("player", "briar_pipe") == 0, "the pipe is pledged")
	_require(PawnSales.book().tickets.has("briar_pipe"), "with a ticket")
	var lent := int(economy.book().cash) - cash
	_require(lent == PawnSales.loan_for(50), "for a third of its worth: %d" % lent)
	await _take_out(view, "pencil")
	_require(view.held_item == "pencil", "a cheap thing isn't taken")
	var pencil: Dictionary = CarriedCase.place_of("pencil")
	await _press(_screen(view, float(pencil.x) + 0.5, float(pencil.y) + 0.5))
	await _capture_interaction("pawn_after_pledge")
	await _key(KEY_TAB)
	await get_tree().create_timer(0.6).timeout

	# Redeem with the real hand.
	point.refresh_list()
	var ticket_id := PawnSales.REDEEM_PREFIX + "briar_pipe"
	_require(point.item_ids.has(ticket_id), "the ticket is on the list")
	point.select(point.item_ids.find(ticket_id))
	await _capture_interaction("pawn_redeem_selected")
	cash = int(economy.book().cash)
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand redeems")
	_require(int(economy.book().cash) < cash and cash - int(economy.book().cash) > lent, "for a little more than the loan")
	_require(PersonInventory.goods_count("player", "briar_pipe") == 1, "the pipe comes back")
	_require(point.flag.text == "SETTLED", "the slip and flag survive the ticket ending: " + point.flag.text)
	_require(not point.item_ids.has(ticket_id), "the list moves on")
	_require(not PawnSales.book().tickets.has("briar_pipe"), "and the ticket ends")

	# A lapsed ticket goes on the shelf.
	_require(sales.pledge("briar_pipe", "Briar pipe", "tool", 50), "pledge again")
	PawnSales.book().tickets.briar_pipe.at -= (PawnSales.TICKET_DAYS + 1) * PawnSales.DAY
	point.refresh_list()
	var resale_id := PawnSales.RESALE_PREFIX + "briar_pipe"
	_require(not point.item_ids.has(ticket_id) and point.item_ids.has(resale_id), "a lapsed ticket goes on the shelf")
	point.select(point.item_ids.find(resale_id))
	_require(int(point.sales.stock_record(resale_id).price_cents) == lent * 2, "at twice the loan")
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand buys it back")
	_require(PersonInventory.goods_count("player", "briar_pipe") == 1, "the pipe is bought back")

	# A resident's dated pledge appears, and sells once.
	CampaignClock.new().configure_date(1929, 9, 1, 12 * 60)
	point.refresh_list()
	if _require(point.item_ids.has("wedding_ring"), "the ring is on the shelf by its date"):
		point.select(point.item_ids.find("wedding_ring"))
		economy.book().cash = 2000
		_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand buys it")
		point.refresh_list()
		_require(PersonInventory.goods_count("player", "wedding_ring") == 1, "it's in the case")
		_require(not point.item_ids.has("wedding_ring"), "and is gone from the shelf")
	_require(PawnSales.valid(RealityState.data[PawnSales.KEY]), "the book stays valid")
