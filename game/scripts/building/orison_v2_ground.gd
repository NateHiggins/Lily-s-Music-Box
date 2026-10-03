extends Node3D
## Bounded subgrade and retained-datum court surface in the registered V2 frame.
const ASSET:=preload("res://assets/props/orison_ground.glb")

func _ready() -> void:
	var model:=ASSET.instantiate() as Node3D
	add_child(model)
	var asphalt:=MatLib.get_mat("asphalt").duplicate() as StandardMaterial3D
	var soil:=MatLib.get_mat("soil").duplicate() as StandardMaterial3D
	asphalt.uv1_triplanar=false;soil.uv1_triplanar=false
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=asphalt if str(draw.name).contains("asphalt") else soil
		var body:=StaticBody3D.new();body.name="GroundCollision";draw.add_child(body)
		var collision:=CollisionShape3D.new()
		collision.shape=draw.mesh.create_trimesh_shape();body.add_child(collision)
