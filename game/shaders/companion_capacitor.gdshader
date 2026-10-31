shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// Registered porcelain retains the shared surface pipeline. COLOR.r carries
// only the native _EMISSION_REGION tag, never a replacement albedo texture.
#include "res://shaders/orison_surface.gdshaderinc"
uniform float capacitor_charge : hint_range(0.0, 1.0) = 0.0;
uniform vec3 amber_linear = vec3(1.0, .376262123, .02842604);
uniform float emission_strength = 2.0;
uniform vec3 off_lens_tint = vec3(.055, .020694417, .001563432);
uniform bool segmented_display = false;
uniform int digit_masks[36];
uniform vec3 row_valid = vec3(0.0);
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
	float powered = step(.1, COLOR.r);
	if (segmented_display) {
		int row = clamp(int(round(COLOR.r * 2.0)), 0, 2);
		int digit = int(round(COLOR.g * 12.0)) - 1;
		int segment = clamp(int(round(COLOR.b * 8.0)), 0, 8);
		powered = row_valid[row];
		if (digit >= 0 && segment < 7) {
			powered *= float((digit_masks[row * 12 + digit] >> segment) & 1);
		}
		ALBEDO *= off_lens_tint;
	}
	EMISSION = s.emission + amber_linear * powered * capacitor_charge * emission_strength;
	BACKLIGHT = s.backlight;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	ANISOTROPY = anisotropy;
}
