extends Node
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _ready() -> void:
	var source_box := BoxMesh.new(); source_box.size=Vector3(7,.2,5)
	var mapped := preload("res://scripts/building/v2_metre_box_uv.gd").chart(source_box)
	var original_arrays := source_box.surface_get_arrays(0)
	var mapped_arrays := mapped.surface_get_arrays(0)
	for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_INDEX]:
		check(original_arrays[field]==mapped_arrays[field],"metre charts preserve geometry field "+str(field))
	var points: PackedVector3Array=mapped_arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=mapped_arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array=mapped_arrays[Mesh.ARRAY_INDEX]
	for start in range(0,indices.size(),3):
		var i:=indices[start];var j:=indices[start+1];var k:=indices[start+2]
		var area3d:float=(points[j]-points[i]).cross(points[k]-points[i]).length()
		var area_uv:float=absf((uv[j]-uv[i]).cross(uv[k]-uv[i]))
		check(absf(area3d-area_uv)<.00001,"all six box faces retain physical metre chart area")
	var shared := MatLib.get_mat("metal") as StandardMaterial3D
	var original_uv1 := shared.uv1_triplanar
	var original_uv2 := shared.uv2_triplanar
	var original_color := shared.albedo_color
	var world := Node3D.new(); add_child(world)
	var draw := MeshInstance3D.new(); draw.mesh = BoxMesh.new()
	draw.material_override = shared; world.add_child(draw)
	var policy := preload("res://scripts/building/orison_v2_uv_material_policy.gd").new()
	world.add_child(policy); policy.setup(world)
	check(draw.get_active_material(0) == shared and not shared.uv1_triplanar,
		"UV application retains the live material identity")
	shared.albedo_color = Color(.2,.4,.6)
	check(draw.get_active_material(0).albedo_color == shared.albedo_color,
		"existing live material controls still update the visible draw")
	shared.albedo_color = original_color
	var late_stock := shared.duplicate() as StandardMaterial3D
	late_stock.uv1_triplanar = true
	var late := MultiMeshInstance3D.new(); world.add_child(late)
	late.multimesh = MultiMesh.new(); late.multimesh.mesh = BoxMesh.new()
	late.material_override = late_stock
	var shader_stock := ShaderMaterial.new()
	shader_stock.shader = preload("res://shaders/orison_surface.gdshader")
	shader_stock.set_shader_parameter("uv_mode",1)
	var shader_draw := MeshInstance3D.new(); world.add_child(shader_draw)
	shader_draw.mesh = BoxMesh.new(); shader_draw.material_override = shader_stock
	var default_stock := ShaderMaterial.new(); default_stock.shader=shader_stock.shader
	var original_mode: Variant=default_stock.get_shader_parameter("uv_mode")
	var default_draw := MeshInstance3D.new(); world.add_child(default_draw)
	default_draw.mesh=BoxMesh.new(); default_draw.material_override=default_stock
	for frame in 3: await get_tree().process_frame
	check(not late_stock.uv1_triplanar,"late streamed multi-mesh material uses authored UVs")
	check(shader_stock.get_shader_parameter("uv_mode") == 0,"late surface shader uses authored UVs")
	check(default_stock.get_shader_parameter("uv_mode") == 0,"implicit shader defaults become observed UV selection")
	var reference: WeakRef = weakref(world)
	world.queue_free()
	for frame in 3: await get_tree().process_frame
	check(reference.get_ref() == null,"UV policy world retires")
	check(shared.uv1_triplanar == original_uv1 and shared.uv2_triplanar == original_uv2,
		"shared catalogue defaults restore for explicit V1 rollback")
	check(late_stock.uv1_triplanar and shader_stock.get_shader_parameter("uv_mode") == 1,
		"late material defaults restore after teardown")
	check(default_stock.get_shader_parameter("uv_mode") == original_mode,
		"implicit shader default restores after teardown")
	print("V2 UV APPLICATION: ", "PASS" if failures.is_empty() else "FAIL", "; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
