shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Registered porcelain retains the shared surface pipeline. COLOR.r carries
// only the native _EMISSION_REGION tag, never a replacement albedo texture.
#include "res://shaders/orison_surface.gdshaderinc"
uniform float capacitor_charge : hint_range(0.0, 1.0) = 0.0;
void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	OrisonSurface s = orison_surface(UV, VERTEX, NORMAL, TANGENT, BINORMAL,
		EYE_OFFSET, VIEW_MATRIX, TIME);
	ALBEDO = s.albedo;
	NORMAL = s.normal;
	ROUGHNESS = s.rough;
	METALLIC = s.metal;
	AO = s.ao;
	AO_LIGHT_AFFECT = ao_light_affect;
	// Steady, restrained emission, including reduced-flash presentation. No
	// additional light or autonomous oscillator; command/power own the charge.
	EMISSION = s.emission + vec3(.32, 1.0, .48) * step(.1, COLOR.r) * capacitor_charge * .65;
	BACKLIGHT = s.backlight;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	ANISOTROPY = anisotropy;
}
