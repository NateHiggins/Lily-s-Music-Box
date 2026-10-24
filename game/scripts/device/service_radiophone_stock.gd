extends RefCounted
## Bind the native material-name ABI to the registered catalogue once at mount.
const DATA := "res://data/device/service_radiophone_v2.json"

static func apply(model: Node3D) -> Dictionary:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(int(data.schema_version)==1)
	assert(FileAccess.get_sha256(str(data.asset))==str(data.asset_sha256),"native handheld export drift")
	var finishes: Dictionary={}
	var names: Array[String]=["Case","Brass","Steel","Paper","Rubber","Leather","Porcelain","Lens","TypeEmboss"]
	assert(data.finishes.size()==names.size(),"native finish ABI")
	for name: String in names:
		var spec: Dictionary=data.finishes[name]
		var material:=MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
		assert(material.albedo_texture!=null and material.normal_texture!=null and material.roughness_texture!=null,"native handheld PBR")
		material.uv1_triplanar=false;material.uv1_world_triplanar=false
		material.uv1_scale=Vector3.ONE/float(MatLib.SETS[str(spec.catalog_key)][3])
		material.normal_enabled=true;material.normal_scale=float(spec.normal);material.roughness=float(spec.roughness)
		# The physical catalogue map remains the pigment source. This tint is
		# deliberately conservative; native pigment mixing is review-only.
		assert(float(spec.pigment)>0. and float(spec.pigment)<=1.)
		var tint: Array=spec.tint
		material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		finishes[name]=material
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			var source: Material=draw.mesh.surface_get_material(surface)
			assert(source!=null and finishes.has(source.resource_name),"unknown native handheld finish")
			draw.set_surface_override_material(surface,finishes[source.resource_name])
	var paper: Dictionary=data.paper
	assert(paper.center.size()==3 and float(paper.width)>0. and float(paper.height)>0.,"native paper datum")
	return paper
