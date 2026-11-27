class_name CarriedCase
extends RefCounted
## Where each stack of goods lies in the player's case: a grid of stitched squares.
## PersonInventory stays the owner of what is carried and how many; this owns only
## the arrangement. Paid maintenance stock can have a place without a second
## inventory row. Keys, loose parts and the grocery bag keep their own owners.

const KEY := "carried_case"
const DATA_PATH := "res://data/carried_case.json"
const MAINTENANCE_WASHER := "fire_hose_spare_gasket"
const WASHER_FORM := "maintenance_washer"
const VENT_INSERT_PREFIX := "radiator_insert:"
const VENT_INSERT_FORM := "radiator_vent_insert"
const VENT_INSERT_SOURCE := "res://data/orison_v2/heating_service_stock.json"
const BOOK_PREFIX := "library_book:"
const LIBRARY_PATH := "res://data/orison_v2/readable_library.json"
const LIBRARY_COPIES_PATH := "res://data/orison_v2/nook_readable_books.json"
## Covers extend beyond their authored block, with clearance at both edges.
const BOOK_FOOTPRINT_ALLOWANCE := 0.004
## Kitchen prep stock taken into the inventory (Lily 2026-11-24; ruling held_put_down_20261124:
## it stays in the case until used somewhere). Item "kitchen_tool:<station>/<assembly>".
const KITCHEN_TOOL_PREFIX := "kitchen_tool:"
const KITCHEN_TOOL_FORMS := {"Breadboard": "flat", "SinkBridge": "flat", "RollingPin": "tool", "MixingBowl": "parcel"}
## What the hand holds: one packed item or nothing. Optional, so older saves read as empty.
const HAND := "hand"
const FOUND_TRACE_PREFIX := "found_trace:"
const FOUND_TRACE_FORM := "found_phonautogram"
const RECORDED_TRACE_PREFIX := "recorded_trace:"
const RECORDED_ORIGINALS := "recorded_originals"
const TraceForge := preload("res://scripts/songbook/phonautogram_forge.gd")

static var _data: Dictionary = {}
static var _book_sizes: Dictionary = {}
static var _vent_stock_id := ""


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary and _valid_data(parsed) else {}
	return _data


## The view draws from these fields; a broken file means no case, not a broken one.
static func _valid_data(value: Dictionary) -> bool:
	if int(value.get("schema_version", 0)) != 1 or str(value.get("asset", "")) == "" \
			or float(value.get("cell", 0.0)) <= 0.0 or value.get("hinge") is not Array \
			or value.get("parts") is not Array or value.get("forms") is not Dictionary:
		return false
	for part: Variant in value.parts:
		if part is not Dictionary or str(part.get("name", "")) == "" or str(part.get("assembly", "")) == "" \
				or str(part.get("key", "")) == "" or float(part.get("tile", 0.0)) <= 0.0:
			return false
	return true


static func grid() -> Vector2i:
	var cells: Array = data().get("grid", [0, 0])
	return Vector2i(int(cells[0]), int(cells[1]))


static func has_form(form: String) -> bool:
	return data().get("forms", {}).has(form)


static func form_size(form: String, turned := false) -> Vector2i:
	if form.begins_with(BOOK_PREFIX):
		var footprint := _book_size(form.trim_prefix(BOOK_PREFIX))
		return Vector2i(footprint.y, footprint.x) if turned else footprint
	var size: Array = data().get("forms", {}).get(form, {}).get("size", [1, 1])
	return Vector2i(int(size[1]), int(size[0])) if turned else Vector2i(int(size[0]), int(size[1]))


static func _book_size(copy: String) -> Vector2i:
	if _book_sizes.is_empty():
		var sizes := {}
		var cell := float(data().get("cell", 0.0))
		if cell <= 0.0:
			return Vector2i.ZERO
		for path: String in [LIBRARY_PATH, LIBRARY_COPIES_PATH]:
			var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if source is not Dictionary or source.get("books") is not Dictionary:
				return Vector2i.ZERO
			for identity: String in source.books:
				var construction: Dictionary = source.books[identity]
				sizes[identity] = Vector2i(
					ceili((float(construction.width) + BOOK_FOOTPRINT_ALLOWANCE) / cell),
					ceili((float(construction.height) + BOOK_FOOTPRINT_ALLOWANCE) / cell))
		_book_sizes = sizes
	return _book_sizes.get(copy, Vector2i.ZERO)


static func library_item(collection: String, copy: String) -> String:
	return BOOK_PREFIX + collection + ":" + copy


