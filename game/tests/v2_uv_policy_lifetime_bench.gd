extends Node
## INERT restoration ownership and bounded ledger controls.
const Policy := preload("res://scripts/building/orison_v2_uv_material_policy.gd")
var checks: Array=[]

func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label});print("UV LIFETIME: ",label," = ",ok)

func local_shader_refs(policy: Node) -> Array:
	var texture:=ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	var material:=ShaderMaterial.new();material.shader=preload("res://shaders/orison_surface.gdshader")
	material.set_shader_parameter("uv_mode",1);material.set_shader_parameter("albedo_tex",texture)
	policy._apply(material)
	return [weakref(material),weakref(texture)]

func alive(reference: WeakRef) -> bool:
	# Keep the reference getter's temporary inside this frame only.
	return reference.get_ref()!=null

func temporary_materials(policy: Node) -> void:
	for index in 512:
		var material:=StandardMaterial3D.new();material.uv1_triplanar=true
		policy._apply(material)

func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	var path:=OS.get_environment("V2_ORIGINAL_UV_POLICY")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=OS.get_environment("V2_ORIGINAL_UV_POLICY_SHA"):
		check(false,"frozen original policy hash");finish();return
	var original: Script=load(path)
	if original==null:check(false,"frozen original policy compiles");finish();return
	var old_world:=Node3D.new();add_child(old_world)
	var old_policy: Node=original.new();old_world.add_child(old_policy);old_policy.setup(old_world)
	var old_refs:=local_shader_refs(old_policy)
	check(alive(old_refs[0]) and alive(old_refs[1]),"frozen original ledger retains a retired shader and texture")
	old_world.free()
	check(not alive(old_refs[0]) and not alive(old_refs[1]),"original retention ends when the entire policy world exits")
	var world:=Node3D.new();add_child(world)
	var policy:=Policy.new();world.add_child(policy);policy.setup(world)
	var shared:=StandardMaterial3D.new();shared.uv1_triplanar=true;shared.uv2_triplanar=true
	var original_color:=shared.albedo_color
	policy._apply(shared)
	check(not shared.uv1_triplanar and not shared.uv2_triplanar,"same live shared material receives authored-UV selection")
	shared.albedo_color=Color(.2,.4,.6)
	check(shared.albedo_color!=original_color,"live material state remains mutable through the same reference")
	var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/orison_surface.gdshader");shader.set_shader_parameter("uv_mode",1)
	var implicit:=ShaderMaterial.new();implicit.shader=shader.shader
	var original_mode: Variant=implicit.get_shader_parameter("uv_mode")
	policy._apply(shader);policy._apply(implicit)
	check(shader.get_shader_parameter("uv_mode")==0 and implicit.get_shader_parameter("uv_mode")==0,"explicit and implicit surface shader modes remain corrected")
	var references:=local_shader_refs(policy)
	check(not alive(references[0]) and not alive(references[1]),"weak restoration records release retired local shader and texture")
	temporary_materials(policy)
	check(policy.changed_materials.size()<=35,"bounded incremental pruning reclaims dead restoration records")
	check(policy.changed_materials.has(shared.get_instance_id()) and policy.changed_materials.has(shader.get_instance_id()) and policy.changed_materials.has(implicit.get_instance_id()),"pruning preserves every live restoration record")
	world.free()
	check(shared.uv1_triplanar and shared.uv2_triplanar,"shared catalogue projection defaults restore on world exit")
	check(shared.albedo_color==Color(.2,.4,.6),"teardown preserves live color state")
	check(shader.get_shader_parameter("uv_mode")==1 and implicit.get_shader_parameter("uv_mode")==original_mode,"explicit and implicit shader defaults restore exactly")
	finish()

func finish() -> void:
	var ok: bool=checks.all(func(row):return row.ok)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks},"\t"))
	print("UV POLICY LIFETIME: ","PASS" if ok else "FAIL"," checks=",checks.size());get_tree().quit(0 if ok else 1)
