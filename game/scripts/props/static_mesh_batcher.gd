class_name StaticMeshBatcher
extends RefCounted
## Draw-call batching for primitive-built Node3D props.  This deliberately
## lives outside FunctionalProp: architectural actors such as doors and the
## mail bank need batching without being enrolled in the building's signal,
## possession and infection systems.


static func merge(under: Node3D, keep: Array = []) -> int:
	var groups := {}
	var victims: Array = []
	_gather(under, under, groups, victims, keep)
	if victims.size() < 2:
		return 0
	for victim in victims:
		var owner_node: Node = victim.get_parent()
		if owner_node:
			owner_node.remove_child(victim)
		victim.queue_free()
	for key in groups:
		var merged := MeshInstance3D.new()
		merged.mesh = groups[key].tool.commit()
		merged.material_override = groups[key].material
		merged.cast_shadow = groups[key].shadow
		under.add_child(merged)
	return victims.size() - groups.size()


static func _gather(node: Node3D, root: Node3D, groups: Dictionary,
		victims: Array, keep: Array) -> void:
	for child in node.get_children():
		if child in keep or not child is Node3D:
			continue
		if child is MeshInstance3D and child.mesh != null \
				and child.material_override is StandardMaterial3D:
			var material: StandardMaterial3D = child.material_override
			var key := _material_key(material)
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"material": material, "tool": tool,
						"shadow": child.cast_shadow}
			var xf := _relative_xform(child, root)
			for surface in child.mesh.get_surface_count():
				groups[key].tool.append_from(child.mesh, surface, xf)
			victims.append(child)
		else:
			_gather(child, root, groups, victims, keep)


static func _relative_xform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cursor: Node3D = node
	while cursor != null and cursor != root:
		xf = cursor.transform * xf
		cursor = cursor.get_parent() as Node3D
	return xf


static func _material_key(material: StandardMaterial3D) -> String:
	return "%s|%.3f|%.3f|%s|%s|%s|%s" % [
		material.albedo_color, material.roughness, material.metallic,
		material.albedo_texture.get_rid() if material.albedo_texture else "-",
		material.normal_texture.get_rid() if material.normal_texture else "-",
		material.uv1_scale, material.transparency]
