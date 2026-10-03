extends RefCounted
## Native foundation union; occupied basement and service volumes stay open.
static func mount(root: Node3D) -> void:
	var model: Node3D=(preload("res://assets/props/orison_foundations.glb") as PackedScene).instantiate()
	model.name="Foundations"
	root.add_child(model)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=MatLib.get_mat("concrete")
		# Bounds span exclusions and step changes. The exact exported union
		# owns collision; an AABB solid would fill retained voids.
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		var shape_node:=CollisionShape3D.new()
		shape_node.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape_node);model.add_child(body)
