extends RefCounted
## Fixed source-thickness caps; the retained ceilings still own interior finish.
static func mount(root: Node3D) -> void:
	var model: Node3D=(preload("res://assets/props/roof_bulkhead_caps.glb") as PackedScene).instantiate()
	model.name="RoofBulkheadCaps"
	root.add_child(model)
	var thickness: float=root.layout.dimensions.slab_thickness
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=MatLib.get_mat("concrete")
		# Each bounded top rectangle has one full-depth solid body. Original
		# ceilings have no body, and adjacent pieces share only zero-area edges.
		var bounds:=draw.mesh.get_aabb()
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		var shape_node:=CollisionShape3D.new();var shape:=BoxShape3D.new()
		shape.size=Vector3(bounds.size.x,thickness,bounds.size.z)
		shape_node.shape=shape
		shape_node.position=Vector3(bounds.get_center().x,bounds.end.y-thickness*.5,bounds.get_center().z)
		body.add_child(shape_node);model.add_child(body)
