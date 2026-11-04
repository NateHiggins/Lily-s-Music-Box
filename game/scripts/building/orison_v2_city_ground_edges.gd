extends RefCounted
## Passive source-fitted edge stock. No grade, clock, actor or save authority.
const RECIPE := "res://data/orison_v2/exterior/city_ground_edges.json"

static func mount(frame: Node3D) -> Node3D:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RECIPE))
	assert(int(data.schema)==1 and str(data.frame)=="ORISON_V2_BUILDING_FRAME")
	assert(float(data.lod_error_m)>0.)
	var model: Node3D=(load(str(data.asset)) as PackedScene).instantiate() as Node3D
	var low: Node3D=(load(str(data.lower_asset)) as PackedScene).instantiate() as Node3D
	assert(model.transform.is_equal_approx(low.transform))
	model.name="CityGroundEdges"
	# Exported nodes already carry their source anchor and axis conversion.
	# The registered building frame is the only runtime placement.
	frame.add_child(model)
	var near_parts:=model.find_children("*","MeshInstance3D",true,false)
	var low_parts:=low.find_children("*","MeshInstance3D",true,false)
	assert(near_parts.size()==1 and low_parts.size()==1)
	var draw:=near_parts[0] as MeshInstance3D
	var replacement:=low_parts[0] as MeshInstance3D
	assert(str(draw.name)==str(data.part) and str(replacement.name)==str(data.lower_part))
	assert(draw.transform.is_equal_approx(replacement.transform))
	assert(draw.mesh.get_surface_count()==1 and replacement.mesh.get_surface_count()==1)
	var spec: Dictionary=data.finish
	assert(MatLib.SETS.has(str(spec.catalog_key)) and is_equal_approx(float(spec.pigment),1.))
	var stock:=MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
	stock.uv1_triplanar=false
	stock.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var tint: Array=spec.tint
	stock.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
	stock.normal_scale=float(spec.normal);stock.roughness*=float(spec.roughness)
	var near_mesh:=draw.mesh
	draw.mesh=preload("res://scripts/building/orison_v2_city_transport.gd")._with_lod(near_mesh,replacement.mesh,float(data.lod_error_m))
	draw.material_override=SurfacePass.weather_surface(stock,{})
	draw.set_meta("v2_city_ground_edge_source",stock)
	draw.set_meta("v2_city_ground_edges",true)
	var body:=StaticBody3D.new();body.name="SourceCollision"
	var collision:=CollisionShape3D.new();collision.name="NearSurface"
	collision.shape=near_mesh.create_trimesh_shape();body.add_child(collision);draw.add_child(body)
	low.free()
	return model
