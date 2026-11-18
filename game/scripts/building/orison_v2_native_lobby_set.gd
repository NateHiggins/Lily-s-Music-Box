extends RefCounted
## Native stock for the lobby set (notice board, Orison broadside, mail chute).
## Resolves every part of lobby_set.glb to a duplicated catalogue material; the
## three V1 prop scripts keep every state, word and interaction.
const PATH := "res://data/orison_v2/lobby_set.json"
const Glazing := preload("res://scripts/building/orison_v2_architectural_materials.gd")

var parts: Dictionary = {}
var errors: Array[String] = []


func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("parts") is not Array:
		errors.append("lobby set part table missing or of another schema")
		return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("lobby set stock missing: " + str(data.asset))
		return false
	var model := packed.instantiate()
	var materials: Dictionary = {}
	for row: Dictionary in data.parts:
		var draw := model.find_child(str(row.name), true, false) as MeshInstance3D
		var key := str(row.material)
		if draw == null or draw.mesh == null:
			errors.append("lobby set part missing: " + str(row.name))
			continue
		var tint := Color.WHITE
		if row.has("tint"):
			tint = Color(float(row.tint[0]), float(row.tint[1]), float(row.tint[2]))
		var id := key + "|" + tint.to_html()
		if not materials.has(id):
			if key == "glass":
				materials[id] = Glazing.new().material_for("Glazing", "domestic")
			elif MatLib.SETS.has(key):
				var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				mat.uv1_triplanar = false
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mat.albedo_color = tint
				materials[id] = mat
			else:
				errors.append("unregistered lobby set finish: " + key)
				continue
		parts[str(row.name)] = {"name": str(row.name), "assembly": str(row.assembly), "component": str(row.component),
			"role": str(row.role), "key": key, "mesh": draw.mesh, "pose": draw.transform, "material": materials[id]}
	model.free()
	return errors.is_empty()


## One part as a MeshInstance3D on its authored pivot.
func draw(part_name: String) -> MeshInstance3D:
	var part: Dictionary = parts.get(part_name, {})
	if part.is_empty():
		push_error("V2 lobby set: no part named " + part_name)
		return null
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = part.mesh
	node.material_override = part.material
	node.transform = part.pose
	node.set_meta("native_lobby_set_part", part_name)
	node.set_meta("material_key", part.key)
	return node


func pose(part_name: String) -> Transform3D:
	return (parts.get(part_name, {}) as Dictionary).get("pose", Transform3D.IDENTITY)


## Every fixed part of one assembly, added under `prop`.
func mount_static(prop: Node3D, assembly: String) -> int:
	var count := 0
	for part_name: String in parts:
		var part: Dictionary = parts[part_name]
		if part.assembly == assembly and part.role == "static":
			prop.add_child(draw(part_name))
			count += 1
	return count


## Authored lettering: single-sided ink that takes the room's light with its
## paper (unlit ink glows on a dim wall), never a texture (RUL-008).
static func lettering(words: String, font_path: String, font_size: int, pixel_size: float, ink: Color, at: Vector3) -> Label3D:
	var text := Label3D.new()
	text.text = words
	text.font = load(font_path) as Font
	text.font_size = font_size
	text.pixel_size = pixel_size
	text.modulate = ink
	text.outline_size = 0
	text.shaded = true
	text.double_sided = false
	text.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	text.position = at
	return text


## Pixel size at which the widest line of `words` is `width` metres across.
static func fit(words: String, font_path: String, font_size: int, width: float) -> float:
	var font := load(font_path) as Font
	var widest := 1.0
	for line in words.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return width / widest
