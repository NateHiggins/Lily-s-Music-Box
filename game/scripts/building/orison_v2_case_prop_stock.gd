extends RefCounted
## The Blender-authored case-prop library (art/blender/scripts/build_case_props.py):
## one imported model, catalogue materials bound by key, charts already in tiles.
const PATH := "res://data/orison_v2/case_props.json"
## Beyond these distances a small object is not drawn: every flat is far
## smaller, and the frame is bound by draw calls.
const SMALL_RANGE := 16.0
const LARGE_RANGE := 32.0

var assemblies: Dictionary = {}
var errors: Array[String] = []
var _materials: Dictionary = {}


func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("assemblies") is not Array:
		errors.append("malformed case prop stock")
		return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		errors.append("case prop model missing: " + str(data.asset))
		return false
	var model := packed.instantiate()
	for row: Dictionary in data.assemblies:
		var parts: Array = []
		for part: Dictionary in row.parts:
			var draw := model.find_child(str(part.name), true, false) as MeshInstance3D
			var key := str(part.material)
			if draw == null or draw.mesh == null or not MatLib.SETS.has(key):
				errors.append("case prop part or finish absent: " + str(part.name))
				continue
			var tint: Array = part.get("tint", [])
			parts.append({"name": str(part.name), "component": str(part.component), "mesh": draw.mesh,
				"pose": draw.transform, "material": _material(key, tint),
				"motion": str(part.get("motion", "")), "amount": float(part.get("amount", 0.0))})
		var low: Array = row.bounds[0]
		var high: Array = row.bounds[1]
		var box := AABB(Vector3(low[0], low[1], low[2]),
			Vector3(float(high[0]) - float(low[0]), float(high[1]) - float(low[1]), float(high[2]) - float(low[2])))
		assemblies[str(row.id)] = {"parts": parts, "bounds": box}
	model.free()
	return errors.is_empty()


func has(asset: String) -> bool:
	return assemblies.has(asset)


func bounds(asset: String) -> AABB:
	if not assemblies.has(asset):
		return AABB()
	var box: AABB = assemblies[asset].bounds
	return box


## Adds the assembly's meshes under `holder` and returns them with their roles:
## [{draw, component, motion, amount}].
func mount_on(holder: Node3D, asset: String) -> Array:
	var mounted: Array = []
	if not assemblies.has(asset):
		return mounted
	var record: Dictionary = assemblies[asset]
	var box: AABB = record.bounds
	var extent: float = box.get_longest_axis_size()
	for part: Dictionary in record.parts:
		var draw := MeshInstance3D.new()
		draw.name = str(part.name)
		draw.mesh = part.mesh as Mesh
		draw.material_override = part.material as Material
		draw.visibility_range_end = SMALL_RANGE if extent < 0.6 else LARGE_RANGE
		if extent < 0.2:
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(draw)
		var pose: Transform3D = part.pose
		draw.transform = pose
		draw.set_meta("case_prop_part", str(part.name))
		mounted.append({"draw": draw, "component": str(part.component), "motion": str(part.motion),
			"amount": float(part.amount)})
	holder.set_meta("v2_native_case_prop", asset)
	return mounted


func _material(key: String, tint: Array) -> StandardMaterial3D:
	var id := "%s|%s" % [key, str(tint)]
	if not _materials.has(id):
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if tint.size() == 3:
			material.albedo_color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
		_materials[id] = material
	var found: StandardMaterial3D = _materials[id]
	return found
