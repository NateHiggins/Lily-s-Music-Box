class_name ResidentErrands
extends RefCounted
## A resident short of groceries gives the player a written list at the door. The
## player lays it on the bodega counter, the counter fills a paper sack through the
## shop's own sales, and the player carries the sack back. The resident notices at
## the door if something is missing, and puts the rest away to cook through the
## existing KitchenLarder. One errand per resident per day; the tip and goodwill
## stay inside CaretakerEconomy's caps. Errands never touch a case or a mystery flag.
##
## Lily's ruling bodega_list_and_bag_20261124 (2026-11-24). An errand taken down
## before that ruling has no stage and is still settled from the player's pockets.

signal sack_changed

const KEY := "resident_errands"
const LIST_LIMIT := 4
const DAY := 1440.0
const SHOP := "bodega"
const LIST_PREFIX := "errand_list:"
const SACK_PREFIX := "errand_sack:"
const LIST_FORM := "card"
const SACK_FORM := "parcel"
## stage: "list" in the case, "sack" waiting on the counter, "carried" in the case.
const STAGES := ["list", "sack", "carried"]

var larder: KitchenLarder
var economy: Node
var _clock := CampaignClock.new()


func setup(kitchens: KitchenLarder, ledger: Node) -> void:
	larder = kitchens
	economy = ledger


