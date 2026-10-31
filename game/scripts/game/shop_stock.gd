class_name ShopStock
extends Node
## Stock levels by group for every shop: demand wears a group down and dated
## deliveries fill it up. The result does not depend on how time is sliced, so
## catch-up after a save is the same as having watched it happen. RealityState
## owns durability; ShopCatalogue owns the rules; there is no second clock.

signal level_changed(shop_id: String, group_id: String, level: String)

const KEY := "shop_stock"
const FULL := "full"
const THIN := "thin"
const OUT := "out"
const THIN_BELOW := 0.34
const POLL_SECONDS := 1.0
## A longer absence than this cannot change a level any further.
const MAX_CATCH_UP_MINUTES := 57600.0
const DAY := 1440.0

var catalogue: ShopCatalogue
var _clock := CampaignClock.new()
var _accumulator := 0.0


func setup(shops: ShopCatalogue) -> bool:
	catalogue = shops
	if catalogue == null or not catalogue.errors.is_empty() or not _clock.bind_state():
		return false
	_ensure()
	return valid(RealityState.data[KEY])


static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("cursor")) not in [TYPE_INT, TYPE_FLOAT] \
			or not is_finite(float(value.cursor)) or value.get("groups") is not Dictionary:
		return false
	for shop_id: Variant in value.groups:
		if shop_id is not String or value.groups[shop_id] is not Dictionary:
			return false
		for group_id: Variant in value.groups[shop_id]:
			var units: Variant = value.groups[shop_id][group_id]
			if group_id is not String or typeof(units) not in [TYPE_INT, TYPE_FLOAT] \
					or not is_finite(float(units)) or float(units) < 0.0:
				return false
	return true


func _ensure() -> void:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"cursor": _clock.absolute_minutes(), "groups": {}}
	var state: Dictionary = RealityState.data[KEY]
	for shop_id: String in catalogue.shop_ids():
		if not state.groups.has(shop_id):
			state.groups[shop_id] = {}
		for group_id: String in catalogue.shops[shop_id].groups:
			if not state.groups[shop_id].has(group_id):
				state.groups[shop_id][group_id] = float(catalogue.shops[shop_id].groups[group_id].capacity)


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator < POLL_SECONDS or catalogue == null:
		return
	_accumulator = 0.0
	if _clock.bind_state() and not RealityState.save_write_blocked:
		advance_to(_clock.absolute_minutes(), _today())


func _today() -> String:
	var local := _clock.local_datetime()
	return "" if local.is_empty() else "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]


## Bring every group up to this absolute minute. Time running backward (a clock
## handoff) moves the cursor and changes nothing.
func advance_to(to_minute: float, date: String) -> void:
	_ensure()
	var state: Dictionary = RealityState.data[KEY]
	var from_minute := float(state.cursor)
	if not is_finite(to_minute):
		return
	if to_minute <= from_minute:
		state.cursor = to_minute
		return
	from_minute = maxf(from_minute, to_minute - MAX_CATCH_UP_MINUTES)
	for shop_id: String in catalogue.shop_ids():
		var shop: Dictionary = catalogue.shops[shop_id]
		for group_id: String in shop.groups:
			var before := level(shop_id, group_id)
			state.groups[shop_id][group_id] = advanced_units(float(state.groups[shop_id][group_id]),
					shop.groups[group_id], from_minute, to_minute, demand_factor(shop, group_id, date))
			var after := level(shop_id, group_id)
			if after != before:
				level_changed.emit(shop_id, group_id, after)
	state.cursor = to_minute


## How a dated event moves demand. A factor of 0 stops sales pressure; a shortage
## is authored by removing a delivery's item from the catalogue, not here.
static func demand_factor(shop: Dictionary, group_id: String, date: String) -> float:
	var factor := 1.0
	for event: Dictionary in shop.get("events", []):
		if str(event.group) == group_id and date >= str(event.from) and date <= str(event.until):
			factor *= float(event.factor)
	return factor


## Pure: walks delivery boundaries in order, so any slicing gives one answer.
static func advanced_units(units: float, group: Dictionary, from_minute: float,
		to_minute: float, factor := 1.0) -> float:
	var delivery: Dictionary = group.delivery
	var period := float(delivery.every_days) * DAY
	var offset := float(delivery.at_minute)
	var capacity := float(group.capacity)
	var per_minute := float(group.per_day) * factor / DAY
	var at := from_minute
	while at < to_minute:
		var next: float = offset + (floorf((at - offset) / period) + 1.0) * period
		var until := minf(next, to_minute)
		units = maxf(0.0, units - per_minute * (until - at))
		if is_equal_approx(until, next) or until == next:
			units = minf(capacity, units + float(delivery.units))
		at = until
	return units


func units(shop_id: String, group_id: String) -> float:
	_ensure()
	return float(RealityState.data[KEY].groups.get(shop_id, {}).get(group_id, 0.0))


func level(shop_id: String, group_id: String) -> String:
	var capacity := float(catalogue.shops.get(shop_id, {}).get("groups", {}).get(group_id, {}).get("capacity", 0.0))
	var left := units(shop_id, group_id)
	if capacity <= 0.0 or left < 1.0:
		return OUT
	return THIN if left / capacity < THIN_BELOW else FULL


## One unit leaves the shelf. Uncommitted: the caller's settlement saves it.
func take(shop_id: String, group_id: String) -> bool:
	if units(shop_id, group_id) < 1.0:
		return false
	var before := level(shop_id, group_id)
	RealityState.data[KEY].groups[shop_id][group_id] = units(shop_id, group_id) - 1.0
	var after := level(shop_id, group_id)
	if after != before:
		level_changed.emit(shop_id, group_id, after)
	return true


## Undo a take when delivery fails, so stock and money always move together.
func put_back(shop_id: String, group_id: String) -> void:
	RealityState.data[KEY].groups[shop_id][group_id] = units(shop_id, group_id) + 1.0
