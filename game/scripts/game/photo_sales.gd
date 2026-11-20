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
	if value is not Dictionary or value.get("waiting") is not bool:
		return false
	for field: String in ["exposed", "prints"]:
		if value.has(field) and value.get(field) is not Array:
			return false
	return true


# --- Her own pictures (Lily's ruling wall_photos_how_20261120: "hold the camera up anywhere, frame, press; that
# view is what the print shows"). A blank plate takes one exposure. The exposure rides with the plate until the
# plate is printed, here or in the tray; the print then carries that picture. Pictures are numbered from one, in
# the order they were taken, and their files are user://plates/plate_<number>.webp.

const PICTURES := "user://plates"


static func picture_path(number: int) -> String:
	return "%s/plate_%04d.webp" % [PICTURES, number]


## Exposed plates not yet printed, oldest first: [{"n", "room", "taken"}].
static func exposed() -> Array:
	var value: Variant = book().get("exposed", [])
	return value if value is Array else []


## Prints that carry a picture, oldest first, as picture numbers.
static func pictured_prints() -> Array:
	var value: Variant = book().get("prints", [])
	return value if value is Array else []


## Blank plates in the case: every plate that does not already hold an exposure.
static func blank_plates() -> int:
	return maxi(0, PersonInventory.goods_count(PersonInventory.PLAYER, PLATE) - exposed().size())


## The number the next picture will have.
static func next_picture() -> int:
	return int(book().get("taken", 0)) + 1


## One blank plate takes the picture just written to picture_path(next_picture()). `room` and `taken` are where and
## (in campaign time) when. Returns the picture's number, or 0 when there is no blank plate. Uncommitted: the camera
## commits once the file is on disk.
static func expose(room: String, taken: String) -> int:
	if blank_plates() <= 0:
		return 0
	var number := next_picture()
	var waiting: Array = exposed().duplicate()
	waiting.append({"n": number, "room": room, "taken": taken})
	book()["exposed"] = waiting
	book()["taken"] = number
	return number


## A plate is being printed: the oldest exposure goes with it. Returns its picture number, or 0 for a blank plate.
static func _plate_goes_to_print() -> int:
	var waiting: Array = exposed().duplicate()
	if waiting.is_empty():
		return 0
	var first: Dictionary = waiting.pop_front()
	book()["exposed"] = waiting
	return int(first.get("n", 0))


## The print in the tray came out (or was lost): its picture, if it had one, is kept with the print or dropped.
static func tray_print_done(kept: bool) -> void:
	var number := int(book().get("tray", 0))
	book().erase("tray")
	if kept and number > 0:
		var made: Array = pictured_prints().duplicate()
		made.append(number)
		book()["prints"] = made


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
			if not PersonInventory.spend_goods(PersonInventory.PLAYER, PLATE) \
					or not PersonInventory.carry_goods(PersonInventory.PLAYER, "own_print", "Print, %s hand" % hand, "card"):
				return false
			var number := _plate_goes_to_print()
			if number > 0:
				var made: Array = pictured_prints().duplicate()
				made.append(number)
				book()["prints"] = made
			return true
		HOUR:
			for item: String in [PLATE, PAPER, CHEMICALS]:
				if not PersonInventory.spend_goods(PersonInventory.PLAYER, item):
					return false
			book().waiting = true
			var number := _plate_goes_to_print()
			if number > 0:
				book()["tray"] = number
			return true
		SITTING:
			return PersonInventory.carry_goods(PersonInventory.PLAYER, "own_portrait", "Portrait of the night man", "card")
	return super(record)
