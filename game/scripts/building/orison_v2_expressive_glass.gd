extends RefCounted
## Authored dielectric relief drives the engine's lit, screen-space refraction.
## Opaque scenery is refracted; transparent layers remain an engine limitation.
const STYLES := {
	"glass_drawn_expressive": {"refraction":.025,"opacity":.055},
	"glass_reeded": {"refraction":.065,"opacity":.065},
	"glass_cut": {"refraction":.055,"opacity":.045},
	"glass_frosted": {"refraction":.035,"opacity":.16},
}

static func make(key: String) -> StandardMaterial3D:
	if not STYLES.has(key) or not MatLib.SETS.has(key):return null
	var mat:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
	mat.resource_name=key;mat.uv1_triplanar=false
	mat.normal_enabled=true;mat.normal_scale=1.;mat.roughness=1.;mat.metallic=0.
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color=Color(1,1,1,float(STYLES[key].opacity))
	mat.refraction_enabled=true;mat.refraction_scale=float(STYLES[key].refraction)
	return mat
