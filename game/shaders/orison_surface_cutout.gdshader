shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ORISON SURFACE, cutout. The same layered surface as orison_surface.gdshader
// plus the alpha path for GENUINE cutouts — torn plaster (the finish
// survival mask), mesh, holes — as scissor or hash, never blend. The
// corruption state can restore the surface as a membrane where it has been
// torn away (the encroachment's grammar), which is why the cutout knows
// about the masks at all.

#include "res://shaders/orison_surface.gdshaderinc"

group_uniforms cutout;
// 1 = alpha scissor (hard edge), 2 = alpha hash (dithered, mips safe).
uniform int cutout_mode : hint_range(1, 2) = 1;
// 0 = the albedo's alpha, 1 = cutout_tex.r.
uniform int cutout_source : hint_range(0, 1) = 0;
uniform sampler2D cutout_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float cutout_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool corruption_restores = true;
// Damage on a cutout TEARS it (the plaster goes, the masonry shows) instead
// of painting a substrate on it.
uniform bool damage_tears = true;
group_uniforms;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	OrisonSurface s = orison_surface(UV, VERTEX, NORMAL, TANGENT, BINORMAL,
			EYE_OFFSET, VIEW_MATRIX, TIME);
	float a = cutout_source == 1 ? texture(cutout_tex, UV).r : s.alpha;
	if (damage_tears) {
		a = min(a, 1.0 - smoothstep(0.25, 0.6, s.damage));
	}
	if (corruption_restores) {
		a = max(a, s.corruption);
	}
	ALPHA = a;
	if (cutout_mode == 2) {
		ALPHA_HASH_SCALE = 1.0;
	} else {
		ALPHA_SCISSOR_THRESHOLD = cutout_threshold;
	}
	ALBEDO = s.albedo;
	NORMAL = s.normal;
	ROUGHNESS = s.rough;
	METALLIC = s.metal;
	AO = s.ao;
	AO_LIGHT_AFFECT = ao_light_affect;
	EMISSION = s.emission;
	BACKLIGHT = s.backlight;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	ANISOTROPY = anisotropy;
}
