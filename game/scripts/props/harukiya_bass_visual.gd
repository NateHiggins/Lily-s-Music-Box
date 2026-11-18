extends RefCounted
## Visual representation of the inventory bass at its existing assembly origin.
## Inventory ownership and the original home interaction remain with their owners.
const DATA := "res://data/orison_v2/harukiya_bass_visual.json"

static func instantiate(texture_scale: float = 1.0) -> Node3D:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if document is not Dictionary or int(document.get("schema_version", 0)) != 1:
		return null
	var packed := load(str(document.asset)) as PackedScene
	if packed == null:
		return null
	var bass := packed.instantiate() as Node3D
	if bass == null:
		return null
	var finishes := {}
	for row: Dictionary in document.materials:
		var source := MatLib.get_mat(str(row.catalog_key)) as StandardMaterial3D
		if source == null:
			bass.free()
			return null
		var material := source.duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE * texture_scale / float(row.meters_per_tile)
		material.roughness = float(row.roughness)
		if row.has("normal"):
			material.normal_scale = float(row.normal)
		material.albedo_color = Color(row.tint[0], row.tint[1], row.tint[2], row.tint[3])
		finishes[str(row.key)] = material
	var parts := {}
	for row: Dictionary in document.partitions:
		parts[str(row.mesh)] = row.materials
	for draw: MeshInstance3D in bass.find_children("*", "MeshInstance3D", true, false):
		var keys: Array = parts.get(str(draw.name), [])
		if keys.is_empty() or draw.mesh == null or draw.mesh.get_surface_count() != keys.size():
			bass.free()
			return null
		for index: int in keys.size():
			if not finishes.has(keys[index]):
				bass.free()
				return null
			draw.set_surface_override_material(index, finishes[keys[index]])
		parts.erase(str(draw.name))
	if not parts.is_empty():
		bass.free()
		return null
	return bass
