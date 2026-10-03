extends RefCounted
## Fabricated outer leaf; room-side walls and semantic apertures retain ownership.
static func mount(root: Node3D) -> void:
	var model := (preload("res://assets/props/exterior_masonry.glb") as PackedScene).instantiate() as Node3D
	model.name="ExteriorMasonry"
	root.add_child(model)
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface)
			var tint := Color.WHITE if original.resource_name=="FaceBrick" else Color(.78,.72,.66)
			mesh.set_surface_override_material(surface,MatLib.get_mat("brick",tint))
		var body := StaticBody3D.new()
		body.name="MasonryCollision"
		var shape := CollisionShape3D.new()
		shape.shape=mesh.mesh.create_trimesh_shape()
		shape.transform=mesh.transform
		body.add_child(shape)
		model.add_child(body)
