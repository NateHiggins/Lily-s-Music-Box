class_name KitchenLarder
extends RefCounted
## Every household's pantry and icebox (design/ORISON_KITCHENS_2026-10-24.md).
##
## Each resident has one dish in the house cookbook (data/kitchen/cookbook.json)
## made from what the bodega and the Arcade sell (data/kitchen/groceries.json).
## The larder answers what a household is short of, where to buy it, whether
## the dish can be cooked, whether there is anything left to eat and whether
## the washing-up has got past what that household tolerates
## (apartment_life_profiles.json cleanliness). The resident agenda decides
## when; the larder applies shopping, cooking, eating, washing up and spoilage
## to durable stock, stamped in campaign minutes so a repeated event is
## refused rather than applied twice.

const GROCERIES := "res://data/kitchen/groceries.json"
const COOKBOOK := "res://data/kitchen/cookbook.json"
const PROFILES := "res://data/apartment_life_profiles.json"
const STATE_KEY := "household_larders"
## How many recent household events the save keeps.
var event_limit := 80
const SHELF_ROWS := 4

## A household's stock changed: its icebox should be restocked.
signal changed(unit: String)

var groceries: Dictionary = {}
var cookbook: Dictionary = {}
var errors: Array[String] = []
var state: Dictionary = {}
var _dishes: Dictionary = {}
var _units: Dictionary = {}
var _limits: Dictionary = {}
var _commit := Callable()


## residents: resident id -> unit. Validates every dish against the shops.
func load_data(residents: Dictionary) -> bool:
	errors.clear()
	var g: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROCERIES))
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(COOKBOOK))
	if g is not Dictionary or c is not Dictionary or float(g.get("schema_version", 0)) != 1.0 \
			or float(c.get("schema_version", 0)) != 1.0:
		errors.append("kitchen data unreadable")
		return false
	groceries = g
	cookbook = c
	_units = residents.duplicate()
	for item: String in groceries.ingredients:
		var record: Dictionary = groceries.ingredients[item]
		if not groceries.shops.has(str(record.shop)) or float(record.pack) <= 0.0 \
				or str(record.storage) not in ["pantry", "icebox"] or str(record.name) == "" \
				or str(record.unit) == "" or float(record.cents) < 0.0 or float(record.keeps_days) <= 0.0:
			errors.append("grocery malformed: " + item)
	for dish: Dictionary in cookbook.dishes:
		var resident := str(dish.resident)
		if not _units.has(resident):
			errors.append("dish for an unknown resident: " + str(dish.id))
			continue
		if _dishes.has(resident):
			errors.append("two dishes for " + resident)
		for row: Array in dish.ingredients:
			if not groceries.ingredients.has(str(row[0])) or float(row[1]) <= 0.0:
				errors.append("%s: unknown or empty ingredient %s" % [dish.id, row[0]])
		if int(dish.serves) < 1 or int(dish.washing_up) < 0 or int(dish.minutes) < 1 or dish.method.is_empty():
			errors.append("dish malformed: " + str(dish.id))
		# Every page the cookbook prints: whose, from where, the twist, the note,
		# and the compiler's red pencil where one was owed.
		if str(dish.name) == "" or str(dish.origin) == "" or str(dish.twist) == "" or str(dish.note) == "" \
				or not (dish.red_pencil == null or dish.red_pencil is String):
			errors.append("dish page incomplete: " + str(dish.id))
		_dishes[resident] = dish
	for resident: String in _units:
		if not _dishes.has(resident):
			errors.append("no dish for " + resident)
	for field in [cookbook.title, cookbook.subtitle, cookbook.compiled_by, cookbook.foreword]:
		if str(field) == "":
			errors.append("cookbook front matter incomplete")
	for look: String in groceries.pantry_looks:
		var spec: Dictionary = groceries.pantry_looks[look]
		if str(spec.shape) not in ["box", "cylinder"] or spec.size.size() != 3 or spec.tint.size() != 3 \
				or not MatLib.SETS.has(str(spec.material)):
			errors.append("pantry look malformed: " + look)
	for item: String in groceries.ingredients:
		if str(groceries.ingredients[item].storage) == "icebox" and not groceries.icebox_looks.has(item):
			errors.append("icebox goods with no look: " + item)
		if str(groceries.ingredients[item].storage) == "pantry" \
				and not groceries.pantry_looks.has(str(groceries.pantry_shapes.get(str(groceries.ingredients[item].unit), ""))):
			errors.append("pantry goods with no look: " + item)
	var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
	if profiles is Dictionary:
		for profile: Dictionary in profiles.profiles:
			# The tidy wash up after every meal; the untidy let it stack.
			_limits[str(profile.unit)] = 1 + int(round((1.0 - float(profile.cleanliness)) * 8.0))
	return errors.is_empty()


