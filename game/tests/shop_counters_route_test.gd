extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Selling in the production V2 root with the real hand: the Hardware counter's
## selector slides to a stop and its lever settles the sale; the goods land in the
## case; News settles into a single transport slot; the Bodega sells a
## grocery into the bag; a list taken at a door is carried back and paid for.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

var _hand: Node

func _init() -> void:
	route_label = "SHOP COUNTERS ROUTE"

func _prepare_player_start() -> void:
	player.velocity = Vector3.ZERO

func _stand_before(point: Node3D, distance := 0.95) -> void:
	# Stand the player on the customer side: the terminal's lettering faces local -Z.
	var forward: Vector3 = -point.global_basis.z
	player.global_position = point.global_position + forward * distance + Vector3.DOWN * 1.1
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame

func _slide_selector(point: Node3D, goal: float) -> bool:
	await _hand.aim(point.selector.to_global(Vector3(0, .094, -.025)))
	_hand.click()
	if not player._grab.active() or player._grab.target.part != point.selector:
		if player._grab.active():
			_hand.click()
		print("[SHOP COUNTERS] selector not grabbed; hit=", player._grab.last_hit)
		return false
	var moved: bool = await _hand._gesture_to(goal)
	if player._grab.active():
		_hand.click()
	return moved and not player._grab.active()

func _fitted_counter_support(shop_id: String, model_name: String, point: Node3D) -> bool:
	var model := world.passage_region.shop_fitting("shop_" + shop_id,model_name)
	var mesh := model.find_child("*counter__countertop",true,false) as MeshInstance3D if model != null else null
	if mesh == null: return false
	var bounds: AABB = mesh.global_transform * mesh.get_aabb()
	var at := point.global_position
	return absf(at.y-bounds.end.y)<.001 and at.x>bounds.position.x and at.x<bounds.end.x \
		and at.z>bounds.position.z and at.z<bounds.end.z

## The bodega's counter top is the fitted mesh on the authored counter_top record.
## Something rests on it when its foot is at the top face and inside its footprint.
func _bodega_counter_top() -> AABB:
	var shop: Node3D = world.exterior_cell.instance_node("SHOP_BODEGA")
	for draw: MeshInstance3D in shop.find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta("authored_record_id", "")) == "counter_top" and draw.mesh != null:
			return draw.global_transform * draw.get_aabb()
	return AABB()

func _rests_on_bodega_counter(label: String, foot: Vector3, margin := .02) -> bool:
	var top := _bodega_counter_top()
	var inside := top.size != Vector3.ZERO and absf(foot.y - top.end.y) < .005 		and foot.x > top.position.x + margin and foot.x < top.end.x - margin 		and foot.z > top.position.z + margin and foot.z < top.end.z - margin
	print("[SHOP COUNTERS] ", label, " foot=", foot, " counter top=", top, " rests=", inside)
	return inside

