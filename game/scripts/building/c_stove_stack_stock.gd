extends RefCounted
## Native stock construction only. Caller owns layout, apertures and placement.
const ASSET=preload("res://assets/props/c_stove_stack.glb")
const STRENGTHS={"stove_clinker":1.0,"stove_lime":1.0,"limewash_plaster":1.0,"concrete":.12}

static func build() -> Node3D:
	var stock: Node3D=ASSET.instantiate()
	stock.name="CStoveStackStock"
	for draw: MeshInstance3D in stock.find_children("*","MeshInstance3D",true,false):
		var key:=str(draw.name)
		assert(STRENGTHS.has(key),"Unknown C-stack fabrication batch: "+key)
		var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false;material.uv2_triplanar=false;material.uv1_scale=Vector3.ONE
		material.normal_enabled=true;material.normal_scale=float(STRENGTHS[key]);material.vertex_color_use_as_albedo=true
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.set_meta("v2_surface_stock",key);draw.set_meta("v2_material_key",key);draw.material_override=material
		var body:=StaticBody3D.new();body.name="NativeContact"
		var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();body.add_child(shape);draw.add_child(body)
	return stock
