extends RefCounted
static func read(mesh: Mesh) -> PackedVector3Array:
	# Mesh.get_faces() uses its snapped triangle-mesh cache. Read the imported
	# position/index arrays to preserve actual thin sheet and joint coordinates.
	var result:=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays: Array=mesh.surface_get_arrays(surface);var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_INDEX]==null or (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():result.append_array(positions)
		else:
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index: int in indices:result.append(positions[index])
	return result
