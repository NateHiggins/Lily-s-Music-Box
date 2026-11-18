extends RefCounted
## Native stock for the apparatus set: the soda-acid extinguisher and the
## overhead door check (art/blender/scripts/build_fire_apparatus.py). This binds
## each Blender part to its catalogue finish; the V1 prop scripts keep every
## state, refusal and record.
const PATH := "res://data/orison_v2/fire_apparatus.json"
const Glass := preload("res://scripts/building/orison_v2_expressive_glass.gd")
## A fitting this small is not drawn from across the building.
const DRAW_RANGE := 24.0

static var _shared: RefCounted

var data: Dictionary = {}
var parts: Dictionary = {}
var errors: Array[String] = []


## One prepared stock for every unit: the meshes and finishes are shared.
static func shared() -> RefCounted:
	if _shared == null:
		var stock: RefCounted = load("res://scripts/building/orison_v2_native_fire_apparatus.gd").new()
		if not stock.prepare():
			push_error("V2 fire apparatus stock refused: %s" % [stock.errors])
			return null
		_shared = stock
	return _shared


func prepare() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		errors.append("fire apparatus data missing")
		return false
	data = parsed
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("fire apparatus asset missing")
		return false
	var model := packed.instantiate()
	var finishes: Dictionary = {}
	for row: Dictionary in data.parts:
		var draw := model.find_child(str(row.name), true, false) as MeshInstance3D
		var key := str(row.material)
		if draw == null or draw.mesh == null or not MatLib.SETS.has(key):
			errors.append("stock or finish absent: %s / %s" % [row.name, key])
			continue
		var tint := Color.WHITE
		if row.has("tint"):
			tint = Color(float(row.tint[0]), float(row.tint[1]), float(row.tint[2]))
		var finish_id := "%s|%s" % [key, tint.to_html()]
		if not finishes.has(finish_id):
			var finish: StandardMaterial3D
			if key.begins_with("glass_"):
				finish = Glass.make(key)
			else:
				finish = MatLib.get_mat(key).duplicate() as StandardMaterial3D
				finish.uv1_triplanar = false
				finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				finish.albedo_color = tint
			if finish == null:
				errors.append("finish refused: " + key)
				continue
			finishes[finish_id] = finish
		parts[str(row.name)] = {"mesh": draw.mesh, "material": finishes[finish_id],
				"component": str(row.component), "rest": draw.transform}
	model.free()
	return errors.is_empty() and parts.size() == data.parts.size()


## A fresh draw of one named part, at the origin of whatever it is hung on.
func draw(part_name: String, node_name := "") -> MeshInstance3D:
	if not parts.has(part_name):
		push_error("V2 fire apparatus part missing: " + part_name)
		return null
	var part: Dictionary = parts[part_name]
	var node := MeshInstance3D.new()
	node.name = node_name if not node_name.is_empty() else part_name
	node.mesh = part.mesh
	node.material_override = part.material
	node.visibility_range_end = DRAW_RANGE
	node.set_meta("v2_native_fire_apparatus_part", part_name)
	return node


func datum(group: String, key: String) -> Vector3:
	var value: Array = data[group][key]
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
