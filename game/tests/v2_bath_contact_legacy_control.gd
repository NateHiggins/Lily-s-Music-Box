extends "res://tests/toilet_inspection_test.gd"
## Reproduce the legacy suite with original rendered-mesh contacts, locally only.
func review_native_form() -> void:
	var body:=wc.get_node("FixedCastingCollision") as StaticBody3D
	for shape in body.get_children():shape.free()
	for draw: MeshInstance3D in wc.find_child("WaterClosetCasting",true,false).find_children("*","MeshInstance3D",true,false):
		if draw.name in ["WaterSeal","StoredWater"]:continue
		var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();body.add_child(shape);shape.global_transform=draw.global_transform
	await get_tree().physics_frame
	await super.review_native_form()
