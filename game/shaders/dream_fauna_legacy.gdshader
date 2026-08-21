shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/dream_fauna_style.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.32, 0.06, 0.10);
uniform vec3 gold_color : source_color = vec3(0.72, 0.43, 0.10);
uniform float gait_amount = 0.12;
varying vec4 legacy_data;

void vertex() {
	legacy_data = INSTANCE_CUSTOM;
	float nutrient = fauna_unit(fauna_high_byte(INSTANCE_CUSTOM.g));
	float activity = fauna_unit(fauna_low_byte(INSTANCE_CUSTOM.b));
	float phase = fract(INSTANCE_CUSTOM.r) * 6.2831853;
	float gait = sin(TIME * (0.42 + nutrient * 0.35) + phase);
	VERTEX.y += gait * gait_amount * activity;
	VERTEX.xz *= 1.0 + gait * 0.06 * activity;
}

void fragment() {
	float band = fauna_unit(fauna_low_byte(legacy_data.g));
	ALBEDO = mix(base_color, gold_color, band);
	METALLIC = 0.28;
	EMISSION = ALBEDO * (0.004 + band * 0.022);
	ROUGHNESS = 0.64;
}
