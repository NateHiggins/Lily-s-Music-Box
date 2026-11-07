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
const BOOK_PREFIX := "library_book:"
const LIBRARY_PATH := "res://data/orison_v2/readable_library.json"
const LIBRARY_COPIES_PATH := "res://data/orison_v2/nook_readable_books.json"
## Covers extend beyond their authored block, with clearance at both edges.
const BOOK_FOOTPRINT_ALLOWANCE := 0.004

static var _data: Dictionary = {}
static var _book_sizes: Dictionary = {}


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


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"version": 1, "places": {}}
	return RealityState.data[KEY]


static func _rect(place: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(place.x), int(place.y)), form_size(str(place.form), bool(place.turned)))


static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] \
			or float(value.version) != 1.0 or value.get("places") is not Dictionary:
		return false
	var bounds := Rect2i(Vector2i.ZERO, grid())
	var taken: Array[Rect2i] = []
	for item: Variant in value.places:
		var place: Variant = value.places[item]
		if item is not String or place is not Dictionary or place.get("form") is not String \
				or typeof(place.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(place.get("y")) not in [TYPE_INT, TYPE_FLOAT] \
				or place.get("turned") is not bool:
			return false
		if item.begins_with(BOOK_PREFIX):
			var copy: String = place.form.trim_prefix(BOOK_PREFIX)
			if not place.form.begins_with(BOOK_PREFIX) or place.get("collection") is not String \
					or place.collection.is_empty() or item != library_item(place.collection, copy) \
					or not is_finite(float(place.x)) or not is_finite(float(place.y)) \
					or float(place.x) != floorf(float(place.x)) or float(place.y) != floorf(float(place.y)) \
					or _book_size(copy) == Vector2i.ZERO:
				return false
		elif not has_form(place.form) or (item == MAINTENANCE_WASHER) != (place.form == WASHER_FORM):
			return false
		var rect := _rect(place)
		if not bounds.encloses(rect) or taken.any(func(other: Rect2i): return other.intersects(rect)):
			return false
		taken.append(rect)
	return true


static func washer_is_packed(document: Dictionary) -> bool:
	var case_book: Variant = document.get(KEY)
	return case_book is Dictionary and case_book.get("places") is Dictionary \
			and case_book.places.has(MAINTENANCE_WASHER)


static func place_of(item: String) -> Dictionary:
	return book().places.get(item, {})


static func fits(item: String, form: String, x: int, y: int, turned: bool) -> bool:
	var rect := Rect2i(Vector2i(x, y), form_size(form, turned))
	if not rect.has_area() or not Rect2i(Vector2i.ZERO, grid()).encloses(rect):
		return false
	var places: Dictionary = book().places
	for other: String in places:
		if other != item and _rect(places[other]).intersects(rect):
			return false
	return true


## Front-left first, so new goods land where a hand would drop them.
static func first_fit(item: String, form: String) -> Dictionary:
	var cells := grid()
	for turned: bool in [false, true]:
		for y in range(cells.y - 1, -1, -1):
			for x in cells.x:
				if fits(item, form, x, y, turned):
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
	if item.begins_with(BOOK_PREFIX):
		var prepare := func(document: Dictionary) -> bool:
			if place_of(item) != place or not fits(item, str(place.form), x, y, turned):
				return false
			var staged: Dictionary = document[KEY].places[item]
			staged.merge({"x": x, "y": y, "turned": turned}, true)
			return true
		return RealityState.commit_library_case_change(prepare)
	place.x = x
	place.y = y
	place.turned = turned
	RealityState.commit()
	return true


static func remove(item: String) -> void:
	book().places.erase(item)
