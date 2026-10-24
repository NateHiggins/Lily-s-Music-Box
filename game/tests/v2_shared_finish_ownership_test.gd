extends Node3D
## Focused ownership regression: live V1/catalogue owners, two V2 worlds,
## native MultiMesh poses, literal glass and original retired shadow geometry.
var failures: Array[String]=[]
var checks:=0
func _ready() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks+=1;print("FINISH OWNERSHIP CHECK: ",label," = ",ok)
	if not ok:failures.append(label);push_error(label)
func _draw(parent: Node3D,material: Material) -> MeshInstance3D:
	var draw:=MeshInstance3D.new();var box:=BoxMesh.new();box.material=material;draw.mesh=box;parent.add_child(draw);return draw
func _run() -> void:
	var catalogue:=MatLib.get_mat("nickel_plated")
	var before: Array=[catalogue.uv1_triplanar,catalogue.uv2_triplanar,catalogue.uv1_scale,catalogue.albedo_color,catalogue.albedo_texture,catalogue.roughness_texture,catalogue.normal_texture,catalogue.roughness,catalogue.normal_scale,catalogue.cull_mode]
	var outside:=_draw(self,catalogue)
	var first:=Node3D.new();add_child(first)
	var second:=Node3D.new();add_child(second)
	var left:=_draw(first,catalogue);var right:=_draw(second,catalogue)
	var live:=catalogue.duplicate() as StandardMaterial3D
	var live_draw:=_draw(first,live)
	var policy_a:=preload("res://scripts/building/orison_v2_uv_material_policy.gd").new();add_child(policy_a);policy_a.setup(first)
	var policy_b:=preload("res://scripts/building/orison_v2_uv_material_policy.gd").new();add_child(policy_b);policy_b.setup(second)
	var installed_a:=left.get_active_material(0) as StandardMaterial3D
	var installed_b:=right.get_active_material(0) as StandardMaterial3D
	check(MatLib.is_shared_material(catalogue) and not MatLib.is_shared_material(live),"duplicated metadata cannot misidentify a local material as its catalogue owner")
	check(installed_a!=catalogue and installed_b!=catalogue and installed_a!=installed_b and not installed_a.uv1_triplanar and not installed_b.uv1_triplanar,"each V2 world owns native UV delivery without changing the catalogue")
	check(outside.get_active_material(0)==catalogue and catalogue.uv1_triplanar,"an existing outside consumer retains its original resource and projection")
	check(installed_a.albedo_texture==catalogue.albedo_texture and installed_a.roughness_texture==catalogue.roughness_texture and installed_a.normal_texture==catalogue.normal_texture and installed_a.uv1_scale==catalogue.uv1_scale,"native copy retains exact registered maps and physical texture scale")
	check(live_draw.get_active_material(0)==live and not live.uv1_triplanar,"a local live control retains its exact material reference")
	live.emission_enabled=true;live.emission=Color(.2,.5,.1)
	check((live_draw.get_active_material(0) as StandardMaterial3D).emission==live.emission,"live updates still reach the bound material")
	var later:=_draw(first,catalogue)
	for frame in 3:await get_tree().process_frame
	check(later.get_active_material(0)==installed_a,"deferred new-node inspection reuses its world-local catalogue copy")
	# Two material slots require a local mesh slot resource, while the actual
	# MultiMesh transform buffer and all source geometry remain untouched.
	var source:=ArrayMesh.new();var box:=BoxMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0));source.surface_set_material(0,catalogue)
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0));source.surface_set_material(1,MatLib.get_mat("brass"))
	var arrays_before: Array=[source.surface_get_arrays(0),source.surface_get_arrays(1)]
	var batch:=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=source;batch.instance_count=2
	var pose:=Transform3D(Basis(Vector3.UP,.37),Vector3(2,3,4));batch.set_instance_transform(1,pose)
	var draw:=MultiMeshInstance3D.new();draw.multimesh=batch;first.add_child(draw);policy_a.inspect_branch(draw)
	check(draw.multimesh==batch and batch.get_instance_transform(1).is_equal_approx(pose),"multi-surface native adaptation preserves the real MultiMesh owner and nonidentity poses")
	check(batch.mesh!=source and batch.mesh.surface_get_material(0)!=catalogue and source.surface_get_material(0)==catalogue,"multi-surface delivery does not mutate the original mesh material slots")
	check(batch.mesh.surface_get_arrays(0)==arrays_before[0] and batch.mesh.surface_get_arrays(1)==arrays_before[1],"every source vertex, normal, UV, index and other array remains exact")
	var optics:=Node3D.new();add_child(optics)
	var glass:=StandardMaterial3D.new();glass.resource_name="M_glassish";glass.albedo_color=Color(.35,.42,.38,.19);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	glass.roughness_texture=MatLib.get_mat("milk_glass").roughness_texture;glass.normal_texture=MatLib.get_mat("milk_glass").normal_texture;glass.normal_enabled=true
	_draw(optics,glass)
	var finite:=glass.duplicate() as StandardMaterial3D;finite.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;_draw(optics,finite)
	var original_color:=glass.albedo_color;var original_normal:=glass.normal_scale
	preload("res://scripts/building/v2_legacy_material_stock.gd").apply(optics)
	check(glass.albedo_texture==null and finite.albedo_texture==null and glass.albedo_color==original_color and finite.albedo_color==original_color and glass.cull_mode==BaseMaterial3D.CULL_DISABLED and finite.cull_mode==glass.cull_mode,"both literal source glass and its finite plain-alpha copy retain exact clear colour, alpha and culling")
	check(glass.normal_scale==original_normal and glass.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS and finite.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"glass PBR and declared local alpha adaptation remain unchanged")
	policy_a.free();first.free()
	check(not installed_b.uv1_triplanar and catalogue.uv1_triplanar,"one world's teardown cannot revert another world's native UVs")
	var after: Array=[catalogue.uv1_triplanar,catalogue.uv2_triplanar,catalogue.uv1_scale,catalogue.albedo_color,catalogue.albedo_texture,catalogue.roughness_texture,catalogue.normal_texture,catalogue.roughness,catalogue.normal_scale,catalogue.cull_mode]
	check(before==after,"all sampled catalogue properties remain unchanged through setup, live use and teardown")
	policy_b.free();second.free();optics.free();outside.free()
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("ownership.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Focused loaded ownership regression; no shop gameplay/runtime qualification","checks":checks,"failures":failures},"\t"))
	print("FINISH OWNERSHIP: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
