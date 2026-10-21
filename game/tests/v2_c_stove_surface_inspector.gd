extends Node
## Measures actual installed stock; declarations alone grant no surface proof.
const Stock=preload("res://scripts/building/c_stove_stack_stock.gd")
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
var checks: Array[Dictionary]=[]
var failures:=0
func _check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok:failures+=1

func inspect(stock: Node3D) -> Dictionary:
	var metrics: Node=Metrics.new();var textures: Dictionary={};var parts:=0;var triangles:=0
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json")).materials
	for draw: MeshInstance3D in stock.find_children("*","MeshInstance3D",true,false):
		parts+=1;var key:=str(draw.name);var material:=draw.material_override as StandardMaterial3D
		_check(Stock.STRENGTHS.has(key) and material!=null,"installed native finish: "+key)
		if not Stock.STRENGTHS.has(key) or material==null:continue
		_check(material.get_meta("v2_surface_stock","")==key and not material.uv1_triplanar and not material.uv2_triplanar and material.uv1_scale==Vector3.ONE,"authored calibrated texture chart: "+key)
		_check(material.normal_enabled and is_equal_approx(material.normal_scale,float(Stock.STRENGTHS[key])) and material.vertex_color_use_as_albedo,"actual normal and exposure-colour recipe: "+key)
		_check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"actual anisotropic mip filtering: "+key)
		var copy:=ArrayMesh.new()
		for surface in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface);var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for index in uv.size():uv[index]*=float(catalog[key].meters_per_tile)
			arrays[Mesh.ARRAY_TEX_UV]=uv;copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];triangles+=indices.size()/3
		metrics._check_cap_mapping(copy,true)
		for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
			_check(texture!=null,"custom physical map loaded: "+key)
			if texture==null or textures.has(texture.resource_path):continue
			var image:=texture.get_image();var expected:=int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.))) if image!=null else -1
			var valid: bool=image!=null and image.has_mipmaps() and image.get_mipmap_count()==expected
			_check(valid,"actual complete loaded mip chain: "+texture.resource_path)
			textures[texture.resource_path]={"mips":valid,"levels":image.get_mipmap_count() if image!=null else -1,"width":image.get_width() if image!=null else 0,"height":image.get_height() if image!=null else 0}
	for failure: String in metrics.failures:_check(false,failure)
	_check(parts==4 and textures.size()==12,"four installed native batches and twelve loaded physical maps")
	var report: Dictionary={"scope":"Actual installed C-stack surfaces only; no global or human appearance acceptance.","parts":parts,"triangles":triangles,"textures":textures,"checks":checks,"metric_checks":metrics.batch_checks,"failures":failures}
	metrics.free();return report
