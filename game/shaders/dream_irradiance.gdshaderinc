// IR-V1: one continuous pointwise response shared by architecture, lineage
// and fauna. exposure_tex.r stays durable; .g is the reversible rate-limited
// lamp response written at 15 Hz by DreamExposureField.

uniform float irradiance_retained_gain : hint_range(0.0, 0.5) = 0.24;
uniform float irradiance_incidence_floor : hint_range(0.0, 1.0) = 0.68;
uniform vec2 irradiance_band_neon = vec2(0.30, 0.58);
uniform vec4 irradiance_band_oblique = vec4(0.16, 0.38, 0.68, 0.86);
uniform vec2 irradiance_band_molten = vec2(0.62, 0.90);
uniform float irradiance_hue : hint_range(-0.20, 0.20) = 0.0;
uniform float irradiance_vein_branch : hint_range(0.5, 2.0) = 1.0;
uniform float irradiance_line_weight : hint_range(0.5, 2.0) = 1.0;
uniform float irradiance_pattern_species : hint_range(0.0, 7.0) = 0.0;
uniform float irradiance_viscosity : hint_range(0.25, 2.0) = 1.0;
uniform float irradiance_pulse_phase = 0.0;

// INC-V1. One inert, bounded presentation bundle reaches every architecture,
// lineage and fauna material through the existing root collector. Later
// incarnation passes consume these values; declaring them here does not alter
// the current shader result.
uniform float incarnation_id : hint_range(0.0, 6.0) = 0.0;
uniform vec4 incarnation_palette = vec4(0.0);
uniform vec4 incarnation_pattern = vec4(0.0, 1.0, 1.0, 1.0);
uniform vec4 incarnation_irradiance = vec4(1.0);
uniform vec4 incarnation_motion = vec4(0.0);
uniform vec2 incarnation_signature = vec2(1.0, 0.0);
uniform vec4 incarnation_fauna = vec4(0.0, 0.0, 0.0, 1.0);

// x neon, y oblique, z molten, w scalar.
vec4 dream_irradiance(vec3 world_position, vec3 world_normal,
		vec2 field, vec3 light_origin) {
	vec3 toward_light = normalize(light_origin - world_position);
	float incidence = mix(irradiance_incidence_floor, 1.0,
			abs(dot(normalize(world_normal), toward_light)));
	float scalar = clamp(field.g * incidence
			+ field.r * irradiance_retained_gain, 0.0, 1.0);
	float neon = 1.0 - smoothstep(irradiance_band_neon.x,
			irradiance_band_neon.y, scalar);
	float oblique = smoothstep(irradiance_band_oblique.x,
			irradiance_band_oblique.y, scalar)
			* (1.0 - smoothstep(irradiance_band_oblique.z,
			irradiance_band_oblique.w, scalar));
	float molten = smoothstep(irradiance_band_molten.x,
			irradiance_band_molten.y, scalar);
	return vec4(neon, oblique, molten, scalar);
}

vec3 dream_irradiance_hue(vec3 colour) {
	return max(vec3(0.0), mix(colour, colour.gbr,
			max(0.0, irradiance_hue))
			+ mix(vec3(0.0), colour.rbg - colour,
			max(0.0, -irradiance_hue)));
}