func _route() -> void:
	var points: Dictionary = world.shop_counters
	for shop_id: String in ["hardware_paint", "news_cigars", "bodega"]:
		if not _require(points.get(shop_id) is Node3D, shop_id + " has a counter"): return
	if world.passage_region.uses_prepared_geometry():
		if not _require(world.passage_region.uses_prepared_geometry(),"the real world loaded the prepared arcade"): return
		if not _require(_fitted_counter_support("hardware_paint","HardwareStock",points.hardware_paint),
			"Hardware's terminal rests on its relocated native counter"): return
		if not _require(_fitted_counter_support("news_cigars","NewsFittings",points.news_cigars),
			"News's terminal rests on its relocated native counter"): return
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 2000
	_hand = Hands.new()
	_hand.set_meta("shared_world_validation", true)
	add_child(_hand)
	_hand.player = player

	# Hardware: the real hand on the selector, then the lever.
	var hardware: Node3D = points.hardware_paint
	await _stand_before(hardware)
	await _capture_interaction("shop_hardware_counter")
	var chosen: String = hardware.selected_item()
	var moved: bool = await _slide_selector(hardware, 0.05)
	_require(moved, "the real hand moves the selector")
	_require(hardware.selected_item() != chosen, "the selector walks the list")
	chosen = hardware.selected_item()
	var record: Dictionary = hardware.sales.stock_record(chosen)
	var cash := int(economy.book().cash)
	var done: bool = await _hand._stroke(hardware.terminal, hardware.terminal.TRAVEL)
	_require(done, "the real hand strokes the lever")
	_require(int(economy.book().cash) == cash - int(record.price_cents), "the stroke debits the price: " + chosen)
	_require(hardware.flag.text == "SETTLED", "the flag says settled")
	if str(record.kind) in ["goods", "part"]:
		_require(CarriedCase.place_of(chosen).size() > 0, "the goods land in the case")
	await _capture_interaction("shop_hardware_settled")

	# Bodega: a grocery goes in the bag.
	var bodega: Node3D = points.bodega
	await _stand_before(bodega)
	await _capture_interaction("shop_bodega_counter")
	var grocery_at := -1
	for i in bodega.item_ids.size():
		if str(bodega.sales.stock_record(bodega.item_ids[i]).kind) == "grocery":
			grocery_at = i
			break
	_require(bodega.item_ids.size() >= 50, "the Bodega sells the residents' list")
	_require(grocery_at >= 0, "the Bodega sells groceries")
	# The service-area pose left the terminal floating 0.225 m above and behind the
	# fitted top; it is seated now, selector and all.
	_require(_rests_on_bodega_counter("bodega terminal", bodega.global_position), "the Bodega's terminal rests on its counter top")
	_require(_rests_on_bodega_counter("bodega selector", bodega.selector.global_position), "and so does its selector")
	# Aim inside a run of groceries so one stop either side is still a grocery.
	var aim_at := grocery_at
	for i in range(grocery_at, bodega.item_ids.size() - 1):
		if str(bodega.sales.stock_record(bodega.item_ids[i + 1]).kind) == "grocery":
			aim_at = i + 1
			break
	var bodega_moved: bool = await _slide_selector(bodega, bodega._stop_travel(aim_at))
	_require(bodega_moved, "the real hand walks the Bodega's selector down its list")
	var item: String = bodega.selected_item()
	_require(str(bodega.sales.stock_record(item).kind) == "grocery",
			"the hand-chosen stop is a grocery: " + item)
	await _capture_interaction("shop_bodega_selected")
	_require(await _hand._stroke(bodega.terminal, bodega.terminal.TRAVEL), "the real hand settles a grocery")
	_require(bodega.flag.text == "SETTLED", "the Bodega's flag says settled: " + bodega.flag.text)
	_require(PersonInventory.carried("player", item) > 0.0, "and goes in the bag")

	# News: ordinary stock at the counter and newspapers at the rack.
	await _stand_before(points.news_cigars)
	await _capture_interaction("shop_news_counter")
	var news: Node3D = points.news_cigars
	var news_cash := int(economy.book().cash)
	_require(news.selected_item() != "the_borough_record", "the counter leaves papers to the rack")
	_require(await _hand._stroke(news.terminal, news.terminal.TRAVEL), "the real hand settles at News")
	_require(int(economy.book().cash) < news_cash, "News charges its price")
	await _newspaper_sales(economy)

	# An errand, end to end (bodega_list_and_bag_20261124): the list comes from the
	# door into the case, is laid on the bodega counter, the counter fills a sack
	# through its own sales, the real hand lifts the sack, and it goes to the door.
	var errands: ResidentErrands = world.conversations.errands
	var item_use: ItemUse = world.get_node("ItemUse")
	if _require(errands != null and errands.ready() and item_use.errands == errands, "errands are bound to the counter"):
		var resident := ""
		for candidate: String in world.conversations.resident_ids():
			if errands.can_ask(candidate):
				resident = candidate
				break
		if resident == "":
			var kitchens: KitchenLarder = errands.larder
			resident = "omar_bell"
			var unit := kitchens.unit_of(resident)
			kitchens.state.units[unit].stock = {}
		if _require(errands.can_ask(resident), "someone is short: " + resident):
			var words := errands.list_words(resident)
			_require(words != "", "the list is read out: " + words)
			var door: Dictionary = world.conversations.with_errand(resident, world.conversations.trees[resident])
			_require(door.nodes.has(ResidentConversations.ERRAND_ASK) and not errands.has_open(resident),
					"offering the reply takes nothing down")
			var list := ResidentErrands.list_item(resident)
			_require(errands.ask(resident), "the list is written down and handed over")
			_require(PersonInventory.goods_count(PersonInventory.PLAYER, list) == 1 and CarriedCase.place_of(list).size() > 0,
					"the written list is a slip in the case")
			for wanted: String in RealityState.data.resident_errands[resident].items:
				_require(str(errands.larder.groceries.ingredients[wanted].shop) == "bodega", "the list keeps to the bodega's stock: " + wanted)
			_require(not errands.can_deliver(resident), "a list alone cannot be delivered")
			_require(item_use.verb_for(list) == "FOR THE BODEGA COUNTER", "away from the counter the list waits")
			# Fill the bodega's shelves and the purse so the whole list can be packed.
			for group: String in ["icebox", "pantry", "notions"]:
				while world.shop_stock.units("bodega", group) < 40.0 and world.shop_stock.level("bodega", group) != "full":
					world.shop_stock.put_back("bodega", group)
			economy.book().cash = 2000
			await _stand_before(bodega)
			_require(item_use.verb_for(list) == "LAY THE LIST ON THE COUNTER", "at the counter the list is offered: " + item_use.verb_for(list))
			var before_lay := int(economy.book().cash)
			_require(item_use.use(list), "the list is laid on the counter")
			_require(errands.sack_waiting() == resident and PersonInventory.goods_count(PersonInventory.PLAYER, list) == 0,
					"the list is spent and a sack waits on the counter")
			_require(int(economy.book().cash) < before_lay, "the sack is paid for through the counter's settlement")
			var sack: Node3D = bodega.get_node("BodegaErrandSack")
			_require(sack.visible and sack.target_area.collision_layer == 1, "the sack stands on the counter, offered to the hand")
			_require(_rests_on_bodega_counter("bodega sack", sack.global_position), "the sack stands on the counter top itself")
			await _capture_interaction("shop_bodega_sack")
			await _hand.aim(sack.part.to_global(Vector3(0, sack.SIZE.y * 0.6, -sack.SIZE.z * 0.5)))
			_hand.click()
			var gripped: bool = player._grab.active() and player._grab.target.part == sack.part
			if not gripped:
				print("[SHOP COUNTERS] sack not grabbed; hit=", player._grab.last_hit)
				if player._grab.active(): _hand.click()
			_require(gripped, "the real hand takes hold of the sack")
			if gripped:
				var lifted: bool = await _hand._gesture_to(sack.LIFT)
				if player._grab.active(): _hand.click()
				_require(lifted and not player._grab.active(), "mouse motion lifts it and the next click lets go")
			var sack_item := ResidentErrands.sack_item(resident)
			_require(errands.stage(resident) == "carried" and CarriedCase.place_of(sack_item).size() > 0,
					"lifted clear, the sack goes into the case")
			_require(not sack.visible and sack.target_area.collision_layer == 0, "and the counter is clear")
			door = world.conversations.with_errand(resident, world.conversations.trees[resident])
			var short := errands.missing(resident)
			var answer := ResidentConversations.ERRAND_THANKS if short.is_empty() else ResidentConversations.ERRAND_SHORT
			_require(door.nodes.has(answer), "the sack can be handed over at the door, answered as " + answer)
			var sacked: Dictionary = RealityState.data.resident_errands[resident].sack.duplicate()
			var paid := int(economy.book().cash)
			_require(errands.deliver(resident), "the sack is handed over")
			_require(int(economy.book().cash) > paid, "the errand tips")
			_require(PersonInventory.goods_count(PersonInventory.PLAYER, sack_item) == 0, "the sack leaves the case")
			_require(not errands.can_ask(resident), "and not again today")
			for wanted: String in sacked:
				_require(PersonInventory.carried(resident, wanted) > 0.0, "the bag is the resident's: " + wanted)
	# A short sack: the resident notices at the door, and the tip follows what came.
	if errands != null and errands.ready():
		var other := ""
		for candidate: String in world.conversations.resident_ids():
			if errands.larder.unit_of(candidate) != "" and not errands.has_open(candidate) \
					and not RealityState.data.get("resident_errands", {}).has(candidate):
				other = candidate
				break
		if _require(other != "", "a second household for the short sack"):
			var whole := {"milk": 4.0, "butter": 1.0}
			RealityState.data.resident_errands[other] = {"items": whole, "day": 0, "done": false,
				"stage": "carried", "sack": {"milk": 4.0}}
			PersonInventory.carry_goods(PersonInventory.PLAYER, ResidentErrands.sack_item(other), "Paper sack", ResidentErrands.SACK_FORM)
			var short_door: Dictionary = world.conversations.with_errand(other, world.conversations.trees[other])
			var line := str(short_door.nodes.get(ResidentConversations.ERRAND_SHORT, {}).get("line", ""))
			_require(not short_door.nodes.has(ResidentConversations.ERRAND_THANKS) and line.begins_with("That isn't all of it"),
					"the resident notices something is missing: " + line)
			var full_tip := int(economy.book().tips.get("errand:%s:%d" % [other, errands._day()], -1))
			_require(full_tip == -1 and errands.deliver(other), "a short sack is still taken in")
			var tip := int(economy.book().tips.get("errand:%s:%d" % [other, errands._day()], 0))
			_require(tip > 0 and PersonInventory.carried(other, "butter") <= 0.0001, "half a list earns part of a tip, and no butter: %d" % tip)
	# The save boundary: every written snapshot during a fill and a delivery is whole,
	# a crash after the first pack resumes without paying twice, and a crash during
	# delivery leaves the sack in the case with no tip. Real disk writes, real reloads.
	if errands != null and errands.ready():
		await _errand_save_boundary(errands, item_use, economy, bodega)
	_require(ResidentErrands.valid(RealityState.data.get("resident_errands", {})), "errands stay valid")
	await _capture_interaction("shop_news_counter_after")


