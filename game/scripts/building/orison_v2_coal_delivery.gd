extends Node3D
## Closed pavement cover and gravity chute; the existing boiler owns firing.
const Model := preload("res://assets/building/v2_coal_delivery.glb")

func _ready() -> void:
	var model := Model.instantiate()
	add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(index)
			if material != null and MatLib.SETS.has(material.resource_name):
				mesh.set_surface_override_material(index, MatLib.get_mat(material.resource_name))
		mesh.create_trimesh_collision()
