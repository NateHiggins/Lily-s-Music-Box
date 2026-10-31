class_name ResidentErrands
extends RefCounted
## A resident short of groceries can give the player a list at the door, and the
## player can carry it back. The groceries go into the resident's own bag, and the
## resident puts them away and cooks them through the existing KitchenLarder. One
## errand per resident per day; the tip and goodwill stay inside CaretakerEconomy's
## caps. Errands never touch a case or a mystery flag.

const KEY := "resident_errands"
const LIST_LIMIT := 4
const DAY := 1440.0

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
	return true


func _book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {}
	return RealityState.data[KEY]


func _day() -> int:
	_clock.bind_state()
	return int(_clock.elapsed_minutes() / DAY)


func ready() -> bool:
	return larder != null and economy != null


## A list is on offer: nothing open or done today, and the resident is short.
func can_ask(resident: String) -> bool:
	if not ready() or larder.unit_of(resident) == "":
		return false
	var errand: Dictionary = _book().get(resident, {})
	if not errand.is_empty() and (not bool(errand.done) or int(errand.day) == _day()):
		return false
	return not larder.missing(resident).is_empty()


func _list(resident: String) -> Dictionary:
	var items := {}
	var short: Dictionary = larder.missing(resident)
	var ids := short.keys()
	ids.sort()
	for item: String in ids:
		if items.size() >= LIST_LIMIT:
			break
		items[item] = float(short[item])
	return items


## What the door says, without taking anything down yet.
func list_words(resident: String) -> String:
	var names: PackedStringArray = []
	for item: String in _list(resident):
		names.append(str(larder.groceries.ingredients[item].name))
	return ", ".join(names)


## The list is taken down. Its words are the ones the door just said.
func ask(resident: String) -> void:
	_book()[resident] = {"items": _list(resident), "day": _day(), "done": false}
	RealityState.commit()


func can_deliver(resident: String) -> bool:
	var errand: Dictionary = _book().get(resident, {})
	if errand.is_empty() or bool(errand.done):
		return false
	for item: String in errand.items:
		if PersonInventory.carried(PersonInventory.PLAYER, item) + 0.0001 < float(errand.items[item]):
			return false
	return true


func has_open(resident: String) -> bool:
	var errand: Dictionary = _book().get(resident, {})
	return not errand.is_empty() and not bool(errand.done)


## The whole list passes from the player's bag to the resident's, or nothing does.
func deliver(resident: String) -> bool:
	if not can_deliver(resident):
		return false
	var errand: Dictionary = _book()[resident]
	for item: String in errand.items:
		var amount := float(errand.items[item])
		PersonInventory.lose(PersonInventory.PLAYER, item, amount)
		PersonInventory.carry(resident, item, amount)
	errand.done = true
	errand.day = _day()
	economy.tip("errand:%s:%d" % [resident, _day()], resident, 1.0, _clock.elapsed_minutes())
	RealityState.commit()
	return true
