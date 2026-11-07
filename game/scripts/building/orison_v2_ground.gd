extends Node3D
## Bounded subgrade and retained-datum court surface in the registered V2 frame.
const ASSET:=preload("res://assets/props/orison_ground.glb")

func _ready() -> void:
	var model:=ASSET.instantiate() as Node3D
	add_child(model)
	var apron := (preload("res://assets/props/city_ground_apron.glb") as PackedScene).instantiate() as Node3D
	apron.name = "DistantApron"
	model.add_child(apron)
	var asphalt:=MatLib.get_mat("asphalt").duplicate() as StandardMaterial3D
	var original_asphalt := asphalt.duplicate() as StandardMaterial3D
	original_asphalt.uv1_triplanar=false
	var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/ground_finish.json"))
	var tint: Array=recipe.tint
	asphalt.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
	asphalt.normal_scale=float(recipe.normal)
	asphalt.roughness=float(recipe.roughness)
	var soil:=MatLib.get_mat("soil").duplicate() as StandardMaterial3D
	asphalt.uv1_triplanar=false;soil.uv1_triplanar=false
	var exposed_asphalt:=SurfacePass.weather_surface(asphalt,{})
	var relief: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_ground_relief.json"))
	assert(int(relief.schema)==1 and str(relief.frame)=="ORISON_V2_BUILDING_FRAME")
	set_meta("city_street_asl_m",float(relief.street_asl_m))
	set_meta("city_water_scene_y_m",float(relief.water_scene_y_m))
	var relief_materials: Dictionary={}
	for spec: Dictionary in relief.finishes:
		var key:=str(spec.catalog_key)
		assert(not relief_materials.has(key))
		var stock:=MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
		stock.uv1_triplanar=false
		var pigment: Array=spec.tint
		stock.albedo_color=Color(pigment[0],pigment[1],pigment[2],pigment[3])
		stock.normal_scale=float(spec.normal);stock.roughness=float(spec.roughness)
		# Opaque turbid river water keeps depth/world occlusion and avoids a
		# kilometre-wide refraction pass. Its finite ripple maps retain mipmaps.
		relief_materials[key]=stock if key=="water_clear" else SurfacePass.weather_surface(stock,{})
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.material_override=exposed_asphalt if str(draw.name).contains("asphalt") else soil
		if str(draw.name).contains("__"):
			var key: String=str(draw.name).split("__")[-1]
			assert(relief_materials.has(key))
			draw.material_override=relief_materials[key]
			if key=="water_clear":continue # A water surface is not a walkable slab.
		if str(draw.name).contains("asphalt"):draw.set_meta("v2_ground_source",original_asphalt)
		var body:=StaticBody3D.new();body.name="GroundCollision";draw.add_child(body)
		var collision:=CollisionShape3D.new()
		collision.shape=_native_shape(draw.mesh);body.add_child(collision)

func _native_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(preload("res://scripts/building/orison_v2_native_faces.gd").read(mesh));return shape
