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
		collision.shape=_native_shape(draw.mesh);body.add_child(collision)

func _native_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
