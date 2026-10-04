extends RefCounted
## One rolled finish over the fitted falling field. The retained Floor body
## owns the original structural slab and the added native walking envelope.
static func mount(root: Node3D) -> Node3D:
	var model: Node3D=(preload("res://assets/props/roof_membrane.glb") as PackedScene).instantiate()
	model.name="RoofMembrane"
	root.add_child(model)
	var surfaces: Dictionary={}
	var owners: Dictionary={}
	var bare_meshes: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var identity: String=str(draw.name).split("__")[0]
		var finish: String=draw.mesh.surface_get_material(0).resource_name
		if not surfaces.has(finish):
			var material:=MatLib.get_mat("roof_bitumen").duplicate() as StandardMaterial3D
			material.uv1_triplanar=false
			material.vertex_color_use_as_albedo=true
			material.vertex_color_is_srgb=false
			surfaces[finish]=material
		draw.material_override=surfaces[finish]
		draw.set_meta("material_key","roof_bitumen")
		draw.set_meta("floor_owner",identity)
		owners[identity]=true
	for identity: String in owners:
		var floor: MeshInstance3D=root.get_node(identity+"/Floor")
		bare_meshes[identity]=floor.mesh
		floor.mesh=_without_top(floor.mesh)
		floor.set_meta("fitted_roof_finish",model.get_path())
	model.set_meta("bare_roof_meshes",bare_meshes)
	return model

static func _without_top(original: Mesh) -> ArrayMesh:
	var result:=ArrayMesh.new()
	for index in original.get_surface_count():
		var arrays: Array=original.surface_get_arrays(index)
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices:=PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for vertex in normals.size():indices.append(vertex)
		var retained:=PackedInt32Array()
		for triangle in range(0,indices.size(),3):
			if normals[indices[triangle]].y>.9 and normals[indices[triangle+1]].y>.9 and normals[indices[triangle+2]].y>.9:continue
			retained.append(indices[triangle]);retained.append(indices[triangle+1]);retained.append(indices[triangle+2])
		if retained.is_empty():continue
		arrays[Mesh.ARRAY_INDEX]=retained
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,original.surface_get_material(index))
	return result
