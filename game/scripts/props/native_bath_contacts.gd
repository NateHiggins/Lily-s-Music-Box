extends RefCounted
## Fixed contact stock authored from the Blender owners, with <=2 mm sampled
## deviation. Visuals, hollow openings and movable mechanism owners stay separate.
static var _cache: Dictionary={}

static func _gather(node: Node,parent_transform: Transform3D,output: Array) -> void:
	var local:=parent_transform
	if node is Node3D:local*=node.transform
	if node is MeshInstance3D and node.mesh!=null:
		output.append({"shape":node.mesh.create_trimesh_shape(),"transform":local,"name":str(node.name)})
	for child in node.get_children():_gather(child,local,output)

static func install(body: StaticBody3D,frame: Node3D,family: String) -> bool:
	if family not in ["bath_lavatory","bath_water_closet"]:return false
	if not _cache.has(family):
		var source:=load("res://assets/props/"+family+"_contact.glb") as PackedScene
		if source==null:return false
		var model:=source.instantiate();var definitions: Array=[]
		_gather(model,Transform3D.IDENTITY,definitions);model.free()
		if definitions.is_empty():return false
		_cache[family]=definitions
	var relative:=body.global_transform.affine_inverse()*frame.global_transform
	for definition: Dictionary in _cache[family]:
		var collision:=CollisionShape3D.new();collision.name=definition.name
		collision.shape=definition.shape;collision.transform=relative*definition.transform;body.add_child(collision)
	body.set_meta("native_contact_family",family)
	return true
