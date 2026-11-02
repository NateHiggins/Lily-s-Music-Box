class_name ParcelErrands
extends RefCounted
## The wall of parcels at the Model Laundry. A resident gives the player a ticket number at the
## door, the player finds the tag on the wall by eye and pulls that parcel off by hand, and carries
## it back. One parcel out at a time. The wall changes by itself every fortnight, a claimed parcel's
## place stays empty for a fortnight, and the top row is the old unclaimed work and never moves.
## Errands never touch a case or a mystery flag.

const KEY := "parcel_errands"
const ITEM := "laundry_parcel"
const COLUMNS := 8
const ROWS := 5
const FIRST_TICKET_ROW := 1
const UNCLAIMED_ROW := 4
const WAIT_DAYS := 7
const GONE_DAYS := 14
const STALE_DAYS := 14


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"open": {}, "last": {}, "gone": {}}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 3:
		return false
	var open: Variant = value.get("open")
	if open is not Dictionary or value.get("last") is not Dictionary or value.get("gone") is not Dictionary:
		return false
	if open.is_empty():
		return true
	return open.get("resident") is String and open.get("parcel") is String and open.get("taken") is bool \
			and typeof(open.get("day")) in [TYPE_INT, TYPE_FLOAT]


static func parcel_id(row: int, column: int) -> String:
	return "%d_%d" % [row, column]


## Three figures, one to a parcel, in no order you could walk along the wall.
static func ticket(parcel: String) -> int:
	var at := parcel.split("_")
	return 212 + ((int(at[0]) * COLUMNS + int(at[1])) * 17) % (ROWS * COLUMNS) * 7


static func on_wall(parcel: String, today: int) -> bool:
	var open: Dictionary = book().open
	if str(open.get("parcel", "")) == parcel:
		return not bool(open.taken)
	if parcel.begins_with("%d_" % UNCLAIMED_ROW):
		return true
	if today < int(book().gone.get(parcel, today)):
		return false
	return ("%s:%d" % [parcel, maxi(today, 0) / GONE_DAYS]).hash() % 5 != 0


## A parcel on offer: nothing else out, this resident's week comes round, and a clock is running.
static func can_ask(resident: String) -> bool:
	var today := LaundrySales.day()
	if today == LaundrySales.UNSET or has_open(resident) or not _free(today):
		return false
	var last: Variant = book().last.get(resident)
	if last != null and today - int(last) < WAIT_DAYS:
		return false
	return ("%s:%d" % [resident, today / WAIT_DAYS]).hash() % 3 == 0


## An old ticket nobody fetched stops holding up the house. One already in the case stays yours.
static func _free(today: int) -> bool:
	var open: Dictionary = book().open
	return open.is_empty() or (not bool(open.taken) and today - int(open.day) >= STALE_DAYS)


## The parcel this resident would send you for today, without taking anything down yet.
static func chosen(resident: String) -> String:
	var today := LaundrySales.day()
	var there: PackedStringArray = []
	for row in range(FIRST_TICKET_ROW, UNCLAIMED_ROW):
		for column in COLUMNS:
			if on_wall(parcel_id(row, column), today):
				there.append(parcel_id(row, column))
	if there.is_empty():
		return ""
	return there[("%s:%d" % [resident, today]).hash() % there.size()]


## The ticket is taken down. Its number is the one the door just said.
static func ask(resident: String) -> void:
	book().open = {"resident": resident, "parcel": chosen(resident), "day": LaundrySales.day(), "taken": false}
	RealityState.commit()


static func has_open(resident: String) -> bool:
	return str(book().open.get("resident", "")) == resident


static func open_ticket() -> int:
	return ticket(str(book().open.parcel))


static func can_deliver(resident: String) -> bool:
	return has_open(resident) and bool(book().open.taken) \
			and PersonInventory.goods_count(PersonInventory.PLAYER, ITEM) > 0


## Only the ticketed parcel comes off the wall, and only if the case has room for it.
static func take(parcel: String) -> bool:
	var open: Dictionary = book().open
	if str(open.get("parcel", "")) != parcel or bool(open.taken):
		return false
	if not PersonInventory.carry_goods(PersonInventory.PLAYER, ITEM, "Parcel, ticket %d" % ticket(parcel), "parcel"):
		return false
	open.taken = true
	RealityState.commit()
	return true


static func deliver(resident: String, economy: Node, minutes: float) -> bool:
	if not can_deliver(resident) or not PersonInventory.spend_goods(PersonInventory.PLAYER, ITEM):
		return false
	var left := book()
	var today := LaundrySales.day()
	left.gone[str(left.open.parcel)] = today + GONE_DAYS
	left.last[resident] = today
	left.open = {}
	economy.tip("parcel:%s:%d" % [resident, today], resident, 1.0, minutes)
	RealityState.commit()
	return true