func _newspaper_sales(economy: Node) -> void:
	var stand := world.passage_region.transaction_actor_root().get_node_or_null("NewsStand") as NewsRackProp
	if not _require(stand != null and stand.sales != null,"the rack knows its counter"): return
	var catalog := stand._catalog()
	var offers := NewsRackProp.offers_for(catalog,catalog.today(),true)
	if not _require(offers.size() >= 2,"the rack offers two published papers"): return
	var first := offers[0]
	var second := offers[1]
	var first_key := NewspaperCatalog.key_of(str(first.paper),str(first.date))
	var second_key := NewspaperCatalog.key_of(str(second.paper),str(second.date))
	var first_price := int(stand.sales.stock_record(NewsRackProp.SALE_ITEMS[first.paper]).price_cents)
	var second_price := int(stand.sales.stock_record(NewsRackProp.SALE_ITEMS[second.paper]).price_cents)
	var stock := stand.sales.stock
	var before := int(economy.book().cash)
	var units := stock.units(stand.sales.shop_id,"papers")
	_require(stand._take(player,catalog,str(first.paper),str(first.date)),"the rack sells the first issue")
	_require(int(economy.book().cash) == before - first_price
		and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units - 1.0),
		"the first issue debits its price and one stock unit")
	_require(catalog.is_collected(str(first.paper),str(first.date)) and PaperPocket.transit_news() == first_key,
		"the first issue is kept in the single transport slot")
	if stand._panel != null: stand._panel.close()
	await get_tree().process_frame

	before = int(economy.book().cash)
	units = stock.units(stand.sales.shop_id,"papers")
	_require(not stand._take(null,catalog,str(second.paper),str(second.date))
		and int(economy.book().cash) == before and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units)
		and not catalog.is_collected(str(second.paper),str(second.date)) and PaperPocket.transit_news() == first_key,
		"a full newspaper slot refuses a second paid issue without changing cash, stock or custody")

	var stack := world.news_stack as NewsStackProp
	if not _require(stack != null,"the apartment's physical stack is mounted"): return
	var filed := stack.count()
	_require(PaperPocket.file_news() and stack.count() == filed + 1 and PaperPocket.has_room_for_news()
		and catalog.is_collected(str(first.paper),str(first.date)),
		"filing moves the kept issue from the slot to the apartment stack")
	economy.book().cash = 0
	_require(not stand._take(null,catalog,str(second.paper),str(second.date))
		and int(economy.book().cash) == 0 and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units)
		and not catalog.is_collected(str(second.paper),str(second.date)) and PaperPocket.has_room_for_news(),
		"short cash refuses a paper with an empty slot and leaves stock and custody intact")

	economy.book().cash = 2000
	_require(stand._take(player,catalog,str(second.paper),str(second.date))
		and int(economy.book().cash) == 2000 - second_price
		and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units - 1.0)
		and PaperPocket.transit_news() == second_key and stack.count() == filed + 1,
		"the next paid issue occupies the freed slot and the first stays on the stack")
	if stand._panel != null: stand._panel.close()
	await get_tree().process_frame


