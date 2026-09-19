extends RefCounted
const PATH := "res://data/orison_v2/bookshelves.json"
const Shelf := preload("res://scripts/building/orison_v2_bookshelf.gd")
const ROSTER := {
	"2A":["Mina Vale","repaired"], "3A":["Malcolm Reed","repaired"],
	"4A":["Peter Wren","sectional"], "5A":["Nadia Quell","plain"],
	"5C":["Iris Bell","plain"], "6A":["Sacha Reed","repaired"],
	"6B":["Jonah Price","plain"], "6C":["Mae Kessler","sectional"]}
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source, adapter): return false
	var acoustic_ids: Array[String] = []
	for record: Dictionary in source.shelves:
		if AcousticGraphData.nodes.has(record.id): acoustic_ids.append(str(record.id))
	if not acoustic_ids.is_empty() and not adapter.install_acoustic_overrides(acoustic_ids):
		errors.append("bookshelf acoustic anchors could not be rebound")
		return false
	for record: Dictionary in source.shelves:
		var prop := Shelf.new()
		prop.prop_type = "bookshelf"
		prop.unit = record.unit
		prop.owner_name = record.owner
		prop.case_style = record.style
		prop.canonical_book = record.canonical_book
		if AcousticGraphData.nodes.has(record.id): prop.graph_node_id = record.id
		var body := StaticBody3D.new()
		body.name = "InstalledCaseCollision"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var lo := Vector3(record.bounds[0][0],0,record.bounds[0][2])
		var hi := Vector3(record.bounds[1][0],1.34 if record.style == "sectional" else record.bounds[1][1],record.bounds[1][2])
		box.size = hi-lo
		shape.shape = box
		shape.position = (hi+lo)*.5
		body.add_child(shape)
		prop.add_child(body)
		if not adapter.mount_consumer(record.id, prop):
			prop.free()
			errors.append("bookshelf mount refused: " + str(record.id))
			return false
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("shelves") is not Array or adapter == null:
		errors.append("invalid bookshelf manifest")
		return false
	var seen := {}
	for record: Variant in source.shelves:
		if record is not Dictionary or record.get("unit") not in ROSTER:
			errors.append("unknown bookshelf household")
			continue
		var unit_id := str(record.unit)
		var identity := "F0" + unit_id[0] + "_" + unit_id + "_BOOKSHELF_01"
		if seen.has(unit_id) or record.get("id") != identity or record.get("owner") != ROSTER[unit_id][0] or record.get("style") != ROSTER[unit_id][1] or record.get("canonical_book") != ("prospectus" if unit_id == "6C" else ""):
			errors.append("bookshelf identity/library differs from authored resident")
		seen[unit_id] = true
		var anchor: Node = adapter.resolve(identity)
		if not anchor is Marker3D or not adapter.resolve(identity+"_STANCE") is Marker3D:
			errors.append("missing bookshelf installation/approach anchor")
		var expected: Array
		match ROSTER[unit_id][1]:
			"plain": expected = [[-.38,0,-.146],[.38,1.30,.14]]
			"repaired": expected = [[-.371,0,-.131],[.377,1.22,.146]]
			_: expected = [[-.43,0,-.17],[.43,1.54,.171]]
		if not _same_bounds(record.get("bounds"), expected): errors.append("bookshelf clearance differs from native case")
	if seen.size() != ROSTER.size() or source.shelves.size() != ROSTER.size(): errors.append("incomplete bookshelf roster")
	return errors.is_empty()

func _same_bounds(value: Variant, expected: Array) -> bool:
	if value is not Array or value.size() != 2: return false
	for i in 2:
		if value[i] is not Array or value[i].size() != 3: return false
		for j in 3:
			if typeof(value[i][j]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[i][j])) or not is_equal_approx(float(value[i][j]),float(expected[i][j])): return false
	return true
