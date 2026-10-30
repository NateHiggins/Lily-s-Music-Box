extends RefCounted
## Passive city assembly translations, authored in Blender metres. No state owner.
## The immutable geometry/UV stock stays shared; collision and roof fittings follow.
var source_offsets: Dictionary = {}

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_elevations.json"))
	assert(int(data.schema) == 1)
	for row: Dictionary in data.buildings:
		var values: Array = row.get("assembly_translation_m", [0., 0., 0.])
		assert(values.size() == 3)
		var offset := Vector3(float(values[0]), float(values[1]), float(values[2]))
		assert(offset.is_finite() and not source_offsets.has(str(row.id)))
		source_offsets[str(row.id)] = offset

func source_offset(identity: String) -> Vector3:
	for key: String in source_offsets:
		if identity == key or identity.begins_with(key + "_"):
			return source_offsets[key]
	return Vector3.ZERO

func city_offset(identity: String) -> Vector3:
	var source := source_offset(identity)
	return GameBoot.b2g([source.x, source.y, source.z])

func apply(draw: MeshInstance3D) -> void:
	assert(not draw.has_meta("city_assembly_translation"), "City assembly must move once")
	var offset := city_offset(str(draw.name))
	draw.position += offset
	draw.set_meta("city_assembly_translation", offset)
