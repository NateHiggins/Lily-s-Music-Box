extends RefCounted
## Passive landmark and approach. Travel boundaries, calendar and saves retain
## their existing owners. Structural collision always uses the near body.
const NEAR := preload("res://assets/props/city_bridge.glb")
const FAR := preload("res://assets/props/city_bridge_lod1.glb")
const FINISHES := "res://data/orison_v2/exterior/city_bridge.json"

static func mount(city: Node3D) -> Node3D:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	assert(int(data.schema)==1 and str(data.frame)=="BRIDGE_ENGINEERING_X_MANHATTAN_TO_QUEENS_Z_HIGH_WATER")
	assert(float(data.main_length_m)>1000. and float(data.lod_error_m)>0.)
	var direction:=Vector3(sin(deg_to_rad(float(data.eastbound_azimuth_deg))),0.,-cos(deg_to_rad(float(data.eastbound_azimuth_deg))))
	var q: Array=data.queens_source_xy_m
	var queens:=Vector3(float(q[0]),float(data.water_scene_y_m),-float(q[1]))
	var model:=NEAR.instantiate() as Node3D
	model.name="QueensboroBridge"
	# glTF already converted native Z-up to Godot Y-up. One rigid placement
	# aligns native X to the declared bearing; do not apply b2g a second time.
	model.transform=Transform3D(Basis(direction,Vector3.UP,direction.cross(Vector3.UP)),queens-direction*float(data.main_length_m))
	city.add_child(model)
	var low:=FAR.instantiate() as Node3D
	var lower: Dictionary={}
	for draw: MeshInstance3D in low.find_children("*","MeshInstance3D",true,false):
		var identity:=str(draw.name).replace("_L1__","_L0__")
		assert(not lower.has(identity))
		lower[identity]=draw
	var materials: Dictionary={}
	for spec: Dictionary in data.finishes:
		var alias:=str(spec.alias)
		assert(not materials.has(alias) and MatLib.SETS.has(str(spec.catalog_key)) and is_equal_approx(float(spec.pigment),1.))
		var material:=MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
		material.uv1_triplanar=false
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var tint: Array=spec.tint
		material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
		material.normal_scale=float(spec.normal)
		material.roughness*=float(spec.roughness)
		material.metallic=float(spec.metallic)
		if alias=="water_clear":
			# Reuse the existing opaque turbid-river policy; no kilometre-wide
			# screen refraction pass or new reflection viewport.
			material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
		materials[alias]=material
	var seen: Array[String]=[]
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var identity:=str(draw.name)
		assert(identity in data.parts and lower.has(identity))
		var replacement: MeshInstance3D=lower[identity]
		assert(draw.transform.is_equal_approx(replacement.transform))
		assert(draw.mesh.get_surface_count()==1 and replacement.mesh.get_surface_count()==1)
		var near_mesh:=draw.mesh
		draw.mesh=preload("res://scripts/building/orison_v2_city_transport.gd")._with_lod(near_mesh,replacement.mesh,float(data.lod_error_m))
		var alias:=identity.split("__")[-1]
		var material: StandardMaterial3D=materials[alias]
		draw.material_override=material if alias=="water_clear" else SurfacePass.weather_surface(material,{})
		draw.set_meta("v2_bridge_source",material)
		draw.set_meta("v2_city_bridge",true)
		if alias in ["soil","water_clear"]:
			draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			var body:=StaticBody3D.new()
			body.name="SourceCollision"
			var collision:=CollisionShape3D.new()
			collision.name="NearSurface"
			collision.shape=near_mesh.create_trimesh_shape()
			body.add_child(collision)
			draw.add_child(body)
		seen.append(identity)
	assert(seen.size()==data.parts.size() and seen.size()==lower.size() and not seen.is_empty())
	low.free()
	return model
