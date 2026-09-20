extends Node
func _ready() -> void:
	var source := DreamFaunaParts.tessellates()
	var opaque := ShaderMaterial.new()
	var tissue := ShaderMaterial.new()
	var result := preload("res://scripts/lamp/lamp_tessellate_material.gd").split(source,opaque,tissue)
	var original := source.surface_get_arrays(0)
	var ok := result.get_surface_count()==2
	var triangles := {}
	var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
	# The authored producer submits non-indexed triangles. Each triangle must
	# appear in exactly one partition, with the same ordered vertex addresses.
	ok = ok and original[Mesh.ARRAY_INDEX]==null
	for surface in 2:
		var arrays := result.surface_get_arrays(surface)
		for slot in Mesh.ARRAY_MAX:
			if slot!=Mesh.ARRAY_INDEX:
				if arrays[slot]!=original[slot]: print("MISMATCH surface=",surface," slot=",slot)
				ok = ok and arrays[slot]==original[slot]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0,indices.size(),3):
			ok = ok and indices[i]%3==0 and indices[i+1]==indices[i]+1 and indices[i+2]==indices[i]+2 and not triangles.has(indices[i])
			triangles[indices[i]] = true
	ok = ok and triangles.size()*3==vertices.size()
	ok = ok and result.surface_get_material(0)==opaque and result.surface_get_material(1)==tissue
	if not ok: push_error("Tessellate partition changed authored geometry or duplicated/lost a triangle")
	print("TESSELLATE EXACT PARTITION: ","PASS" if ok else "FAIL", "; triangles=",triangles.size())
	get_tree().quit(0 if ok else 1)
