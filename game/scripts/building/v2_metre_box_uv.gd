extends RefCounted
## Chart source-owned planar architectural boxes in metres. Position, topology,
## normals, tangent handedness, surface materials and collision stay unchanged.
static func chart(mesh: Mesh, origin: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		assert(normals.size()==points.size() and tangents.size()==points.size()*4)
		var uv := PackedVector2Array(); uv.resize(points.size())
		for i in points.size():
			var u := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			var v := normals[i].cross(u)*tangents[i*4+3]
			# Local origin remains the default for thin reveals. Wet-room stock
			# opts into a common installation phase to align separate grout courses.
			uv[i] = Vector2(points[i].dot(u),points[i].dot(v)) + Vector2(origin.dot(u),origin.dot(v))
		arrays[Mesh.ARRAY_TEX_UV] = uv
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(surface,mesh.surface_get_material(surface))
	return result
