extends RefCounted
## Passive native kit. Performance timing and cast rigs remain separate owners.
const DATA := "res://data/orison_v2/harukiya_drumkit.json"

static func mount(parent: Node3D, placement: Transform3D) -> Node3D:
	if parent.has_node("HarukiyaDrumKit") or not placement.is_finite(): return null
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or int(decoded.get("schema_version", 0)) != 1: return null
	var data: Dictionary = decoded
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return null
	var model := packed.instantiate() as Node3D
	if model == null: return null
	var finishes := {}; var parts := {}; var seen := {}
	for row: Dictionary in data.materials:
		var key := str(row.catalog_key)
		var identity := str(row.key)
		if finishes.has(identity) or not MatLib.SETS.has(key) \
				or absf(float(MatLib.SETS[key][3]) - float(row.meters_per_tile)) > .000001:
			model.free(); return null
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(row.meters_per_tile)
		material.normal_scale = float(row.normal)
		material.roughness = float(row.roughness)
		var tint: Array = row.tint
		material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		finishes[identity] = {"material": material, "source": row}
	for part: Dictionary in data.partitions:
		if parts.has(str(part.mesh)): model.free(); return null
		parts[str(part.mesh)] = part
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not parts.has(identity) or seen.has(identity) or draw.mesh == null:
			model.free(); return null
		var part: Dictionary = parts[identity]
		if draw.mesh.get_surface_count() != part.materials.size() \
				or draw.mesh.get_faces().size() != int(part.triangles) * 3:
			model.free(); return null
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		for surface in part.materials.size():
			var finish: Dictionary = finishes.get(str(part.materials[surface]), {})
			if finish.is_empty(): model.free(); return null
			draw.mesh.surface_set_material(surface, finish.material)
			# Export partitions have one finish each, matching SurfacePass's owner.
			draw.set_meta("material_key", str(finish.source.catalog_key))
			draw.set_meta("harukiya_pigment", float(finish.source.pigment))
		draw.set_meta("harukiya_drum_part", identity)
		draw.name = "F01_retail_bar_" + identity
		draw.create_trimesh_collision()
		seen[identity] = true
	if seen.size() != parts.size(): model.free(); return null
	var contacts := Node3D.new(); contacts.name = "Contacts"; model.add_child(contacts)
	for identity: String in data.contacts:
		var row: Dictionary = data.contacts[identity]
		if not row.has("position"): continue
		var marker := Marker3D.new(); marker.name = identity
		marker.position = Vector3(row.position[0], row.position[1], row.position[2])
		marker.set_meta("contact", row.duplicate(true)); contacts.add_child(marker)
	model.name = "HarukiyaDrumKit"
	model.transform = placement
	model.set_meta("source", data)
	parent.add_child(model)
	return model

static func calibrate(model: Node3D) -> void:
	# Run after the region's shared optical/state pass, retaining its cache owner.
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not draw.has_meta("harukiya_drum_part"): continue
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_surface_override_material(surface) as ShaderMaterial
			if material != null:
				material.set_shader_parameter("pigment_variation", float(draw.get_meta("harukiya_pigment")))