## CaretakerEconomy has no class_name; its saved key.
const ECONOMY_KEY := "caretaker_economy"


func _errand_snapshot_faults(document: Dictionary, resident: String, start: Dictionary) -> Array[String]:
	var faults: Array[String] = []
	var errand: Dictionary = document.get(ResidentErrands.KEY, {}).get(resident, {})
	if errand.is_empty():
		return faults
	var sack: Dictionary = errand.get("sack", {})
	var spent := 0
	var taken := {}
	for item: String in sack:
		var record: Dictionary = start.records[item]
		var packs := roundi(float(sack[item]) / float(record.pack))
		spent += packs * int(record.cents)
		taken[str(record.group)] = int(taken.get(str(record.group), 0)) + packs
	var cash := int(document.get(ECONOMY_KEY, {}).get("cash", -1))
	var paid := int(start.cash) - cash
	if not bool(errand.done) and paid != spent:
		faults.append("cash %d paid against %d packed" % [paid, spent])
	var groups: Dictionary = document.get(ShopStock.KEY, {}).get("groups", {}).get("bodega", {})
	for group: String in start.stock:
		var gone := roundi(float(start.stock[group]) - float(groups.get(group, 0.0)))
		if gone != int(taken.get(group, 0)):
			faults.append("%s stock down %d against %d packed" % [group, gone, int(taken.get(group, 0))])
	var holders: Dictionary = document.get(PersonInventory.KEY, {}).get("holders", {})
	var player: Dictionary = holders.get(PersonInventory.PLAYER, {})
	for item: String in start.pockets:
		var now := float(player.get("grocery:" + item, {}).get("qty", 0.0))
		if absf(now - float(start.pockets[item])) > 0.0001:
			faults.append("pocket %s changed" % item)
	var stage := str(errand.get("stage", ""))
	var has_list := player.has("goods:" + ResidentErrands.list_item(resident))
	var has_sack := player.has("goods:" + ResidentErrands.sack_item(resident))
	if has_list != (stage in ["list", "filling"]):
		faults.append("list custody %s at stage %s" % [has_list, stage])
	var tipped: bool = document.get(ECONOMY_KEY, {}).get("tips", {}).has(start.tip)
	var resident_has: Dictionary = holders.get(resident, {})
	var delivered := not sack.is_empty()
	for item: String in sack:
		var held := float(resident_has.get("grocery:" + item, {}).get("qty", 0.0))
		if held < float(start.resident.get(item, 0.0)) + float(sack[item]) - 0.0001:
			delivered = false
	if bool(errand.done):
		if has_sack or not tipped or not delivered:
			faults.append("done without the whole hand-over: sack=%s tip=%s goods=%s" % [has_sack, tipped, delivered])
	elif tipped or (stage != "carried" and has_sack) or (stage == "carried" and not has_sack):
		faults.append("open errand at %s with sack=%s tip=%s" % [stage, has_sack, tipped])
	return faults


