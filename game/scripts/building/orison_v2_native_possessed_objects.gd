extends RefCounted
## Native stock for the possessed household objects V2 had no counterpart for
## (art/blender/scripts/build_possessed_objects.py). The V1 prop script keeps
## the tell's owner, timing and inspection copy; this binds what is seen:
## Blender parts in registered catalogue finishes, each moving part on its own
## pivot, and the Label3D numerals the builder placed (RUL-008).
const PATH := "res://data/orison_v2/possessed_object_stock.json"
const FONT := "res://assets/fonts/courier_prime/CourierPrime-Regular.ttf"
const FONT_SIZE := 64
## A Label3D capital's height as a share of its font size.
const CAP := 0.70
const SEEN_TO := 12.0
const READ_TO := 3.0

var kinds: Dictionary = {}
var errors: Array[String] = []
var _materials: Dictionary = {}
var _font: Font
var _prepared := false


func prepare() -> bool:
	if _prepared:
		return errors.is_empty()
	_prepared = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary) or int(data.get("schema_version", 0)) != 1 or not (data.get("kinds") is Array):
		errors.append("possessed object stock data missing")
		return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("possessed object stock missing")
		return false
	var model := packed.instantiate()
	for spec: Dictionary in data.kinds:
		var id := str(spec.id)
		var root := model.find_child(str(spec.root), true, false) as Node3D
		if root == null:
			errors.append("possessed object assembly missing: " + id)
			continue
		var rows: Array = []
		for row: Dictionary in spec.parts:
			var draw := root.get_node_or_null(NodePath(str(row.name))) as MeshInstance3D
			if draw == null or draw.mesh == null:
				errors.append("possessed object part missing: " + str(row.name))
				continue
			var tint := Color.WHITE if str(row.tint).is_empty() else Color.from_string(str(row.tint), Color.WHITE)
			if finish(str(row.material), tint) == null:
				continue
			rows.append({"name": str(row.name), "component": str(row.component), "material": str(row.material),
				"tint": tint, "moving": bool(row.moving), "mesh": draw.mesh, "pose": draw.transform})
		var labels: Array = []
		for label: Dictionary in spec.labels:
			labels.append({"text": str(label.text), "at": vec(label.at), "height": float(label.height),
				"color": Color.from_string(str(label.color), Color.BLACK)})
		var lo := vec(spec.bounds[0])
		kinds[id] = {"mounting": str(spec.mounting), "bounds": AABB(lo, vec(spec.bounds[1]) - lo), "rows": rows,
			"labels": labels}
	model.free()
	return errors.is_empty()


## One finish per catalogue key and tint, shared by every object that wears it.
func finish(key: String, tint: Color) -> StandardMaterial3D:
	var id := key + "|" + tint.to_html()
	if _materials.has(id):
		return _materials[id]
	var result: StandardMaterial3D = null
	if MatLib.SETS.has(key):
		result = MatLib.get_mat(key).duplicate() as StandardMaterial3D
		result.uv1_triplanar = false
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		result.albedo_color = tint
	else:
		errors.append("unregistered possessed object finish: " + key)
	_materials[id] = result
	return result


func mounting(kind: String) -> String:
	return str(kinds.get(kind, {}).get("mounting", ""))


func bounds(kind: String) -> AABB:
	return kinds.get(kind, {}).get("bounds", AABB())


## Mounts one assembly on `prop`. Static parts hang on the prop; every moving
## part gets a Node3D at its true pivot, returned by component name.
func mount_on(prop: Node3D, kind: String) -> Dictionary:
	if not kinds.has(kind):
		return {}
	var pivots: Dictionary = {}
	for row: Dictionary in kinds[kind].rows:
		var draw := MeshInstance3D.new()
		draw.name = str(row.name)
		draw.mesh = row.mesh
		draw.material_override = finish(str(row.material), row.tint)
		draw.visibility_range_end = SEEN_TO
		draw.set_meta("v2_possessed_object_part", str(row.component))
		if bool(row.moving):
			var component := str(row.component)
			if not pivots.has(component):
				var pivot := Node3D.new()
				pivot.name = component
				prop.add_child(pivot)
				pivot.transform = row.pose
				pivots[component] = pivot
			pivots[component].add_child(draw)
		else:
			prop.add_child(draw)
			draw.transform = row.pose
	var count := 0
	for row: Dictionary in kinds[kind].labels:
		if _font == null:
			_font = load(FONT)
		var label := Label3D.new()
		label.name = "Numeral%02d" % count
		count += 1
		label.font = _font
		label.font_size = FONT_SIZE
		label.pixel_size = float(row.height) / (FONT_SIZE * CAP)
		label.outline_size = 0
		label.double_sided = false
		label.shaded = true
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		label.text = str(row.text)
		label.modulate = row.color
		label.position = row.at
		label.visibility_range_end = READ_TO
		prop.add_child(label)
	prop.set_meta("v2_native_possessed_object", kind)
	return {"parts": pivots}


static func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
