extends Node
## The shared shop systems without a world: all thirteen catalogues load and hold
## the residents' prices; goods stack, cap and survive the save validator; repeat
## sales debit once and roll back whole; stock wears down and refills the same
## however time is sliced; a real lever stroke through the terminal sells, refuses
## and never retries. Shops are not mounted here, so this proves no shop in play.

const Economy := preload("res://scripts/game/caretaker_economy.gd")
const Clearing := preload("res://scripts/game/radio_clearing_network.gd")
const SalePoint := preload("res://scripts/props/shop_sale_point.gd")

var _fails := 0
var _radio := true
var _line_open := true


func _check(label: String, ok: bool) -> void:
	print("SHOP COMMERCE: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	await _run()
	print("SHOP COMMERCE TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _stroke(point: Node3D) -> void:
	var grip: Dictionary = point.terminal.grip()
	grip.begin.call()
	grip.write.call(0.020)
	grip.write.call(point.terminal.TRAVEL)
	grip.end.call()
	grip.begin.call()
	grip.write.call(0.0)
	grip.end.call()


func _run() -> void:
	var clock := CampaignClock.new()
	_check("the clock binds", clock.configure_date(1929, 3, 3, 12 * 60))
	var catalogue := ShopCatalogue.new()
	var loaded := catalogue.load_all()
	_check("all catalogues load", loaded)
	if not loaded:
		print(catalogue.errors)
	_check("thirteen shops", catalogue.shop_ids().size() == 13)
	for shop_id: String in catalogue.shop_ids():
		_check("%s has items" % shop_id, not catalogue.shops[shop_id].items.is_empty())
	_check("a bad grocery link is refused", not catalogue._valid({"shop_id": "x", "name": "x", "closed": [], "groups": {},
			"items": [{"id": "c", "name": "c", "cents": 99, "kind": "goods", "source": "live", "grocery": "chocolate"}]},
			"test", {"chocolate": {"cents": 5}}))
	catalogue.errors.clear()
	_check("Arcade hours close the counter", not catalogue.open_at("news_cigars", 200) and catalogue.open_at("news_cigars", 600))
	_check("Hardware never closes", catalogue.open_at("hardware_paint", 200))

	var economy := Economy.new()
	add_child(economy)
	economy.book().cash = 100
	var stock := ShopStock.new()
	add_child(stock)
	stock.set_process(false)
	_check("stock binds", stock.setup(catalogue))
	var clearing := Clearing.new()
	clearing.configure(economy, func(): return _radio, func(_shop: String): return _line_open)

	# Goods.
	_check("goods carry", PersonInventory.carry_goods("player", "earplugs", "Earplugs"))
	_check("goods count", PersonInventory.goods_count("player", "earplugs") == 1)
	_check("goods appear in the pocket", " ".join(PersonInventory.pocket_lines()).contains("Earplugs"))
	_check("the save validator keeps them", PersonInventory.valid(RealityState.data.inventories))
	for i in PersonInventory.GOODS_STACK - 1:
		PersonInventory.carry_goods("player", "earplugs", "Earplugs")
	_check("a stack caps", not PersonInventory.carry_goods("player", "earplugs", "Earplugs"))
	_check("goods spend", PersonInventory.spend_goods("player", "earplugs"))
	_check("and return room", PersonInventory.can_carry_goods("player", "earplugs"))
	_check("empty hands spend nothing", not PersonInventory.spend_goods("player", "nothing_here"))
	var bad: Dictionary = RealityState.data.inventories.duplicate(true)
	bad.holders.player["goods:x"] = {"kind": "goods", "item": "x", "name": "x", "qty": 0}
	_check("a zero stack is invalid", not PersonInventory.valid(bad))

	# The case: every shape fits a stitched square, and a full case refuses.
	for form: String in CarriedCase.data().forms:
		var size := CarriedCase.form_size(form)
		_check("form %s turns" % form, CarriedCase.form_size(form, true) == Vector2i(size.y, size.x))
	_check("the arrangement is valid", CarriedCase.valid(RealityState.data.carried_case))
	var filled := 0
	while PersonInventory.carry_goods("player", "fill_%d" % filled, "Fill", "parcel") and filled < 80:
		filled += 1
	_check("a full case refuses a new stack", filled > 0 and filled < 80
			and not PersonInventory.can_carry_goods("player", "one_more", "parcel"))
	_check("a full case still stacks what it holds", PersonInventory.can_carry_goods("player", "fill_0", "parcel"))
	_check("a full arrangement stays valid", CarriedCase.valid(RealityState.data.carried_case))
	var overlapped: Dictionary = RealityState.data.carried_case.duplicate(true)
	var first_two: Array = overlapped.places.keys().slice(0, 2)
	overlapped.places[first_two[1]].x = overlapped.places[first_two[0]].x
	overlapped.places[first_two[1]].y = overlapped.places[first_two[0]].y
	_check("an overlap is invalid", not CarriedCase.valid(overlapped))
	for i in filled:
		PersonInventory.spend_goods("player", "fill_%d" % i)
	_check("spending frees the squares", not CarriedCase.book().places.has("fill_0"))

	# Repeat purchases.
	var sale_cash := int(economy.book().cash)
	_check("a repeat sale settles", economy.purchase_repeat("m", "i", 10, func(): return true))
	_check("and again", economy.purchase_repeat("m", "i", 10, func(): return true))
	_check("two debits", int(economy.book().cash) == sale_cash - 20)
	_check("one bounded row", economy.book().sales.size() == 1 and int(economy.book().sales["m/i"].count) == 2)
	_check("a failed delivery refunds", not economy.purchase_repeat("m", "i", 10, func(): return false)
			and int(economy.book().cash) == sale_cash - 20 and int(economy.book().sales["m/i"].count) == 2)
	_check("no credit, no sale", not economy.purchase_repeat("m", "i", 100000, func(): return true))
	_check("the ledger stays valid", Economy.valid(economy.book()))
	var broken: Dictionary = economy.book().duplicate(true)
	broken.sales["m/i"].count = -1
	_check("a bad sales row is invalid", not Economy.valid(broken))

	# Stock: slicing cannot change the answer.
	var group := {"capacity": 24.0, "per_day": 3.0, "delivery": {"every_days": 7, "at_minute": 420, "units": 12}}
	var whole := ShopStock.advanced_units(10.0, group, 1000.0, 30000.0)
	var sliced := 10.0
	var at := 1000.0
	while at < 30000.0:
		sliced = ShopStock.advanced_units(sliced, group, at, minf(at + 97.0, 30000.0))
		at += 97.0
	_check("slicing does not change stock", absf(whole - sliced) < 0.0001)
	_check("demand empties a shelf with no delivery in reach",
			ShopStock.advanced_units(2.0, group, 421.0, 421.0 + 1440.0) < 2.0)
	_check("a delivery refills it", ShopStock.advanced_units(0.0, group, 419.0, 421.0) >= 11.9)
	_check("capacity holds", ShopStock.advanced_units(24.0, group, 419.0, 421.0) <= 24.0)
	var shop_with_event := {"events": [{"group": "g", "from": "1929-07-01", "until": "1929-08-31", "factor": 2.0, "why": "heat"}]}
	_check("a dated event moves demand", ShopStock.demand_factor(shop_with_event, "g", "1929-07-20") == 2.0
			and ShopStock.demand_factor(shop_with_event, "g", "1929-03-03") == 1.0)
	_check("the save shape is valid", ShopStock.valid(RealityState.data[ShopStock.KEY]))
	_check("a negative level is invalid", not ShopStock.valid({"cursor": 0.0, "groups": {"a": {"b": -1.0}}}))
	var cursor := float(RealityState.data[ShopStock.KEY].cursor)
	stock.advance_to(cursor - 50.0, "1929-03-03")
	_check("a clock handoff backward does not bank time",
			float(RealityState.data[ShopStock.KEY].cursor) == cursor - 50.0)

	# A real stroke through the terminal.
	var shop := "news_cigars"
	var item_id := ""
	for record: Dictionary in catalogue.shops[shop].items:
		if str(record.kind) == "goods" and record.has("group") and not record.has("sold_by"):
			item_id = str(record.id)
			break
	var sales := ShopSales.new(shop, catalogue, stock, clearing)
	var point: Node3D = SalePoint.new()
	add_child(point)
	var list: Array[String] = [item_id]
	_check("a sale point mounts", point.configure(sales, list))
	var record: Dictionary = sales.stock_record(item_id)
	var group_id := str(record.group)
	economy.book().cash = 1000
	var cash := 1000
	var before := stock.units(shop, group_id)
	_stroke(point)
	_check("the stroke debits the price", int(economy.book().cash) == cash - int(record.price_cents))
	_check("one unit leaves the shelf", absf(stock.units(shop, group_id) - (before - 1.0)) < 0.001)
	_check("one goes in the pocket", PersonInventory.goods_count("player", item_id) == 1)
	_check("the flag says settled", point.flag.text == "SETTLED")
	cash = int(economy.book().cash)
	_radio = false
	_stroke(point)
	_check("no carrier refuses", point.flag.text == "NO CARRIER" and int(economy.book().cash) == cash)
	_radio = true
	_line_open = false
	_stroke(point)
	_check("a closed line refuses", point.flag.text == "LINE CLOSED" and int(economy.book().cash) == cash)
	_line_open = true
	RealityState.data[ShopStock.KEY].groups[shop][group_id] = 0.0
	_stroke(point)
	_check("an empty shelf refuses", point.flag.text == "NONE LEFT" and int(economy.book().cash) == cash)
	RealityState.data[ShopStock.KEY].groups[shop][group_id] = 5.0
	economy.book().cash = 0
	if int(record.price_cents) > 0:
		_stroke(point)
		_check("no money refuses", point.flag.text == "NO CREDIT")
	economy.book().cash = 1000
	var grip: Dictionary = point.terminal.grip()
	var count := PersonInventory.goods_count("player", item_id)
	grip.begin.call()
	grip.write.call(0.02)
	grip.end.call()
	_check("a partial stroke does nothing", PersonInventory.goods_count("player", item_id) == count)
	await get_tree().physics_frame
	_check("the commerce state survives the save validator", Economy.valid(economy.book())
			and PersonInventory.valid(RealityState.data.inventories) and ShopStock.valid(RealityState.data[ShopStock.KEY]))
