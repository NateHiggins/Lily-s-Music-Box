extends MultiMeshInstance3D
## St. Elmo's fire on the tips of stacks and water tanks while a high-charge
## storm is overhead. One instanced draw per owner; hidden (no draw) at zero.
## WeatherManager drives every corona through the "st_elmo_corona" group.

func _init(tips := PackedVector3Array(), size := 1.0) -> void:
	name = "StElmoCorona"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = tips.size()
	for index in tips.size():
		multimesh.set_instance_transform(index, Transform3D(Basis(), tips[index]))
		multimesh.set_instance_custom_data(index, Color(size, float(index) * .618, 0.0, 0.0))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/v2_st_elmo_corona.gdshader")
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = size * 2.0
	set_meta("surface_role", "electric_corona")
	visible = false
	add_to_group("st_elmo_corona")


func set_corona(level: float) -> void:
	visible = level > .01
	(material_override as ShaderMaterial).set_shader_parameter("corona", level)


## The highest points of a mesh (its cap top), as one tip in the parent's frame.
static func crown_of(draw: MeshInstance3D, frame: Node3D) -> Vector3:
	var vertices: PackedVector3Array = draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top := -INF
	for vertex in vertices: top = maxf(top, vertex.y)
	var sum := Vector3.ZERO
	var count := 0
	for vertex in vertices:
		if vertex.y > top - .02:
			sum += vertex
			count += 1
	# Walk the local transforms up to the frame: valid before entering the tree.
	var relative := Transform3D.IDENTITY
	var node: Node = draw
	while node != null and node != frame:
		if node is Node3D: relative = (node as Node3D).transform * relative
		node = node.get_parent()
	return relative * (sum / maxf(1.0, count))
