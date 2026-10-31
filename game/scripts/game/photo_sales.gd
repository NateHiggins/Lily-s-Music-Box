class_name PhotoSales
extends ShopSales
## The Photo Supplies counter. Goods sell as anywhere. The counter's services take a plate:
## printed here it comes back at once, in whoever's hand keeps the shop; an hour in the darkroom
## takes a plate, a sheet and the chemicals and leaves a print waiting in the tray. Sittings
## stop with the photographer. Technique never touches the case: this is only your own pictures.

const KEY := "photo_bench"
const DEATH := "1929-07-19"
const PLATE := "single_dry_plate"
const PAPER := "printing_paper_sheet"
const CHEMICALS := "developer_and_fixer"
const PRINTED := "plate_developed_and_printed_here"
const HOUR := "darkroom_hour"
const SITTING := "portrait_sitting"

var _clock := CampaignClock.new()


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"waiting": false}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	return value is Dictionary and value.get("waiting") is bool


func _today() -> String:
	if not _clock.bind_state():
		return ""
	var local := _clock.local_datetime()
	return "" if local.is_empty() else "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]


func listing() -> Array[String]:
	var out := super()
	out.append(PRINTED)
	out.append(HOUR)
	if _today() <= DEATH:
		out.append(SITTING)
	return out


func _has(item: String) -> bool:
	return PersonInventory.goods_count(PersonInventory.PLAYER, item) > 0


func transaction_status(item_id: String) -> String:
	var record := catalogue.item(shop_id, item_id)
	if item_id == PRINTED or item_id == HOUR or item_id == SITTING:
		if item_id == SITTING and _today() > DEATH:
			return "invalid_quote"
		if item_id != SITTING and not _has(PLATE):
			return "no_plate"
		if item_id == HOUR:
			if bool(book().waiting):
				return "tray_busy"
			if not _has(PAPER) or not _has(CHEMICALS):
				return "no_paper"
		elif not PersonInventory.can_carry_goods(PersonInventory.PLAYER, "own_print", "card"):
			return "case_full"
		return clearing.settlement_status(shop_id, int(record.cents))
	return super(item_id)


func _deliver(record: Dictionary) -> bool:
	match str(record.id):
		PRINTED:
			var hand := "Miss Voss's" if _today() <= DEATH else "Miss Quell's"
			return PersonInventory.spend_goods(PersonInventory.PLAYER, PLATE) \
					and PersonInventory.carry_goods(PersonInventory.PLAYER, "own_print", "Print, %s hand" % hand, "card")
		HOUR:
			for item: String in [PLATE, PAPER, CHEMICALS]:
				if not PersonInventory.spend_goods(PersonInventory.PLAYER, item):
					return false
			book().waiting = true
			return true
		SITTING:
			return PersonInventory.carry_goods(PersonInventory.PLAYER, "own_portrait", "Portrait of the night man", "card")
	return super(record)