static func library_fit(collection: String, copy: String) -> Dictionary:
	var item := library_item(collection, copy)
	if collection.is_empty() or copy.is_empty() or book().places.has(item):
		return {}
	var place := first_fit(item, BOOK_PREFIX + copy)
	if not place.is_empty():
		place.collection = collection
	return place


static func kitchen_tool_item(station: String, assembly: String) -> String:
	return KITCHEN_TOOL_PREFIX + station + "/" + assembly


## [station, assembly] of a kitchen tool item, or [] if it is not one.
static func kitchen_tool_parts(item: String) -> Array:
	if not item.begins_with(KITCHEN_TOOL_PREFIX):
		return []
	var parts := item.trim_prefix(KITCHEN_TOOL_PREFIX).split("/")
	if parts.size() != 2 or parts[0].is_empty() or not KITCHEN_TOOL_FORMS.has(parts[1]):
		return []
	return [parts[0], parts[1]]


static func kitchen_tool_form(item: String) -> String:
	var parts := kitchen_tool_parts(item)
	return "" if parts.is_empty() else str(KITCHEN_TOOL_FORMS[parts[1]])


static func hand(document: Dictionary = RealityState.data) -> String:
	var case_book: Variant = document.get(KEY)
	return str(case_book.get(HAND, "")) if case_book is Dictionary else ""


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"version": 1, "places": {}}
	return RealityState.data[KEY]


static func _rect(place: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(place.x), int(place.y)), form_size(str(place.form), bool(place.turned)))


## Both generations of SongbookStore use <song>_YYYYMMDD_HHMMSS_NNN.
## Bind a local identity without ever touching the player's recording directory.
static func recorded_song_id(version_id: String) -> String:
	var fields := version_id.rsplit("_", true, 3)
	if fields.size() != 4 or fields[0].is_empty() or not version_id.is_valid_filename():
		return ""
	if fields[1].length() != 8 or fields[2].length() != 6 or fields[3].length() != 3:
		return ""
	for i in range(1, 4):
		for digit: String in fields[i]:
			if digit < "0" or digit > "9":
				return ""
	return fields[0]


## Every admitted edition is either in its fitted case square or on the tray.
## The ordered tray (bottom to top) is the sole source of stacking order.
static func _valid_recorded_locations(case_book: Dictionary) -> bool:
	if not case_book.has(RECORDED_ORIGINALS):
		return true
	var originals: Variant = case_book[RECORDED_ORIGINALS]
	if originals is not Dictionary or originals.get("editions") is not Dictionary or originals.get("tray") is not Array:
		return false
	var in_tray := {}
	for id: Variant in originals.tray:
		if id is not String or not originals.editions.has(id) or in_tray.has(id):
			return false
		in_tray[id] = true
	for id: Variant in originals.editions:
		var song: Variant = originals.editions[id]
		if id is not String or song is not String or song.is_empty() or recorded_song_id(id) != song:
			return false
		if in_tray.has(id) == case_book.places.has(RECORDED_TRACE_PREFIX + id):
			return false
	return true


