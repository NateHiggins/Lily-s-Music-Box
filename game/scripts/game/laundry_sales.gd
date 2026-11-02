class_name LaundrySales
extends ShopSales
## The Model Laundry counter. A wash is work, not goods: paying puts your bundle on the counter,
## where the hand pushes it across, and it comes back the next day. A washed uniform stays
## presentable for a week. A dirty one costs a little at first contact and never closes a door.

const KEY := "laundry_book"
const UNIFORM := "uniform_washed_and_pressed"
const PRESENTABLE_DAYS := 7
const UNSET := -1


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"washed": UNSET, "paid": false, "away": false, "ready": 0}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 4:
		return false
	for key: String in ["washed", "ready"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return value.get("paid") is bool and value.get("away") is bool


## A count of days on the campaign calendar, or UNSET with no clock running.
static func day() -> int:
	var clock := CampaignClock.new()
	if not clock.bind_state():
		return UNSET
	var local := clock.local_datetime()
	if local.is_empty():
		return UNSET
	var stamp := "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]
	return int(Time.get_unix_time_from_datetime_string(stamp) / 86400)


## The uniform comes clean with the job, so the week starts the first time anyone looks.
static func presentable() -> bool:
	var today := day()
	if today == UNSET:
		return true
	var left := book()
	if bool(left.paid) or bool(left.away):
		return false
	if int(left.washed) == UNSET:
		left.washed = today
	return today - int(left.washed) < PRESENTABLE_DAYS


static func collectable() -> bool:
	var left := book()
	return bool(left.away) and day() >= int(left.ready)


func transaction_status(item_id: String) -> String:
	if item_id != UNIFORM:
		return super(item_id)
	if bool(book().paid) or bool(book().away):
		return "out_of_stock"
	var record := catalogue.item(shop_id, item_id)
	if record.is_empty():
		return "invalid_quote"
	return clearing.settlement_status(shop_id, int(record.cents))


func transact(item_id: String, shop: String) -> bool:
	if item_id != UNIFORM:
		return super(item_id, shop)
	if shop != shop_id or transaction_status(item_id) != "available":
		return false
	var record := catalogue.item(shop_id, item_id)
	return clearing.settle_repeat(shop_id, item_id, int(record.cents), func():
		book().paid = true
		return true)


## Only the uniform for now: the other services have nothing of yours to work on yet.
func listing() -> Array[String]:
	var out: Array[String] = [UNIFORM]
	return out
