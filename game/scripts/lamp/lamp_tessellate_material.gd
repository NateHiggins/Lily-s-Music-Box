extends RefCounted
## Partition existing triangles by their authored region. No vertex, normal,
## UV, custom channel, instance record, or triangle changes position or value.
static func split(source: Mesh, opaque: ShaderMaterial, tissue: ShaderMaterial) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var solid := PackedInt32Array()
	var body := PackedInt32Array()
	for i in range(0,indices.size(),3):
		var wine := true
		for j in 3:
			wine = wine and roundi(colors[indices[i+j]].r*7.0)==DreamFaunaParts.REGION_WINE
		for j in 3:
			if wine: body.append(indices[i+j])
			else: solid.append(indices[i+j])
	var result := ArrayMesh.new()
	var packed := RenderingServer.mesh_get_surface(source.get_rid(),0)
	for selection in [solid,body]:
		var selected := arrays.duplicate()
		selected[Mesh.ARRAY_INDEX] = selection
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,selected,[],{},source.surface_get_format(0))
		# Preserve packed normals/tangents rather than quantizing their decoded
		# values a second time. Buffers have the same format and vertex count;
		# only the separately allocated index buffer differs.
		var surface := result.get_surface_count()-1
		RenderingServer.mesh_surface_update_vertex_region(result.get_rid(),surface,0,packed.vertex_data)
		if not packed.attribute_data.is_empty():
			RenderingServer.mesh_surface_update_attribute_region(result.get_rid(),surface,0,packed.attribute_data)
	result.surface_set_material(0,opaque)
	result.surface_set_material(1,tissue)
	return result
