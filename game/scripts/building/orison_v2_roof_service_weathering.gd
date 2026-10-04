extends RefCounted
## Fixed roof cover and drainage fittings; retained cap and deck own their floors.
static func mount(root: Node3D) -> Node3D:
	var model: Node3D=(preload("res://assets/props/roof_service_weathering.glb") as PackedScene).instantiate()
	model.name="RoofServiceWeathering";root.add_child(model)
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_service_weathering.json"))
	var keys: Dictionary={}
	for part: Dictionary in fixture.runtime_parts:keys[str(part.name)]=str(part.material)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key: String=str(keys.get(str(draw.name),"missing"))
		assert(MatLib.SETS.has(key),"Unknown roof weather material: "+key)
		draw.set_meta("material_key",key)
		var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false;draw.material_override=material
		var body:=StaticBody3D.new();body.name=str(draw.name)+"Collision"
		body.transform=model.global_transform.affine_inverse()*draw.global_transform
		var shape:=CollisionShape3D.new();shape.shape=_shape(draw.mesh)
		body.add_child(shape);model.add_child(body)
	return model

static func _shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
