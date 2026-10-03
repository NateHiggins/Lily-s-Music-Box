extends RefCounted
## Complete only uncovered ceiling upper volumes; retained undersides stay put.
static func mount(root: Node3D) -> void:
	var model: Node3D=(preload("res://assets/props/ceiling_top_closures.glb") as PackedScene).instantiate()
	model.name="CeilingTopClosures"
	root.add_child(model)
	var depth: float=root.layout.dimensions.slab_thickness
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=MatLib.get_mat("concrete")
		# Every piece has a rectangular, port-free footprint. Its native sides
		# omit buried interfaces; the source-depth body completes its volume.
		var bounds:=draw.mesh.get_aabb()
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		var shape_node:=CollisionShape3D.new();var shape:=BoxShape3D.new()
		shape.size=Vector3(bounds.size.x,depth,bounds.size.z);shape_node.shape=shape
		shape_node.position=Vector3(bounds.get_center().x,bounds.end.y-depth*.5,bounds.get_center().z)
		body.add_child(shape_node);model.add_child(body)
