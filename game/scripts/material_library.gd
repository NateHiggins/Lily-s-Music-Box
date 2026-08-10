class_name MatLib
extends Object
## Runtime texture-backed materials for GDScript-built props. The generated
## set table is emitted by the same ingest contract that feeds Blender; never
## add a material path or physical scale here. MatLib's API remains stable so
## props do not care where the authority lives.
##
## One cached StandardMaterial3D exists per (key, tint, scale). A caller that
## changes any property on the returned material must duplicate it first.

const TEX := "res://assets/building/textures/"
const GENERATED_SETS := preload("res://scripts/generated/material_sets.gd")
const SETS := GENERATED_SETS.SETS

static var _cache: Dictionary = {}


## Shared material for a semantic key, optionally tinted. Albedo colour
## multiplies the map; scale_mult changes projection scale without claiming a
## second meters-per-tile for the material itself.
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
		mat.roughness = float(spec[5]) if spec.size() > 5 else 1.0
	mat.normal_enabled = true
	mat.normal_texture = load(TEX + spec[2])
	mat.normal_scale = 0.35
	mat.metallic = float(spec[4])
	if spec.size() > 6 and bool(spec[6]):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.uv1_triplanar = true
	var s: float = 1.0 / (float(spec[3]) * scale_mult)
	mat.uv1_scale = Vector3(s, s, s)
	_cache[ck] = mat
	return mat
