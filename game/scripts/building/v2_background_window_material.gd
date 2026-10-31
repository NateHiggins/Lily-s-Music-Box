extends RefCounted
## Private optical material factory. Never mutates catalogue stock or native meshes.
## Caller supplies normalized pane UV2 (top-left origin); UV0 remains metric PBR.
## Apply only to opaque, noninteractive background panes, not real inhabited rooms.
const InteriorShader = preload("res://shaders/v2_background_window_interior.gdshader")

static func kind_for(typology: String) -> int:
	if typology == "factory": return 2
	if typology == "commercial": return 1
	return 0

static func neighbour_kind(identity: String) -> int:
	# Optical uses informed by the existing source-card adaptations, not new NPCs.
	if identity in ["site_nw3", "site_ne1", "site_ne3", "site_sw3"]: return 2
	if identity in ["site_nw1", "site_ne2", "site_ne4", "site_se2", "site_se3"]: return 1
	return 0

static func glazing_is_bound(draw: MeshInstance3D) -> bool:
	var optical := draw.material_override as ShaderMaterial
	var source := draw.get_meta("v2_window_source_material", null) as StandardMaterial3D
	if optical == null or source == null or optical.shader != InteriorShader: return false
	return optical.get_shader_parameter("glass_albedo") == source.albedo_texture \
		and optical.get_shader_parameter("glass_roughness") == source.roughness_texture \
		and optical.get_shader_parameter("glass_normal") == source.normal_texture \
		and optical.get_shader_parameter("physical_uv_scale") == Vector2(source.uv1_scale.x, source.uv1_scale.y)

static func create(identity: String, kind: int, size_metres: Vector2) -> ShaderMaterial:
	assert(kind >= 0 and kind <= 3 and size_metres.x > 0.0 and size_metres.y > 0.0)
	var glass: StandardMaterial3D = MatLib.get_mat("mirror_aged")
	var wall: StandardMaterial3D = MatLib.get_mat("limewash_plaster")
	var wood: StandardMaterial3D = MatLib.get_mat("wood_dark")
	var material := ShaderMaterial.new()
	material.shader = InteriorShader
	material.set_shader_parameter("glass_albedo", glass.albedo_texture)
	material.set_shader_parameter("glass_roughness", glass.roughness_texture)
	material.set_shader_parameter("glass_normal", glass.normal_texture)
	material.set_shader_parameter("wall_albedo", wall.albedo_texture)
	material.set_shader_parameter("wood_albedo", wood.albedo_texture)
	material.set_shader_parameter("physical_uv_scale", Vector2(glass.uv1_scale.x, glass.uv1_scale.y))
	material.set_shader_parameter("building_seed", float(identity.hash() & 0xffff))
	material.set_shader_parameter("room_kind", kind)
	material.set_shader_parameter("pane_size", size_metres)
	return material

static func sync_clock(material: ShaderMaterial, clock: CampaignClock) -> bool:
	var day := clock.day_info()
	if not bool(day.get("valid", false)):
		return false # Keep last valid presentation; never invent a date.
	material.set_shader_parameter("minute_of_day", clock.minute_of_day())
	material.set_shader_parameter("weekend", str(day.day) in ["sat", "sun"])
	return true

## Private optical attributes only; original physical arrays and LODs are kept.
static func project(source: Mesh, building_identity := "") -> ArrayMesh:
	var result := ArrayMesh.new()
	var pane_count := 0
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var raw: Dictionary = RenderingServer.mesh_get_surface(source.get_rid(), surface)
		var lods := {}
		var all_indices := indices.duplicate()
		var stride := RenderingServer.mesh_surface_get_format_index_stride(int(raw.format), positions.size())
		for lod: Dictionary in raw.get("lods", []):
			var bytes: PackedByteArray = lod.index_data
			var list := PackedInt32Array()
			list.resize(bytes.size() / stride)
			for i in list.size():
				list[i] = bytes.decode_u16(i * stride) if stride == 2 else bytes.decode_u32(i * stride)
			lods[float(lod.edge_length)] = list
			all_indices.append_array(list)
		# Connected coplanar faces, welded across UV seams for optical charts.
		var parents := PackedInt32Array()
		parents.resize(positions.size())
		var weld := {}
		for i in positions.size():
			parents[i] = i
			var key := str(Vector3i((positions[i] * 10000.0).round())) + ":" + str(Vector3i((normals[i] * 1000.0).round()))
			if weld.has(key): parents[i] = int(weld[key])
			else: weld[key] = i
		for offset in range(0, all_indices.size(), 3):
			var a := _root(parents, all_indices[offset])
			for corner in [1, 2]:
				var b := _root(parents, all_indices[offset + corner])
				if normals[a].dot(normals[b]) > 0.999: parents[b] = a
		var groups := {}
		for i in positions.size():
			var root := _root(parents, i)
			if not groups.has(root): groups[root] = []
			groups[root].append(i)
		var uv := PackedVector2Array()
		uv.resize(positions.size())
		uv.fill(Vector2(0, -2))
		var custom := PackedFloat32Array()
		custom.resize(positions.size() * 4)
		for root: int in groups:
			var normal := normals[root].normalized()
			var right := Vector3.UP.cross(normal)
			if right.length_squared() < 0.001: right = Vector3.RIGHT
			right = right.normalized()
			var up := normal.cross(right).normalized()
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for i: int in groups[root]:
				var p := Vector2(positions[i].dot(right), positions[i].dot(up))
				lo = lo.min(p); hi = hi.max(p)
			var size := hi - lo
			if size.x < 0.2 or size.y < 0.3: continue
			var centre := (lo + hi) * 0.5
			var identity := float((building_identity + str(centre.snapped(Vector2(0.001, 0.001))) + str(normal.snapped(Vector3.ONE * 0.001)) + str(snappedf(normal.dot(positions[root]), 0.001))).hash() & 0xffff)
			for i: int in groups[root]:
				var p := (Vector2(positions[i].dot(right), positions[i].dot(up)) - lo) / size
				uv[i] = Vector2(p.x, 1.0 - p.y)
				custom[i * 4] = identity
				custom[i * 4 + 1] = size.x
				custom[i * 4 + 2] = size.y
				custom[i * 4 + 3] = 1.0
			pane_count += 1
		arrays[Mesh.ARRAY_TEX_UV2] = uv
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], lods,
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		result.surface_set_material(surface, source.surface_get_material(surface))
	result.set_meta("optical_faces", pane_count)
	if source is ArrayMesh:
		result.shadow_mesh = source.shadow_mesh
	return result

static func _root(parents: PackedInt32Array, index: int) -> int:
	var at := index
	while parents[at] != at: at = parents[at]
	return at
