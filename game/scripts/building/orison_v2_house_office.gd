extends RefCounted
## The house office in common room B (Lily, v1r_first_floor_layout_20261111:
## "telephone board into common room B as a house office with dead letters
## and the headquarters"). One call stands the dead-letters sorting desk and
## the maintenance headquarters against the room's walls, from the placement
## table, in the blockout's own frame.
const LAYOUT := "res://data/orison_v2/house_office_layout.json"
const Stock := preload("res://scripts/building/orison_v2_house_office_stock.gd")
const Desk := preload("res://scripts/building/orison_v2_dead_letters_desk.gd")
const Headquarters := preload("res://scripts/building/orison_v2_maintenance_headquarters.gd")


## Returns {"dead_letters": node, "headquarters": node, "errors": [...]}.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, _adapter: Variant) -> Dictionary:
	if root.has_meta("v2_house_office"):
		var mounted: Dictionary = root.get_meta("v2_house_office")
		return mounted
	var result := {"dead_letters": null, "headquarters": null, "errors": []}
	var errors: Array = result.errors
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if table is not Dictionary or table.get("schema_version") != 1 or table.get("placements") is not Array:
		errors.append("house office placement table malformed")
		return result
	var stock := Stock.new()
	if not stock.prepare():
		errors.append_array(stock.errors)
		return result
	var levels: Dictionary = {}
	for row: Dictionary in layout.get("levels", []):
		levels[str(row.id)] = float(row.y)
	var rooms: Dictionary = {}
	for row: Dictionary in layout.get("spaces", []):
		rooms[str(row.id)] = row.rect
	var places: Dictionary = {}
	var solids: Dictionary = {}
	for row: Dictionary in table.placements:
		var at: Array = row.position
		var rect: Array = rooms.get(str(row.space), [])
		if rect.size() != 4 or not levels.has(str(row.level)) or float(at[0]) < float(rect[0]) or float(at[0]) > float(rect[2]) \
				or float(at[2]) < float(rect[1]) or float(at[2]) > float(rect[3]):
			errors.append("house office placement outside its room: " + str(row.id))
			continue
		places[str(row.id)] = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.yaw_degrees))),
				Vector3(float(at[0]), float(at[1]) + float(levels[str(row.level)]), float(at[2])))
		solids[str(row.id)] = row.solids
	if not places.has("sorting_desk") or not places.has("bench") or not places.has("plaque") or not places.has("trophy_wall"):
		errors.append("house office placement table incomplete")
		return result
	var desk := Desk.new()
	desk.name = "DeadLettersDesk"
	desk.prop_type = "dead_letters"
	desk.stock = stock
	desk.transform = places.sorting_desk
	blockout.add_child(desk)
	_solid(desk, Transform3D(), solids.sorting_desk)
	result.dead_letters = desk
	var headquarters := Headquarters.new()
	headquarters.stock = stock
	headquarters.places = places
	blockout.add_child(headquarters)
	_solid(headquarters, places.bench, solids.bench)
	result.headquarters = headquarters
	errors.append_array(stock.errors)
	if not errors.is_empty():
		push_error("ORISON V2 house office: %s" % [errors])
	root.set_meta("v2_house_office", result)
	return result


## Furniture is solid, like V2's own: each box is given in the piece's frame.
static func _solid(owner: Node3D, frame: Transform3D, boxes: Array) -> void:
	if boxes.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.transform = frame
	for box: Array in boxes:
		var low := Vector3(float(box[0][0]), float(box[0][1]), float(box[0][2]))
		var high := Vector3(float(box[1][0]), float(box[1][1]), float(box[1][2]))
		var shape := CollisionShape3D.new()
		var solid := BoxShape3D.new()
		solid.size = high - low
		shape.shape = solid
		shape.position = (low + high) * 0.5
		body.add_child(shape)
	owner.add_child(body)
