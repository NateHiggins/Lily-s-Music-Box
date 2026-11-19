extends RefCounted
## Rechart the electrical spans after stretching the authored one-metre stock.

static func length_mesh(source: ArrayMesh, length: float) -> ArrayMesh:
	assert(length > 0.0)
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var source_points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in source_points.size():
			source_points[index].y *= length
			var normal := source_normals[index]
			source_normals[index] = Vector3(normal.x, normal.y / length, normal.z).normalized()

		# Use independent corners because each triangle has its own metre chart.
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var tangents := PackedFloat32Array()
		var indices := PackedInt32Array()
		var count := source_points.size() if source_indices.is_empty() else source_indices.size()
		for corner in count:
			indices.append(corner)
			var source_index := source_indices[corner] if not source_indices.is_empty() else corner
			points.append(source_points[source_index])
			normals.append(source_normals[source_index])
		uv.resize(count)
		tangents.resize(count * 4)
		for first in range(0, count, 3):
			var a := points[first]
			var ab := points[first + 1] - a
			var ac := points[first + 2] - a
			var bc := points[first + 2] - points[first + 1]
			var axis := ab if ab.length_squared() >= ac.length_squared() else ac
			if bc.length_squared() > axis.length_squared():
				axis = bc
			var u := axis.normalized()
			var v := u.cross(ab.cross(ac).normalized())
			for corner in range(first, first + 3):
				var offset := points[corner] - a
				var normal := normals[corner]
				var tangent := (u - normal * normal.dot(u)).normalized()
				var base := corner * 4
				uv[corner] = Vector2(offset.dot(u), offset.dot(v))
				tangents[base] = tangent.x
				tangents[base + 1] = tangent.y
				tangents[base + 2] = tangent.z
				tangents[base + 3] = -1.0 if normal.cross(tangent).dot(v) < 0.0 else 1.0

		var charted: Array = []
		charted.resize(Mesh.ARRAY_MAX)
		charted[Mesh.ARRAY_VERTEX] = points
		charted[Mesh.ARRAY_NORMAL] = normals
		charted[Mesh.ARRAY_TEX_UV] = uv
		charted[Mesh.ARRAY_TANGENT] = tangents
		charted[Mesh.ARRAY_INDEX] = indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, charted)
		result.surface_set_material(surface, source.surface_get_material(surface))
	return result
