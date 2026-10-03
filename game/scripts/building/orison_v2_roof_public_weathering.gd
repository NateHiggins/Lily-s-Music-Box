extends RefCounted
## Source-fitted public-roof weather fit; original gameplay remains production-owned.
static func mount(root: Node3D) -> Node3D:
	var model: Node3D=(preload("res://assets/props/roof_public_weathering.glb") as PackedScene).instantiate()
	model.name="RoofPublicWeathering";root.add_child(model)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key: String=draw.mesh.surface_get_material(0).resource_name
		assert(MatLib.SETS.has(key),"Unknown public roof weather material: "+key)
		draw.set_meta("material_key",key);draw.material_override=MatLib.get_mat(key)
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);model.add_child(body)
	return model
