class_name MatLib
extends Object
## Runtime texture-backed materials for GDScript-built props, resolving
## the same shared exported texture set the Blender floors use
## (res://assets/building/textures/, deterministic T_* names). Materials
## are triplanar in world space at each set's physical meters_per_tile,
## so a BoxMesh knob and a CylinderMesh drum tile at the same real-world
## scale as the architecture — no per-mesh UV work, no per-prop loads.
## One cached StandardMaterial3D per (key, tint); callers that need
## unique runtime mutation must .duplicate() the result themselves.

const TEX := "res://assets/building/textures/"

# key -> [albedo, rough, normal, meters_per_tile, metallic]
# worn_* albedo/rough variants come from the precomposited overlay pass.
const SETS := {
	"enamel": ["T_library_appliances_aged_enamel_worn_enamel_albedo.png",
			"T_library_appliances_aged_enamel_worn_enamel_rough.png",
			"T_library_appliances_aged_enamel_normal.png", 1.0, 0.0],
	"appliance": [
			"T_library_appliances_aged_enamel_worn_appliance_albedo.png",
			"T_library_appliances_aged_enamel_worn_appliance_rough.png",
			"T_library_appliances_aged_enamel_normal.png", 1.0, 0.0],
	"metal": ["T_library_appliances_galvanized_metal_worn_metal_albedo.png",
			"T_library_appliances_galvanized_metal_worn_metal_rough.png",
			"T_library_appliances_galvanized_metal_normal.png", 0.9, 0.9],
	"chrome": ["T_library_appliances_brushed_steel_albedo.png",
			"T_library_appliances_brushed_steel_rough.png",
			"T_library_appliances_brushed_steel_normal.png", 0.8, 1.0],
	"bakelite": ["T_library_appliances_bakelite_albedo.png",
			"T_library_appliances_bakelite_rough.png",
			"T_library_appliances_bakelite_normal.png", 0.35, 0.0],
	"brass": ["T_library_metals_aged_brass_albedo.png",
			"T_library_metals_aged_brass_rough.png",
			"T_library_metals_aged_brass_normal.png", 0.5, 0.85],
	"porcelain": ["T_library_furniture_porcelain_albedo.png",
			"T_library_furniture_porcelain_rough.png",
			"T_library_furniture_porcelain_normal.png", 0.9, 0.0],
	"wood_dark": ["T_library_furniture_walnut_albedo.png",
			"T_library_furniture_walnut_rough.png",
			"T_library_furniture_walnut_normal.png", 1.2, 0.0],
	"fabric_warm": ["T_library_furniture_upholstery_rust_albedo.png",
			"T_library_furniture_upholstery_rust_rough.png",
			"T_library_furniture_upholstery_rust_normal.png", 0.7, 0.0],
	"linen": ["T_library_furniture_linen_albedo.png",
			"T_library_furniture_linen_rough.png",
			"T_library_furniture_linen_normal.png", 0.6, 0.0],
	"paper": ["T_library_furniture_aged_paper_albedo.png",
			"T_library_furniture_aged_paper_rough.png",
			"T_library_furniture_aged_paper_normal.png", 0.5, 0.0],
	"trim": ["T_library_architectural_painted_trim_albedo.png",
			"T_library_architectural_painted_trim_rough.png",
			"T_library_architectural_painted_trim_normal.png", 1.2, 0.0],
	"plant": ["T_library_organic_leaf_surface_albedo.png",
			"T_library_organic_leaf_surface_rough.png",
			"T_library_organic_leaf_surface_normal.png", 0.5, 0.0],
}

static var _cache: Dictionary = {}


## Shared material for a semantic key, optionally tinted (albedo_color
## multiplies the map — dark tints turn galvanized into cast iron, etc.)
static func get_mat(key: String, tint := Color.WHITE,
		scale_mult := 1.0) -> StandardMaterial3D:
	var ck := "%s|%s|%.2f" % [key, tint.to_html(), scale_mult]
	if _cache.has(ck):
		return _cache[ck]
	var spec: Array = SETS.get(key, [])
	var mat := StandardMaterial3D.new()
	if spec.is_empty():
		mat.albedo_color = tint
		_cache[ck] = mat
		return mat
	mat.albedo_texture = load(TEX + spec[0])
	mat.albedo_color = tint
	var rt: Texture2D = load(TEX + spec[1])
	if rt:
		mat.roughness_texture = rt
		mat.roughness = 1.0
	mat.normal_enabled = true
	mat.normal_texture = load(TEX + spec[2])
	mat.normal_scale = 0.35
	mat.metallic = float(spec[4])
	# world triplanar at physical scale: primitives tile like architecture
	mat.uv1_triplanar = true
	var s: float = 1.0 / (float(spec[3]) * scale_mult)
	mat.uv1_scale = Vector3(s, s, s)
	_cache[ck] = mat
	return mat