func _errand_save_boundary(errands: ResidentErrands, item_use: ItemUse, economy: Node, bodega: Node3D) -> void:
	var resident := ""
	for candidate: String in world.conversations.resident_ids():
		if errands.larder.unit_of(candidate) != "" and not RealityState.data.get(ResidentErrands.KEY, {}).has(candidate):
			resident = candidate
			break
	if not _require(resident != "", "a third household for the save boundary"):
		return
	var unit := errands.larder.unit_of(resident)
	errands.larder.state.units[unit].stock = {}
	if not _require(errands.can_ask(resident) and errands.ask(resident), "the third list is taken: " + resident):
		return
	var list := ResidentErrands.list_item(resident)
	var wanted: Dictionary = RealityState.data[ResidentErrands.KEY][resident].items
	var packs_needed := 0
	for item: String in wanted:
		var record: Dictionary = bodega.sales.stock_record(item)
		packs_needed += ceili(float(wanted[item]) / float(record.pack) - 0.0001)
	if not _require(packs_needed >= 2, "the list needs at least two packs: %d" % packs_needed):
		return
	for group: String in ["icebox", "pantry", "notions"]:
		while world.shop_stock.units("bodega", group) < 40.0 and world.shop_stock.level("bodega", group) != "full":
			world.shop_stock.put_back("bodega", group)
	economy.book().cash = 2000
	await _stand_before(bodega)
	var original_path := RealityState.save_path
	var original_persistence := RealityState.persistence_enabled
	var path := "user://bodega_errand_boundary_save.json"
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	if not _require(RealityState.save_game(), "the boundary starts from a real disk save"):
		RealityState.save_path = original_path; RealityState.persistence_enabled = original_persistence
		return
	var start := {"cash": int(economy.book().cash), "stock": {}, "pockets": {}, "records": {}, "resident": {},
		"tip": "errand:%s:%d" % [resident, errands._day()]}
	for group: String in ["icebox", "pantry", "notions"]:
		start.stock[group] = world.shop_stock.units("bodega", group)
	for item: String in wanted:
		start.pockets[item] = PersonInventory.carried(PersonInventory.PLAYER, item)
		start.resident[item] = PersonInventory.carried(resident, item)
		start.records[item] = bodega.sales.catalogue.item("bodega", item)
	var watch := {"writes": 0, "faults": [], "crashed": false, "refused": 0, "crash_when": Callable()}
	RealityState.storage_operation_override = func(stage: String, operation: String, arguments: Dictionary) -> Variant:
		if stage != "temp_write" or operation != "write" or not str(arguments.get("path", "")).ends_with(".tmp"):
			return null
		var bytes: PackedByteArray = arguments.bytes
		var candidate: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if candidate is not Dictionary:
			return null
		if watch.crashed:
			watch.refused += 1
			return {"ok": false, "error": ERR_FILE_CANT_WRITE}
		var crash: Callable = watch.crash_when
		if crash.is_valid() and bool(crash.call(candidate)):
			watch.crashed = true
			watch.refused += 1
			return {"ok": false, "error": ERR_FILE_CANT_WRITE}
		watch.writes += 1
		watch.faults.append_array(_errand_snapshot_faults(candidate, resident, start))
		return null
	# Crash on the write that would carry the second pack.
	watch.crash_when = func(candidate: Dictionary) -> bool:
		var sack: Dictionary = candidate.get(ResidentErrands.KEY, {}).get(resident, {}).get("sack", {})
		var packs := 0
		for item: String in sack:
			packs += roundi(float(sack[item]) / float(start.records[item].pack))
		return packs >= 2
	item_use.use(list)
	RealityState.storage_operation_override = Callable()
	RealityState.load_game()
	var errand: Dictionary = RealityState.data.get(ResidentErrands.KEY, {}).get(resident, {})
	var first: Dictionary = errand.get("sack", {})
	var first_cents := 0
	for item: String in first:
		first_cents += roundi(float(first[item]) / float(start.records[item].pack)) * int(start.records[item].cents)
	_require(watch.writes >= 1 and watch.refused >= 1 and watch.faults.is_empty(),
			"every saved snapshot of the fill is whole up to the crash: writes %d refused %d %s" % [watch.writes, watch.refused, watch.faults])
	_require(str(errand.get("stage", "")) == "filling" and first.size() == 1 and first_cents > 0
			and int(economy.book().cash) == int(start.cash) - first_cents,
			"after the crash the save holds exactly the first paid pack: %s cash %d" % [first, int(economy.book().cash)])
	_require(PersonInventory.goods_count(PersonInventory.PLAYER, list) == 1 and CarriedCase.place_of(list).size() > 0,
			"and the list is still in the case")
	# Retry from the reloaded save: the fill resumes and pays each pack once.
	watch.crashed = false; watch.crash_when = Callable(); watch.writes = 0
	RealityState.storage_operation_override = func(stage: String, operation: String, arguments: Dictionary) -> Variant:
		if stage == "temp_write" and operation == "write" and str(arguments.get("path", "")).ends_with(".tmp"):
			var candidate: Variant = JSON.parse_string((arguments.bytes as PackedByteArray).get_string_from_utf8())
			if candidate is Dictionary:
				watch.writes += 1
				watch.faults.append_array(_errand_snapshot_faults(candidate, resident, start))
		return null
	_require(item_use.verb_for(list) == "LAY THE LIST ON THE COUNTER" and item_use.use(list), "the reloaded list is laid again")
	var sack: Dictionary = RealityState.data[ResidentErrands.KEY][resident].get("sack", {})
	var total := 0
	var taken := {}
	for item: String in sack:
		var packs := roundi(float(sack[item]) / float(start.records[item].pack))
		total += packs * int(start.records[item].cents)
		taken[str(start.records[item].group)] = int(taken.get(str(start.records[item].group), 0)) + packs
	var stock_exact := true
	for group: String in start.stock:
		stock_exact = stock_exact and roundi(float(start.stock[group]) - world.shop_stock.units("bodega", group)) == int(taken.get(group, 0))
	_require(errands.sack_waiting() == resident and int(economy.book().cash) == int(start.cash) - total and stock_exact,
			"the resumed fill pays each pack once: cash %d of %d, stock exact %s" % [int(start.cash) - int(economy.book().cash), total, stock_exact])
	_require(errands.take_sack(resident), "the sack is taken up")
	# Crash on the delivery's commit, then reload.
	var before_delivery := int(economy.book().cash)
	watch.crash_when = func(candidate: Dictionary) -> bool:
		return bool(candidate.get(ResidentErrands.KEY, {}).get(resident, {}).get("done", false))
	var observe: Callable = RealityState.storage_operation_override
	RealityState.storage_operation_override = func(stage: String, operation: String, arguments: Dictionary) -> Variant:
		if stage == "temp_write" and operation == "write" and str(arguments.get("path", "")).ends_with(".tmp"):
			var candidate: Variant = JSON.parse_string((arguments.bytes as PackedByteArray).get_string_from_utf8())
			if watch.crashed or (candidate is Dictionary and (watch.crash_when as Callable).call(candidate)):
				watch.crashed = true
				return {"ok": false, "error": ERR_FILE_CANT_WRITE}
		return observe.call(stage, operation, arguments)
	errands.deliver(resident)
	RealityState.storage_operation_override = Callable()
	RealityState.load_game()
	errand = RealityState.data[ResidentErrands.KEY][resident]
	_require(not bool(errand.done) and str(errand.stage) == "carried"
			and PersonInventory.goods_count(PersonInventory.PLAYER, ResidentErrands.sack_item(resident)) == 1
			and not economy.book().tips.has(start.tip) and int(economy.book().cash) == before_delivery
			and sack.keys().all(func(item): return absf(PersonInventory.carried(resident, str(item)) - float(start.resident.get(item, 0.0))) < 0.0001),
			"a crash during delivery leaves the sack in the case, the resident without it, and no tip")
	watch.crashed = false; watch.crash_when = Callable()
	RealityState.storage_operation_override = observe
	_require(errands.deliver(resident), "the reloaded sack is handed over")
	RealityState.storage_operation_override = Callable()
	RealityState.load_game()
	errand = RealityState.data[ResidentErrands.KEY][resident]
	var tips: Dictionary = economy.book().tips
	_require(bool(errand.done) and tips.has(start.tip) and not errands.deliver(resident)
			and PersonInventory.goods_count(PersonInventory.PLAYER, ResidentErrands.sack_item(resident)) == 0
			and sack.keys().all(func(item): return PersonInventory.carried(resident, str(item)) >= float(start.resident.get(item, 0.0)) + float(sack[item]) - 0.0001),
			"reloaded after delivery: the groceries are the resident's and the one tip is paid")
	_require(watch.faults.is_empty(), "every saved snapshot across the boundary is whole: %s" % [watch.faults])
	RealityState.save_path = original_path
	RealityState.persistence_enabled = original_persistence
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