## Bind durable stock: `store` is the save dictionary (RealityState.data) and
## commit persists it. Missing households are seeded from their dishes.
func bind(store: Dictionary, commit := Callable()) -> bool:
	if not store.has(STATE_KEY) or not valid(store[STATE_KEY]):
		store[STATE_KEY] = {"units": {}, "events": []}
	state = store[STATE_KEY]
	_commit = commit
	for resident: String in _units:
		var unit := str(_units[resident])
		if not state.units.has(unit):
			state.units[unit] = {"stock": {}, "portions": 0, "dish": "", "cooked": -1.0, "dirty": 0}
			_seed(unit)
	return true


static func valid(value: Variant) -> bool:
	if value is not Dictionary or (value as Dictionary).get("units") is not Dictionary \
			or (value as Dictionary).get("events") is not Array:
		return false
	for unit: Variant in value.units.values():
		if unit is not Dictionary or unit.get("stock") is not Dictionary:
			return false
		for key in ["portions", "dirty", "cooked"]:
			if typeof(unit.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
				return false
		for batch: Variant in unit.stock.values():
			if batch is not Dictionary or typeof(batch.get("qty")) not in [TYPE_INT, TYPE_FLOAT] \
					or typeof(batch.get("bought")) not in [TYPE_INT, TYPE_FLOAT]:
				return false
	return true


## One batch of every long-keeping pantry good for the flat's dishes, and
## a few days' soap and matches; the icebox starts bare.
func _seed(unit: String) -> void:
	var stock: Dictionary = state.units[unit].stock
	for resident: String in _units:
		if str(_units[resident]) != unit:
			continue
		for row: Array in _dishes[resident].ingredients:
			var record: Dictionary = groceries.ingredients[str(row[0])]
			if str(record.storage) == "pantry" and float(record.keeps_days) >= 60.0:
				stock[str(row[0])] = {"qty": float(stock.get(str(row[0]), {}).get("qty", 0.0)) + float(row[1]), "bought": 0.0}
	for item in ["soap_flakes", "scouring_powder", "matches"]:
		stock[item] = {"qty": 3.0, "bought": 0.0}


## ---- questions -------------------------------------------------------

func dish_of(resident: String) -> Dictionary:
	return _dishes.get(resident, {})


func unit_of(resident: String) -> String:
	return str(_units.get(resident, ""))


func qty(unit: String, item: String) -> float:
	return float(state.units.get(unit, {}).get("stock", {}).get(item, {}).get("qty", 0.0))


## What this resident's household lacks to cook their dish once and keep the
## kitchen going: item -> amount short. What the resident is already carrying
## home counts as had, so nobody goes back for it.
func missing(resident: String) -> Dictionary:
	return _short(resident, true)


func _short(resident: String, count_carried: bool) -> Dictionary:
	var unit := unit_of(resident)
	var out := {}
	if not _dishes.has(resident) or not state.get("units", {}).has(unit):
		return out
	var needs := {}
	for row: Array in _dishes[resident].ingredients:
		needs[str(row[0])] = float(needs.get(str(row[0]), 0.0)) + float(row[1])
	for item: String in groceries.household.lighting:
		needs[item] = maxf(float(needs.get(item, 0.0)), float(groceries.household.lighting[item]))
	for item: String in groceries.household.washing_up:
		needs[item] = maxf(float(needs.get(item, 0.0)), float(groceries.household.washing_up[item]))
	for item: String in needs:
		var had := qty(unit, item) + (PersonInventory.carried(resident, item) if count_carried else 0.0)
		if float(needs[item]) - had > 0.0001:
			out[item] = float(needs[item]) - had
	return out


## The shop to go to next: the open one that sells most of what is missing.
func shopping_stop(resident: String, minute: int) -> String:
	var counts := {}
	for item: String in missing(resident):
		var shop := str(groceries.ingredients[item].shop)
		if open_at(shop, minute):
			counts[shop] = int(counts.get(shop, 0)) + 1
	var best := ""
	for shop: String in counts:
		if best == "" or int(counts[shop]) > int(counts[best]) or (int(counts[shop]) == int(counts[best]) and shop < best):
			best = shop
	return best


func open_at(shop: String, minute: int) -> bool:
	var closed: Array = groceries.shops.get(shop, {}).get("closed", [])
	return closed.is_empty() or minute < int(closed[0]) or minute >= int(closed[1])


## Everything for the dish is in the larder itself, not still in the bag.
func can_cook(resident: String) -> bool:
	return _dishes.has(resident) and _short(resident, false).is_empty()


func portions(unit: String) -> int:
	return int(state.units.get(unit, {}).get("portions", 0))


func dirty(unit: String) -> int:
	return int(state.units.get(unit, {}).get("dirty", 0))


func dirty_limit(unit: String) -> int:
	return int(_limits.get(unit, 4))


## What the icebox shows: one FridgeProp larder row per cold item in stock
## ([label, tint, width, height, shelf], native food stock shapes), the
## covered dish of leftovers, at most SHELF_ROWS to a shelf.
func icebox_rows(unit: String) -> Array:
	var rows: Array = []
	var per_shelf := {}
	var record: Dictionary = state.get("units", {}).get(unit, {})
	if record.is_empty():
		return rows
	var wanted: Array[String] = []
	if int(record.portions) > 0:
		wanted.append("leftovers")
	var stocked: Array = record.stock.keys()
	stocked.sort()
	for item: String in stocked:
		if float(record.stock[item].qty) > 0.0 and groceries.icebox_looks.has(item):
			wanted.append(item)
	for item in wanted:
		var look: Array = groceries.icebox_looks[item]
		var shelf := int(look[4])
		if int(per_shelf.get(shelf, 0)) >= SHELF_ROWS:
			continue
		per_shelf[shelf] = int(per_shelf.get(shelf, 0)) + 1
		var tint: Array = look[3]
		rows.append([str(look[0]), Color(float(tint[0]), float(tint[1]), float(tint[2])),
				float(look[1]), float(look[2]), shelf])
	return rows


## What the work table shows: [item, look, name] for pantry goods in stock,
## the flat's dishes' goods first, then the household's, at most `limit`.
func pantry_rows(unit: String, limit := 8) -> Array:
	var rows: Array = []
	var record: Dictionary = state.get("units", {}).get(unit, {})
	if record.is_empty():
		return rows
	var order: Array[String] = []
	for resident: String in _units:
		if str(_units[resident]) == unit:
			for row: Array in _dishes[resident].ingredients:
				if not order.has(str(row[0])):
					order.append(str(row[0]))
	for item in ["soap_flakes", "scouring_powder", "matches"]:
		order.append(item)
	for item in order:
		var goods: Dictionary = groceries.ingredients[item]
		if str(goods.storage) != "pantry" or qty(unit, item) <= 0.0:
			continue
		rows.append([item, str(groceries.pantry_shapes[str(goods.unit)]), str(goods.name)])
		if rows.size() >= limit:
			break
	return rows


## ---- events ----------------------------------------------------------

## Buys whole packs of what is short at this counter; they go into the
## shopper's bag (PersonInventory), not the larder, until they get home.
func shop(resident: String, shop_id: String, stamp: float) -> Array[String]:
	var unit := unit_of(resident)
	var bought: Array[String] = []
	var cents := 0
	var short := missing(resident)
	for item: String in short:
		var record: Dictionary = groceries.ingredients[item]
		if str(record.shop) != shop_id:
			continue
		var packs := 0.0
		while packs < float(short[item]) - 0.0001:
			packs += float(record.pack)
			cents += int(record.cents)
		PersonInventory.carry(resident, item, packs)
		bought.append(item)
	if not bought.is_empty():
		_log(stamp, unit, resident, "shopped", "%s at %s, %d cents" % [", ".join(bought), groceries.shops[shop_id].name, cents])
	return bought


## Home again: everything in the resident's bag goes into the household's
## pantry and icebox, stamped as bought now.
func unpack(resident: String, stamp: float) -> Array[String]:
	var unit := unit_of(resident)
	var put: Array[String] = []
	if not state.get("units", {}).has(unit):
		return put
	var bag := PersonInventory.unpack(resident)
	for item: String in bag:
		var batch: Dictionary = state.units[unit].stock.get(item, {"qty": 0.0, "bought": stamp})
		batch.qty = float(batch.qty) + float(bag[item])
		batch.bought = stamp
		state.units[unit].stock[item] = batch
		put.append(item)
	if not put.is_empty():
		put.sort()
		_log(stamp, unit, resident, "unpacked", ", ".join(put))
	return put


## Cooks the resident's dish if everything is in; otherwise a plain supper
## from eggs and bread if there are any. Returns "dish", "plain" or "".
func cook(resident: String, stamp: float) -> String:
	var unit := unit_of(resident)
	if not state.get("units", {}).has(unit):
		return ""
	var record: Dictionary = state.units[unit]
	if can_cook(resident):
		for row: Array in _dishes[resident].ingredients:
			_use(unit, str(row[0]), float(row[1]))
		for item: String in groceries.household.lighting:
			_use(unit, item, float(groceries.household.lighting[item]))
		record.portions = int(_dishes[resident].serves)
		record.dish = str(_dishes[resident].id)
		record.cooked = stamp
		record.dirty = int(record.dirty) + int(_dishes[resident].washing_up)
		_log(stamp, unit, resident, "cooked", str(_dishes[resident].name))
		return "dish"
	var plain: Dictionary = groceries.household.plain_supper
	for item: String in plain:
		if qty(unit, item) < float(plain[item]):
			return ""
	for item: String in plain:
		_use(unit, item, float(plain[item]))
	record.portions = int(record.portions) + 1
	record.dirty = int(record.dirty) + 1
	record.cooked = stamp
	_log(stamp, unit, resident, "cooked", "a plain supper of eggs and bread")
	return "plain"


## Takes one portion of whatever is cooked; leaves a plate to wash.
func eat(resident: String, stamp: float) -> bool:
	var unit := unit_of(resident)
	if portions(unit) <= 0:
		return false
	state.units[unit].portions = portions(unit) - 1
	state.units[unit].dirty = dirty(unit) + 1
	_log(stamp, unit, resident, "ate", _dish_name(str(state.units[unit].dish)))
	return true


func wash_up(resident: String, stamp: float) -> int:
	var unit := unit_of(resident)
	var stack := dirty(unit)
	if stack <= 0:
		return 0
	var washes := ceili(float(stack) / 6.0)
	for item: String in groceries.household.washing_up:
		_use(unit, item, float(groceries.household.washing_up[item]) * washes)
	state.units[unit].dirty = 0
	_log(stamp, unit, resident, "washed up", "%d pieces" % stack)
	return stack


## Ice melts and milk turns: drop what has outlived its keeping days, and
## leftovers after their own.
func spoil(stamp: float) -> void:
	for unit: String in state.get("units", {}):
		var record: Dictionary = state.units[unit]
		for item: String in record.stock.keys():
			var batch: Dictionary = record.stock[item]
			var keeps := float(groceries.ingredients.get(item, {}).get("keeps_days", 365)) * 1440.0
			if float(batch.qty) > 0.0 and float(batch.bought) > 0.0 and stamp - float(batch.bought) > keeps:
				_log(stamp, unit, "", "spoiled", str(groceries.ingredients[item].name))
				batch.qty = 0.0
		if int(record.portions) > 0 and stamp - float(record.cooked) > float(groceries.household.leftovers_keep_days) * 1440.0:
			_log(stamp, unit, "", "spoiled", "the last of the " + _dish_name(str(record.dish)))
			record.portions = 0
			record.dirty = int(record.dirty) + 1


func _use(unit: String, item: String, amount: float) -> void:
	var batch: Dictionary = state.units[unit].stock.get(item, {"qty": 0.0, "bought": 0.0})
	batch.qty = maxf(0.0, float(batch.qty) - amount)
	state.units[unit].stock[item] = batch


func _dish_name(id: String) -> String:
	for dish: Dictionary in cookbook.get("dishes", []):
		if str(dish.id) == id:
			return str(dish.name)
	return "supper"


func _log(stamp: float, unit: String, resident: String, what: String, detail: String) -> void:
	state.events.append({"at": stamp, "unit": unit, "resident": resident, "what": what, "detail": detail})
	while state.events.size() > event_limit:
		state.events.pop_front()
	if _commit.is_valid():
		_commit.call()
	changed.emit(unit)
