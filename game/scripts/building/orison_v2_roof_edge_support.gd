extends RefCounted
## Fixed slab-edge bearing course; retained roof plant and guards own behavior.
static func mount(root: Node3D) -> void:
	var model: Node3D=(preload("res://assets/props/roof_edge_support.glb") as PackedScene).instantiate()
	model.name="RoofEdgeSupport"
	root.add_child(model)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=MatLib.get_mat("concrete")
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape()
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		body.add_child(shape);model.add_child(body)
