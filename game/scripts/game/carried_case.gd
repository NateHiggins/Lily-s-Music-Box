class_name CarriedCase
extends RefCounted
## Where each stack of goods lies in the player's case: a grid of stitched squares.
## PersonInventory stays the owner of what is carried and how many; this owns only
## the arrangement. Keys, parts and the grocery bag are never limited by it, so a
## full case can't block a job or the mystery. It holds bought goods only.

const KEY := "carried_case"
const DATA_PATH := "res://data/carried_case.json"

static var _data: Dictionary = {}


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
	var size: Array = data().get("forms", {}).get(form, {}).get("size", [1, 1])
	return Vector2i(int(size[1]), int(size[0])) if turned else Vector2i(int(size[0]), int(size[1]))


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"version": 1, "places": {}}
	return RealityState.data[KEY]


static func _rect(place: Dictionary) -> Rect2i:
	return Rect2i(int(place.x), int(place.y), 0, 0).grow_individual(0, 0,
			form_size(str(place.form), bool(place.turned)).x, form_size(str(place.form), bool(place.turned)).y)


static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] \
			or float(value.version) != 1.0 or value.get("places") is not Dictionary:
		return false
	var bounds := Rect2i(Vector2i.ZERO, grid())
	var taken: Array[Rect2i] = []
	for item: Variant in value.places:
		var place: Variant = value.places[item]
		if item is not String or place is not Dictionary or not has_form(str(place.get("form", ""))) \
				or typeof(place.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(place.get("y")) not in [TYPE_INT, TYPE_FLOAT] \
				or place.get("turned") is not bool:
			return false
		var rect := _rect(place)
		if not bounds.encloses(rect) or taken.any(func(other: Rect2i): return other.intersects(rect)):
			return false
		taken.append(rect)
	return true


static func place_of(item: String) -> Dictionary:
	return book().places.get(item, {})


static func fits(item: String, form: String, x: int, y: int, turned: bool) -> bool:
	var rect := Rect2i(Vector2i(x, y), form_size(form, turned))
	if not Rect2i(Vector2i.ZERO, grid()).encloses(rect):
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
	place.x = x
	place.y = y
	place.turned = turned
	RealityState.commit()
	return true


static func remove(item: String) -> void:
	book().places.erase(item)
