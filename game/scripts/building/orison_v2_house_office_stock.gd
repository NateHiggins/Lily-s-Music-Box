extends RefCounted
## The Blender-authored house office (art/blender/scripts/build_house_office.py):
## one imported model, catalogue materials bound by key, charts already in
## tiles, and the measures the sorting desk and the headquarters are worked by.
const PATH := "res://data/orison_v2/house_office.json"
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const INK := Color(0.09, 0.08, 0.07)
## The room is under ten metres long; nothing here is drawn from outside it.
const RANGE := 14.0
const WORDS_RANGE := 6.0

var errors: Array[String] = []
## Assembly id to its parts: [{name, component, mesh, pose, material}].
var assemblies: Dictionary = {}
# The sorting desk, in the desk's own frame (metres).
var tray := Vector3.ZERO
var rail := Vector3.ZERO
var astray := Vector3.ZERO
var carriage_home := 0.0
var stops: Array[float] = []
var dead_stop := 0.0
var dead_lift := 0.0
var rows: Array[float] = []
var hole_front := 0.0
var dead_front := 0.0
var sheet := 0.0
var row_labels: Array = []
var dead_label := Vector3.ZERO
var tally := Vector3.ZERO
var tally_width := 0.0
# The headquarters.
var cards: Array[Vector3] = []
var plaque_words := Vector3.ZERO
var plaque_width := 0.0
var trophy_columns := 0
var trophy_rows := 0
var trophy_pitch := Vector2.ZERO
var trophy_status := Vector3.ZERO
var _materials: Dictionary = {}


func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("assemblies") is not Array:
		errors.append("malformed house office stock")
		return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("house office model missing: " + str(data.asset))
		return false
	var model := packed.instantiate()
	for row: Dictionary in data.assemblies:
		var parts: Array = []
		for part: Dictionary in row.parts:
			var draw := model.find_child(str(part.name), true, false) as MeshInstance3D
			var key := str(part.material)
			if draw == null or draw.mesh == null or not MatLib.SETS.has(key):
				errors.append("house office part or finish absent: " + str(part.name))
				continue
			var tint: Array = part.get("tint", [])
			var colour := Color.WHITE if tint.size() != 3 else Color(float(tint[0]), float(tint[1]), float(tint[2]))
			parts.append({"name": str(part.name), "component": str(part.component), "mesh": draw.mesh,
				"pose": draw.transform, "key": key, "material": finish(key, colour)})
		assemblies[str(row.id)] = parts
	model.free()
	var sorting: Dictionary = data.sorting
	tray = _point(sorting.tray)
	rail = _point(sorting.rail)
	astray = _point(sorting.astray)
	carriage_home = float(sorting.carriage_home)
	for value: float in sorting.stops:
		stops.append(value)
	dead_stop = float(sorting.dead_stop)
	dead_lift = float(sorting.dead_lift)
	for value: float in sorting.rows:
		rows.append(value)
	hole_front = float(sorting.hole_front)
	dead_front = float(sorting.dead_front)
	sheet = float(sorting.sheet)
	for row: Array in sorting.row_labels:
		var places: Array[Vector3] = []
		for place: Array in row:
			places.append(_point(place))
		row_labels.append(places)
	dead_label = _point(sorting.dead_label)
	tally = _point(sorting.tally)
	tally_width = float(sorting.tally_width)
	var bench: Dictionary = data.bench
	for place: Array in bench.cards:
		cards.append(_point(place))
	var plaque: Dictionary = data.plaque
	plaque_words = _point(plaque.words)
	plaque_width = float(plaque.width)
	var trophies: Dictionary = data.trophies
	trophy_columns = int(trophies.columns)
	trophy_rows = int(trophies.rows)
	trophy_pitch = Vector2(float(trophies.pitch[0]), float(trophies.pitch[1]))
	trophy_status = _point(trophies.status)
	return errors.is_empty()


static func _point(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


## A catalogue finish for authored charts: the registered material, untiled
## by triplanar projection, tinted where the part asks.
func finish(key: String, tint := Color.WHITE) -> StandardMaterial3D:
	var id := "%s|%s" % [key, tint.to_html()]
	if not _materials.has(id):
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if tint != Color.WHITE:
			material.albedo_color = tint
		_materials[id] = material
	var found: StandardMaterial3D = _materials[id]
	return found


## One component of an assembly as a node standing on that component's own
## origin, its meshes under it. `tint` recolours every part of it.
func part_node(assembly: String, component: String, tint := Color.WHITE) -> Node3D:
	var holder := Node3D.new()
	holder.name = component
	var first := true
	for part: Dictionary in assemblies.get(assembly, []):
		if str(part.component) != component:
			continue
		var pose: Transform3D = part.pose
		if first:
			holder.transform = pose
			first = false
		var draw := MeshInstance3D.new()
		draw.name = str(part.name)
		draw.mesh = part.mesh as Mesh
		draw.material_override = (part.material as Material) if tint == Color.WHITE else finish(str(part.key), tint)
		draw.visibility_range_end = RANGE
		draw.transform = holder.transform.affine_inverse() * pose
		draw.set_meta("house_office_part", str(part.name))
		holder.add_child(draw)
	if first:
		errors.append("no such house office part: %s/%s" % [assembly, component])
	return holder


## Authored words on paper, brass or board: Courier Prime, one-sided, lit by
## the room. `letter` is the height of one line of type in metres.
func words(text: String, width: float, letter: float, ink := INK) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 48
	label.pixel_size = letter / 48.0
	label.width = width / label.pixel_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = ink
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.visibility_range_end = WORDS_RANGE
	return label
