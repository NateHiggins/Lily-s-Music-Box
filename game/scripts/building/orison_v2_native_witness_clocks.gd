extends RefCounted
## Native stock for the eighteen witness clocks and the two honest clocks
## (art/blender/scripts/build_witness_clocks.py). The V1 clock scripts keep
## every reading, tell and inspection; this binds what is seen: Blender parts
## in registered catalogue finishes, and the Label3D numerals and readings the
## builder placed (RUL-008: no numerals in any texture).
const PATH := "res://data/orison_v2/witness_clocks.json"
const FONT_SIZE := 64
## A Label3D capital's height as a share of its font size, near enough for
## every face used here.
const CAP := 0.70

var styles: Dictionary = {}
var errors: Array[String] = []
var _materials: Dictionary = {}
var _fonts: Dictionary = {}
var _prepared := false


func prepare() -> bool:
	if _prepared:
		return errors.is_empty()
	_prepared = true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary) or int(data.get("schema_version", 0)) != 1:
		errors.append("witness clock data missing")
		return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("witness clock stock missing")
		return false
	var model := packed.instantiate()
	for style: String in data.styles:
		var spec: Dictionary = data.styles[style]
		var root := model.find_child(str(spec.root), true, false) as Node3D
		if root == null:
			errors.append("witness clock assembly missing: " + style)
			continue
		var rows: Array = []
		for row: Dictionary in spec.parts:
			var draw := root.get_node_or_null(NodePath(str(row.name))) as MeshInstance3D
			if draw == null or draw.mesh == null:
				errors.append("witness clock part missing: " + str(row.name))
				continue
			rows.append({"row": row, "mesh": draw.mesh, "pose": draw.transform})
		styles[style] = {"spec": spec, "rows": rows}
	model.free()
	return errors.is_empty()


## One finish per catalogue key and tint, shared by every clock that wears it.
func finish(key: String, tint: Color) -> Material:
	var id := key + "|" + tint.to_html()
	if _materials.has(id):
		return _materials[id]
	var result: Material
	if key == "glassish":
		result = preload("res://scripts/building/orison_v2_architectural_materials.gd").new().material_for("Glazing", "domestic")
	elif MatLib.SETS.has(key):
		var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		mat.uv1_triplanar = false
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.albedo_color = tint
		result = mat
	else:
		errors.append("unregistered witness clock finish: " + key)
	_materials[id] = result
	return result


## Mounts one style's parts on `prop`. Static case parts hang on the prop,
## dial parts on `face`; every moving part gets a Node3D at its true pivot,
## returned by component name.
func mount_on(prop: Node3D, style: String, accent: Color, face: Node3D) -> Dictionary:
	if not styles.has(style):
		return {}
	var spec: Dictionary = styles[style].spec
	var pivots: Dictionary = {}
	for part: Dictionary in styles[style].rows:
		var row: Dictionary = part.row
		var tint := Color.WHITE
		if row.has("tint"):
			tint = accent if str(row.tint) == "accent" else Color.from_string(str(row.tint), Color.WHITE)
		var material := finish(str(row.material), tint)
		if material == null:
			return {}
		var draw := MeshInstance3D.new()
		draw.name = str(row.name)
		draw.mesh = part.mesh
		draw.material_override = material
		draw.set_meta("v2_witness_clock_part", str(row.component))
		var parent: Node3D = face if str(row.rig) == "face" else prop
		if bool(row.moving):
			var component := str(row.component)
			if not pivots.has(component):
				var pivot := Node3D.new()
				pivot.name = component
				parent.add_child(pivot)
				pivot.transform = part.pose
				pivots[component] = pivot
			pivots[component].add_child(draw)
		else:
			parent.add_child(draw)
			draw.transform = part.pose
	var numerals: Array[Label3D] = []
	for row: Dictionary in spec.get("labels", []):
		var numeral := _label(str(row.font), float(row.height))
		numeral.name = "Numeral%02d" % numerals.size()
		numeral.text = str(row.text)
		numeral.modulate = Color.from_string(str(row.color), Color.BLACK)
		numeral.shaded = true
		numeral.position = vec(row.at)
		numeral.visibility_range_end = 14.0
		face.add_child(numeral)
		numerals.append(numeral)
	var display: Label3D = null
	if spec.get("display") is Dictionary:
		display = _label(str(spec.display.font), float(spec.display.height))
		display.name = "Reading"
		display.position = vec(spec.display.at)
		face.add_child(display)
	prop.set_meta("v2_native_witness_clock", style)
	return {"spec": spec, "pivots": pivots, "numerals": numerals, "display": display}


func _label(font_path: String, height: float) -> Label3D:
	var label := Label3D.new()
	if not _fonts.has(font_path):
		_fonts[font_path] = load(font_path)
	label.font = _fonts[font_path]
	label.font_size = FONT_SIZE
	label.pixel_size = height / (FONT_SIZE * CAP)
	label.outline_size = 0
	label.double_sided = false
	label.no_depth_test = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return label


static func vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func bounds(spec: Dictionary) -> AABB:
	var lo := vec(spec.bounds[0])
	var hi := vec(spec.bounds[1])
	return AABB(lo, hi - lo)
