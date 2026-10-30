extends RefCounted
## Passive source-owned station. Engine mesh LOD is selected for each viewport,
## including narrow-field instruments; collision always uses the near source.
const NEAR := preload("res://assets/props/city_transport.glb")
const FAR := preload("res://assets/props/city_transport_lod1.glb")
const FINISHES := "res://data/orison_v2/exterior/city_transport.json"

static func mount(city: Node3D) -> Node3D:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	assert(int(data.schema) == 1 and float(data.lod_error_m) > 0.)
	var model := NEAR.instantiate() as Node3D
	var low := FAR.instantiate() as Node3D
	model.name = "EasternPlazaStation"
	city.add_child(model)
	var far_parts: Dictionary = {}
	for draw: MeshInstance3D in low.find_children("*", "MeshInstance3D", true, false):
		far_parts[str(draw.name).replace("_L1__", "_L0__")] = draw
	var materials: Dictionary = {}
	for spec: Dictionary in data.finishes:
		var alias := str(spec.alias)
		var key := str(spec.catalog_key)
		assert(MatLib.SETS.has(key) and is_equal_approx(float(spec.pigment), 1.))
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var tint: Array = spec.tint
		material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		material.normal_scale = float(spec.normal)
		material.roughness *= float(spec.roughness)
		# The substrate recipe also supplies unpainted iron. Its pigment coat
		# is dielectric; bare rail heads retain the metallic source response.
		material.metallic = float(spec.get("metallic", material.metallic))
		materials[alias] = material
	var seen: Array[String] = []
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		assert(identity in data.parts and far_parts.has(identity))
		var far_draw: MeshInstance3D = far_parts[identity]
		assert(draw.transform.is_equal_approx(far_draw.transform))
		assert(draw.mesh.get_surface_count() == 1 and far_draw.mesh.get_surface_count() == 1)
		var near_mesh := draw.mesh
		draw.mesh = _with_lod(near_mesh, far_draw.mesh, float(data.lod_error_m))
		draw.material_override = materials[identity.split("__")[-1]]
		draw.set_meta("v2_city_transport", true)
		var body := StaticBody3D.new()
		body.name = "SourceCollision"
		var shape := CollisionShape3D.new()
		shape.name = "NearSurface"
		shape.shape = near_mesh.create_trimesh_shape()
		body.add_child(shape)
		draw.add_child(body)
		seen.append(identity)
	assert(seen.size() == data.parts.size() and seen.size() == far_parts.size())
	low.free()
	return model

static func _with_lod(near_mesh: Mesh, far_mesh: Mesh, error_m: float) -> ArrayMesh:
	var arrays := near_mesh.surface_get_arrays(0)
	var low := far_mesh.surface_get_arrays(0)
	var result := ArrayMesh.new()
	if low[Mesh.ARRAY_INDEX].size() >= arrays[Mesh.ARRAY_INDEX].size():
		# Identical simple roof/rail bodies cannot reduce the index buffer. Keep
		# their authored near body without importer-generated simplifications.
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return result
	var offset: int = arrays[Mesh.ARRAY_VERTEX].size()
	# Source exports carry precisely these physical attributes. Append both sets
	# once; each index buffer addresses a complete replacement body.
	for channel: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV]:
		assert(arrays[channel] != null and low[channel] != null)
		var values: Variant = arrays[channel]
		values.append_array(low[channel])
		arrays[channel] = values
	var indices: PackedInt32Array = low[Mesh.ARRAY_INDEX].duplicate()
	for index in indices.size(): indices[index] += offset
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {error_m: indices})
	return result
