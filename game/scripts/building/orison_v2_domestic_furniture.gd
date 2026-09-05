extends RefCounted
## Individual source-derived assemblies. Adapter owns placement and teardown.
const PATH := "res://data/orison_v2/domestic_furniture.json"
const WaterCloset := preload("res://scripts/building/orison_v2_water_closet.gd")
const Wardrobe := preload("res://scripts/building/orison_v2_wardrobe.gd")
const MATERIAL_ALIASES := {"floor_oak": "oak_quartered", "fabric_cool": "linen", "fabric_green": "linen"}
const GARMENT_TINTS := {"fabric_cool": Color(0.36, 0.42, 0.51), "fabric_green": Color(0.38, 0.46, 0.36)}
var errors: Array[String] = []

func mount(adapter: Variant) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source, adapter):
		return false
	for record: Dictionary in source.furniture:
		var body: StaticBody3D
		if record.kind == "toilet":
			body = WaterCloset.new()
			body.call("setup", {"id": record.id, "asm": "toilet"})
		elif record.kind == "wardrobe":
			body = Wardrobe.new()
			body.call("setup", record.mechanism)
		else:
			body = StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			var low := _vector(record.bounds[0])
			var high := _vector(record.bounds[1])
			shape.size = high - low
			collision.shape = shape
			collision.position = (high + low) * 0.5
			body.add_child(collision)
		body.set_meta("v2_furniture_id", str(record.id))
		for surface: Dictionary in record.surfaces:
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			for i in range(0, surface.vertices.size(), 3):
				vertices.append(Vector3(surface.vertices[i], surface.vertices[i + 1], surface.vertices[i + 2]))
				normals.append(Vector3(surface.normals[i], surface.normals[i + 1], surface.normals[i + 2]))
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.material_override = _material(str(surface.material))
			body.add_child(visual)
		if not adapter.mount_consumer(str(record.id), body):
			body.free()
			errors.append("furniture mount refused: " + str(record.id))
			return false
	return true

func validate(source: Variant, adapter: Variant) -> bool:
	errors.clear()
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("furniture") is not Array:
		errors.append("malformed furniture source")
		return false
	var seen: Dictionary = {}
	for record: Variant in source.furniture:
		if record is not Dictionary or record.get("id") is not String or record.get("kind") not in ["bed", "workbench", "toilet", "nightstand", "wardrobe", "shelf"]:
			errors.append("invalid furniture identity or kind")
			continue
		if seen.has(record.id) or adapter == null or not adapter.resolve(record.id) is Node3D:
			errors.append("duplicate or missing furniture anchor: " + str(record.id))
		seen[record.id] = true
		if record.kind == "wardrobe":
			var mechanism: Variant = record.get("mechanism")
			if mechanism is not Dictionary or mechanism.size() != 4 \
					or mechanism.get("id") != record.id or mechanism.get("asm") != "wardrobe" \
					or mechanism.get("W") != 1.3 or mechanism.get("case_wood") != "oak_quartered":
				errors.append("invalid household wardrobe mechanism")
		var bounds: Variant = record.get("bounds")
		if bounds is not Array or bounds.size() != 2 or not _numbers(bounds[0], 3) or not _numbers(bounds[1], 3):
			errors.append("invalid furniture bounds")
			continue
		for axis in range(3):
			if bounds[1][axis] <= bounds[0][axis]:
				errors.append("inverted furniture bounds")
		if record.get("surfaces") is not Array or record.surfaces.is_empty():
			errors.append("missing furniture surfaces")
			continue
		for surface: Variant in record.surfaces:
			if surface is not Dictionary or surface.get("material") is not String:
				errors.append("invalid furniture surface")
				continue
			if surface.material != "glassish" and not MatLib.SETS.has(MATERIAL_ALIASES.get(surface.material, surface.material)):
				errors.append("unknown furniture material")
			var vertices: Variant = surface.get("vertices")
			if vertices is not Array or vertices.is_empty() or vertices.size() % 9 != 0:
				errors.append("invalid furniture triangles")
				continue
			if not _numbers(vertices, vertices.size()) or not _numbers(surface.get("normals"), vertices.size()):
				errors.append("invalid furniture coordinates or normals")
	if seen.is_empty():
		errors.append("empty furniture source")
	return errors.is_empty()

func _numbers(values: Variant, count: int) -> bool:
	if values is not Array or values.size() != count:
		return false
	for value: Variant in values:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	return true

func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _material(key: String) -> StandardMaterial3D:
	if key == "glassish":
		# Same alpha/tint policy as the source exporter; native optical review pending.
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.76, 0.85, 0.89, 0.16)
		glass.roughness = 0.06
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		return glass
	var material := MatLib.get_mat(str(MATERIAL_ALIASES.get(key, key)), GARMENT_TINTS.get(key, Color.WHITE))
	if GARMENT_TINTS.has(key):
		material = material.duplicate() as StandardMaterial3D
		material.roughness = 0.92
	return material
