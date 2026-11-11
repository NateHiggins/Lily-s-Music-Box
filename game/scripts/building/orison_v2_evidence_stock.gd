extends RefCounted
## The evidence pieces, the newspaper bundle and the map pin
## (art/blender/scripts/build_evidence_pieces.py): one imported model,
## catalogue materials bound by key and tinted from the data file, charts
## already in tiles.
##
## build(id) returns a new node whose origin is the centre of the piece's back
## face, with +Z its face normal and +Y up when it hangs on a wall. The pin is
## the one exception: its origin is where the shaft enters the wall, and its
## point lies behind that (-Z).
const PATH := "res://data/orison_v2/evidence_pieces.json"
const Finishes := preload("res://scripts/building/orison_v2_architectural_materials.gd")
## The house glazing route (the key the other native families use for panes).
const GLASS := "glassish"
## Beyond this a piece is not drawn: the frame is bound by draw calls.
const SMALL_RANGE := 12.0
const LARGE_RANGE := 16.0

var errors: Array[String] = []
var _pieces: Dictionary = {}
var _materials: Dictionary = {}


func prepare() -> bool:
	errors.clear()
	_pieces.clear()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("pieces") is not Array:
		errors.append("malformed evidence stock")
		return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("evidence model missing: " + str(data.asset))
		return false
	var model := packed.instantiate()
	for row: Dictionary in data.pieces:
		var id := str(row.id)
		var extent: Array = row.size
		if str(row.face_axis) != "z" or str(row.up_axis) != "y" or extent.size() != 3:
			errors.append("evidence piece is not laid out face +Z, up +Y: " + id)
			continue
		var parts: Array = []
		for part: Dictionary in row.parts:
			var draw := model.find_child(str(part.name), true, false) as MeshInstance3D
			var key := str(part.material)
			if draw == null or draw.mesh == null or not (key == GLASS or MatLib.SETS.has(key)):
				errors.append("evidence part or finish absent: " + str(part.name))
				continue
			var tint: Array = part.get("tint", [])
			parts.append({"name": str(part.name), "mesh": draw.mesh, "pose": draw.transform,
				"material": _material(key, tint, float(part.get("alpha", 1.0))),
				"sorting": float(part.get("sorting_offset", 0.0))})
		_pieces[id] = {"size": Vector3(float(extent[0]), float(extent[1]), float(extent[2])), "parts": parts}
	model.free()
	return errors.is_empty()


func has(id: String) -> bool:
	return _pieces.has(id)


## Width (X), height (Y) and depth off the wall (Z) of the piece, in metres.
func size(id: String) -> Vector3:
	if not _pieces.has(id):
		return Vector3.ZERO
	var found: Vector3 = _pieces[id].size
	return found


func build(id: String) -> Node3D:
	if not _pieces.has(id):
		return null
	var record: Dictionary = _pieces[id]
	var extent: Vector3 = record.size
	var large := maxf(extent.x, maxf(extent.y, extent.z)) > 0.25
	var holder := Node3D.new()
	holder.name = id
	holder.set_meta("evidence_piece", id)
	for part: Dictionary in record.parts:
		var draw := MeshInstance3D.new()
		draw.name = str(part.name)
		draw.mesh = part.mesh as Mesh
		draw.material_override = part.material as Material
		draw.visibility_range_end = LARGE_RANGE if large else SMALL_RANGE
		draw.sorting_offset = float(part.sorting)
		if not large:
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(draw)
		var pose: Transform3D = part.pose
		draw.transform = pose
	return holder


func _material(key: String, tint: Array, alpha: float) -> Material:
	var id := "%s|%s|%s" % [key, str(tint), str(alpha)]
	if not _materials.has(id):
		if key == GLASS:
			_materials[id] = Finishes.new().material_for("Glazing", "domestic")
		else:
			var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar = false
			material.uv1_scale = Vector3.ONE
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			var colour := Color.WHITE
			if tint.size() == 3:
				colour = Color(float(tint[0]), float(tint[1]), float(tint[2]))
			if alpha < 1.0:
				colour.a = alpha
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = colour
			_materials[id] = material
	var found: Material = _materials[id]
	return found
