extends RefCounted
## Retained F06 slabs -> posts -> beam -> new roof landing.
static func mount(root: Node3D) -> void:
	var model: Node3D = preload("res://assets/props/court_roof_bridge.glb").instantiate()
	model.name = "CourtRoofBridge"
	root.add_child(model)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		draw.material_override = MatLib.get_mat(str(draw.mesh.surface_get_material(0).resource_name))
		draw.create_trimesh_collision()
