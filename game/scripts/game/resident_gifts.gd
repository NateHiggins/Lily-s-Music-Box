class_name ResidentGifts
extends RefCounted
## Carried goods the catalogue marks as gifts can be given at a door, one a day to
## each resident. A gift moves goodwill through CaretakerEconomy, under its daily cap,
## and never reaches a case, a clue or a mystery flag.

const KEY := "resident_gifts"
const OFFER_LIMIT := 2
const DAY := 1440.0

var catalogue: ShopCatalogue
var economy: Node
var _clock := CampaignClock.new()


func setup(shops: ShopCatalogue, ledger: Node) -> void:
	catalogue = shops
	economy = ledger


static func valid(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	for resident: Variant in value:
		if resident is not String or typeof(value[resident]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true


func _book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {}
	return RealityState.data[KEY]


func _day() -> int:
	_clock.bind_state()
	return int(_clock.elapsed_minutes() / DAY)


func _is_gift(item: String) -> bool:
	for shop_id: String in catalogue.shop_ids():
		var record := catalogue.item(shop_id, item)
		if not record.is_empty():
			return bool(record.get("gift", false))
	return false


## Up to two gifts on offer: [{id, name}], in a stable order.
func offers(resident: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if int(_book().get(resident, -1)) == _day():
		return out
	var held := PersonInventory.items(PersonInventory.PLAYER)
	var ids := held.keys()
	ids.sort()
	for id: String in ids:
		var record: Dictionary = held[id]
		if str(record.kind) == "goods" and _is_gift(str(record.item)):
			out.append({"id": str(record.item), "name": str(record.name)})
			if out.size() >= OFFER_LIMIT:
				break
	return out


func give(resident: String, item: String) -> bool:
	if int(_book().get(resident, -1)) == _day() or not _is_gift(item) \
			or not PersonInventory.spend_goods(PersonInventory.PLAYER, item):
		return false
	_book()[resident] = _day()
	economy.appreciate(resident)
	RealityState.commit()
	return true
