extends Node3D
## Fitted native bedding beneath the registered closed city masses.
const ASSET:=preload("res://assets/props/city_foundations.glb")

func _ready() -> void:
	var model:=ASSET.instantiate() as Node3D;add_child(model)
	var concrete:=MatLib.get_mat("concrete").duplicate() as StandardMaterial3D
	concrete.uv1_triplanar=false
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=concrete
		var body:=StaticBody3D.new();body.name="GroundCollision";draw.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=draw.mesh.create_trimesh_shape();body.add_child(collision)
