extends RefCounted
## Static fabricated connections only; BoilerProp and HeatBalance keep state.
static func mount(root: Node3D) -> void:
	var model := (preload("res://assets/props/boiler_pipework.glb") as PackedScene).instantiate() as Node3D
	model.name="BoilerPipework"
	root.add_child(model)
	var inlet := (preload("res://assets/props/boiler_inlet.glb") as PackedScene).instantiate() as Node3D
	inlet.name="InletSleeves"
	model.add_child(inlet)
	for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		part.material_override=MatLib.get_mat("cast_iron" if str(part.name)=="Iron" else "metal")
		var body := StaticBody3D.new()
		body.name=str(part.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*part.global_transform
		var collision := CollisionShape3D.new()
		collision.shape=part.mesh.create_trimesh_shape()
		body.add_child(collision)
		model.add_child(body)
