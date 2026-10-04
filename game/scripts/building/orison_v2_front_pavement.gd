extends Node3D
## Public slab fitted to retained room, shop, shed, curb and masonry owners.
## Mounted in the named front-door building frame; top datum remains zero.
const ASSET:=preload("res://assets/props/front_pavement.glb")

func _ready() -> void:
	var model:=ASSET.instantiate() as Node3D
	add_child(model)
	var material:=MatLib.get_mat("concrete").duplicate() as StandardMaterial3D
	material.uv1_triplanar=false
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=material
		var body:=StaticBody3D.new()
		body.name="PavementCollision"
		draw.add_child(body)
		var collision:=CollisionShape3D.new()
		collision.shape=_native_shape(draw.mesh)
		body.add_child(collision)

func _native_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