static func valid(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	for resident: Variant in value:
		var errand: Variant = value[resident]
		if resident is not String or errand is not Dictionary or errand.get("items") is not Dictionary \
				or typeof(errand.get("day")) not in [TYPE_INT, TYPE_FLOAT] or errand.get("done") is not bool:
			return false
		if errand.has("stage") and str(errand.stage) not in STAGES:
			return false
		if errand.has("sack"):
			if errand.sack is not Dictionary:
				return false
			for item: Variant in errand.sack:
				if item is not String or typeof(errand.sack[item]) not in [TYPE_INT, TYPE_FLOAT] \
						or not is_finite(float(errand.sack[item])) or float(errand.sack[item]) < 0.0:
					return false
	return true


func _book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {}
	return RealityState.data[KEY]


func _day() -> int:
	_clock.bind_state()
	return int(_clock.elapsed_minutes() / DAY)


func minutes() -> float:
	_clock.bind_state()
	return _clock.elapsed_minutes()


func ready() -> bool:
	return larder != null and economy != null


static func list_item(resident: String) -> String:
	return LIST_PREFIX + resident


static func sack_item(resident: String) -> String:
	return SACK_PREFIX + resident


## The resident whose list or sack this case good is, or "".
static func resident_of(item: String) -> String:
	for prefix: String in [LIST_PREFIX, SACK_PREFIX]:
		if item.begins_with(prefix):
			return item.trim_prefix(prefix)
	return ""


## A list is on offer: nothing open or done today, and the resident is short of
## something the bodega sells.
func can_ask(resident: String) -> bool:
	if not ready() or larder.unit_of(resident) == "":
		return false
	var errand: Dictionary = _book().get(resident, {})
	if not errand.is_empty() and (not bool(errand.done) or int(errand.day) == _day()):
		return false
	return not _list(resident).is_empty()


## The bodega's errand: only what the bodega itself sells goes on the list.
func _list(resident: String) -> Dictionary:
	var items := {}
	var short: Dictionary = larder.missing(resident)
	var ids := short.keys()
	ids.sort()
	for item: String in ids:
		if items.size() >= LIST_LIMIT:
			break
		var row: Dictionary = larder.groceries.get("ingredients", {}).get(item, {})
		if str(row.get("shop", "")) != SHOP:
			continue
		items[item] = float(short[item])
	return items


func _name(item: String) -> String:
	return str(larder.groceries.ingredients[item].name)


## What the door says, without taking anything down yet.
func list_words(resident: String) -> String:
	var names: PackedStringArray = []
	for item: String in _list(resident):
		names.append(_name(item))
	return ", ".join(names)


## The list is written down and handed over: a slip in the case. A full case
## takes nothing, and the offer stays open.
func ask(resident: String) -> bool:
	var unit := larder.unit_of(resident)
	if not PersonInventory.carry_goods(PersonInventory.PLAYER, list_item(resident),
			"Grocery list, %s" % unit, LIST_FORM):
		return false
	_book()[resident] = {"items": _list(resident), "day": _day(), "done": false, "stage": "list"}
	RealityState.commit()
	return true


func has_open(resident: String) -> bool:
	var errand: Dictionary = _book().get(resident, {})
	return not errand.is_empty() and not bool(errand.done)


func stage(resident: String) -> String:
	return str(_book().get(resident, {}).get("stage", ""))


## The resident whose sack stands on the bodega counter, or "".
func sack_waiting() -> String:
	for resident: String in _book():
		var errand: Dictionary = _book()[resident]
		if not bool(errand.done) and str(errand.get("stage", "")) == "sack":
			return resident
	return ""


func can_lay(resident: String) -> bool:
	return has_open(resident) and stage(resident) == "list" and sack_waiting() == "" \
			and PersonInventory.goods_count(PersonInventory.PLAYER, list_item(resident)) > 0


## The list goes on the counter and the counter fills a sack, line by line through
## the shop's own settlement: stock, the radio and the ledger refuse as they would at
## the lever, and a refused line stays out of the sack. If nothing at all can be
## packed, the list stays in the case.
func lay(resident: String, sales: ShopSales) -> bool:
	if not can_lay(resident) or sales == null or sales.shop_id != SHOP:
		return false
	var errand: Dictionary = _book()[resident]
	var sack := {}
	for item: String in errand.items:
		var record := sales.stock_record(item)
		if record.is_empty() or str(record.get("kind", "")) != "grocery":
			continue
		var pack := float(record.get("pack", 1.0))
		if pack <= 0.0:
			continue
		var wanted := float(errand.items[item])
		while float(sack.get(item, 0.0)) + 0.0001 < wanted:
			if sales.transaction_status(item) != "available":
				break
			var packed := sales.transact_delivering(item, SHOP, func() -> bool:
				# The sale put the pack in the pockets; it goes into the sack instead.
				PersonInventory.lose(PersonInventory.PLAYER, item, pack)
				sack[item] = float(sack.get(item, 0.0)) + pack
				return true)
			if not packed:
				break
	if sack.is_empty():
		return false
	if not PersonInventory.spend_goods(PersonInventory.PLAYER, list_item(resident)):
		return false
	errand.stage = "sack"
	errand.sack = sack
	RealityState.commit()
	sack_changed.emit()
	return true


## The hand lifts the sack off the counter into the case.
func take_sack(resident: String) -> bool:
	if not has_open(resident) or stage(resident) != "sack":
		return false
	if not PersonInventory.carry_goods(PersonInventory.PLAYER, sack_item(resident),
			"Paper sack, %s" % larder.unit_of(resident), SACK_FORM):
		return false
	_book()[resident].stage = "carried"
	RealityState.commit()
	sack_changed.emit()
	return true


func _legacy(errand: Dictionary) -> bool:
	return not errand.has("stage")


func can_deliver(resident: String) -> bool:
	var errand: Dictionary = _book().get(resident, {})
	if errand.is_empty() or bool(errand.done):
		return false
	if not _legacy(errand):
		return str(errand.stage) == "carried" \
				and PersonInventory.goods_count(PersonInventory.PLAYER, sack_item(resident)) > 0
	for item: String in errand.items:
		if PersonInventory.carried(PersonInventory.PLAYER, item) + 0.0001 < float(errand.items[item]):
			return false
	return true


## The names of whatever the sack is short of, in list order.
func missing(resident: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var errand: Dictionary = _book().get(resident, {})
	if errand.is_empty() or _legacy(errand):
		return out
	var sack: Dictionary = errand.get("sack", {})
	for item: String in errand.items:
		if float(sack.get(item, 0.0)) + 0.0001 < float(errand.items[item]):
			out.append(_name(item))
	return out


## The share of the list that arrived, line by line.
func _completeness(errand: Dictionary) -> float:
	if errand.items.is_empty():
		return 1.0
	var sack: Dictionary = errand.get("sack", {})
	var total := 0.0
	for item: String in errand.items:
		total += clampf(float(sack.get(item, 0.0)) / maxf(float(errand.items[item]), 0.0001), 0.0, 1.0)
	return total / float(errand.items.size())


## The sack passes from the case to the resident's bag, contents and all.
func deliver(resident: String) -> bool:
	if not can_deliver(resident):
		return false
	var errand: Dictionary = _book()[resident]
	var completeness := 1.0
	if _legacy(errand):
		for item: String in errand.items:
			var amount := float(errand.items[item])
			PersonInventory.lose(PersonInventory.PLAYER, item, amount)
			PersonInventory.carry(resident, item, amount)
	else:
		if not PersonInventory.spend_goods(PersonInventory.PLAYER, sack_item(resident)):
			return false
		var sack: Dictionary = errand.get("sack", {})
		for item: String in sack:
			PersonInventory.carry(resident, item, float(sack[item]))
		completeness = _completeness(errand)
	errand.done = true
	errand.day = _day()
	economy.tip("errand:%s:%d" % [resident, _day()], resident, completeness, _clock.elapsed_minutes())
	RealityState.commit()
	return true