static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] \
			or float(value.version) != 1.0 or value.get("places") is not Dictionary or not _valid_recorded_locations(value):
		return false
	var bounds := Rect2i(Vector2i.ZERO, grid())
	var taken: Array[Rect2i] = []
	for item: Variant in value.places:
		var place: Variant = value.places[item]
		if item is not String or place is not Dictionary or place.get("form") is not String \
				or typeof(place.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(place.get("y")) not in [TYPE_INT, TYPE_FLOAT] \
				or place.get("turned") is not bool:
			return false
		if item.begins_with(FOUND_TRACE_PREFIX) or item.begins_with(RECORDED_TRACE_PREFIX):
			if item.begins_with(FOUND_TRACE_PREFIX):
				if not TraceForge.FOUND.has(item.trim_prefix(FOUND_TRACE_PREFIX)):
					return false
			elif not value.has(RECORDED_ORIGINALS) or not value[RECORDED_ORIGINALS].editions.has(item.trim_prefix(RECORDED_TRACE_PREFIX)):
				return false
			if place.form != FOUND_TRACE_FORM or not has_form(FOUND_TRACE_FORM) \
					or not is_finite(float(place.x)) or not is_finite(float(place.y)) \
					or float(place.x) != floorf(float(place.x)) or float(place.y) != floorf(float(place.y)):
				return false
		elif item.begins_with(BOOK_PREFIX):
			var copy: String = place.form.trim_prefix(BOOK_PREFIX)
			if not place.form.begins_with(BOOK_PREFIX) or place.get("collection") is not String \
					or place.collection.is_empty() or item != library_item(place.collection, copy) \
					or not is_finite(float(place.x)) or not is_finite(float(place.y)) \
					or float(place.x) != floorf(float(place.x)) or float(place.y) != floorf(float(place.y)) \
					or _book_size(copy) == Vector2i.ZERO:
				return false
		elif not has_form(place.form) or place.form == FOUND_TRACE_FORM or (item == MAINTENANCE_WASHER) != (place.form == WASHER_FORM) \
				or item.begins_with(VENT_INSERT_PREFIX) != (place.form == VENT_INSERT_FORM) \
				or (item.begins_with(KITCHEN_TOOL_PREFIX) and place.form != kitchen_tool_form(item)):
			return false
		var rect := _rect(place)
		if not bounds.encloses(rect) or taken.any(func(other: Rect2i): return other.intersects(rect)):
			return false
		taken.append(rect)
	if value.has(HAND):
		var held: Variant = value[HAND]
		if held is not String or (not held.is_empty() and not value.places.has(held)):
			return false
	return true


static func washer_is_packed(document: Dictionary) -> bool:
	var case_book: Variant = document.get(KEY)
	return case_book is Dictionary and case_book.get("places") is Dictionary \
			and case_book.places.has(MAINTENANCE_WASHER)


## A packed spare still reserves its rack pocket. The case owns only its location in transit.
static func valid_packed_inserts(case_book: Dictionary, records: Variant) -> bool:
	for item: String in case_book.get("places", {}):
		if not item.begins_with(VENT_INSERT_PREFIX):
			continue
		var stock: Variant = records.get(vent_insert_stock_id()) if records is Dictionary else null
		if stock is not Dictionary or stock.get("kind") != "mechanism" or stock.get("value") is not Dictionary:
			return false
		var parts: Variant = stock.value.get("parts")
		if parts is not Array:
			return false
		var identity := item.trim_prefix(VENT_INSERT_PREFIX)
		if not parts.any(func(part): return part is Dictionary and part.get("id") == identity \
				and not part.has("slot") and _valid_vent_index(part.get("rack")) and _valid_vent_index(part.get("grade")) \
				and identity == "VENT_SPARE_%d" % int(part.grade)):
			return false
	return true


static func _valid_vent_index(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and value >= 0 and value < 5 \
		and value == floorf(float(value))


static func vent_insert_stock_id() -> String:
	if _vent_stock_id.is_empty():
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(VENT_INSERT_SOURCE))
		if source is Dictionary:
			_vent_stock_id = str(source.get("id", ""))
	return _vent_stock_id


static func place_of(item: String) -> Dictionary:
	return book().places.get(item, {})


static func fits(item: String, form: String, x: int, y: int, turned: bool, places: Variant = null) -> bool:
	var rect := Rect2i(Vector2i(x, y), form_size(form, turned))
	if not rect.has_area() or not Rect2i(Vector2i.ZERO, grid()).encloses(rect):
		return false
	if places == null:
		places = book().places
	for other: String in places:
		if other != item and _rect(places[other]).intersects(rect):
			return false
	return true


## Front-left first, so new goods land where a hand would drop them.
static func first_fit(item: String, form: String, places: Variant = null) -> Dictionary:
	var cells := grid()
	if places == null:
		places = book().places
	for turned: bool in [false, true]:
		for y in range(cells.y - 1, -1, -1):
			for x in cells.x:
				if fits(item, form, x, y, turned, places):
					return {"x": x, "y": y, "turned": turned, "form": form}
	return {}


static func has_room(item: String, form: String) -> bool:
	return book().places.has(item) or not first_fit(item, form).is_empty()


## Uncommitted: a sale's settlement saves the place with the debit and the goods.
static func place_new(item: String, form: String) -> bool:
	if book().places.has(item):
		return true
	var place := first_fit(item, form)
	if place.is_empty():
		return false
	book().places[item] = place
	return true


static func move(item: String, x: int, y: int, turned: bool) -> bool:
	var place := place_of(item)
	if place.is_empty() or not fits(item, str(place.form), x, y, turned):
		return false
	if item.begins_with(BOOK_PREFIX) or item.begins_with(VENT_INSERT_PREFIX) or item.begins_with(KITCHEN_TOOL_PREFIX) \
			or item.begins_with(FOUND_TRACE_PREFIX) or item.begins_with(RECORDED_TRACE_PREFIX):
		var prepare := func(document: Dictionary) -> bool:
			if place_of(item) != place or not fits(item, str(place.form), x, y, turned):
				return false
			var staged: Dictionary = document[KEY].places[item]
			staged.merge({"x": x, "y": y, "turned": turned}, true)
			return true
		return RealityState.commit_case_and_household(prepare)
	place.x = x
	place.y = y
	place.turned = turned
	RealityState.commit()
	return true


static func remove(item: String) -> void:
	book().places.erase(item)
