extends RefCounted
## Registered authored aerial geometry, with fitted roof anchors and one
## static physical owner per bounded draw. City actors and services stay owned.
static func mount(city: Node3D) -> Node3D:
	var model: Node3D=(preload("res://assets/props/city_masts.glb") as PackedScene).instantiate()
	model.name="RooftopMasts";city.add_child(model)
	var material:=MatLib.get_mat("galvanized_roof").duplicate() as StandardMaterial3D
	material.uv1_triplanar=false
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=material
		var body:=StaticBody3D.new();body.name="MastCollision"
		var shape:=CollisionShape3D.new();shape.name="Surface";shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);draw.add_child(body)
	return model
