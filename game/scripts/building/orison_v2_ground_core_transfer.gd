extends RefCounted
## Native fitted frame beneath the shifted ground core; source floors stay authoritative.
const STEEL_TINT:=Color(.32,.34,.36)

static func mount(root: Node3D) -> void:
	var model: Node3D=(preload("res://assets/props/ground_core_transfer.glb") as PackedScene).instantiate()
	model.name="GroundCoreTransfer";root.add_child(model)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=MatLib.get_mat("metal",STEEL_TINT) if str(draw.name).begins_with("Steel") else MatLib.get_mat("concrete")
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);model.add_child(body)
