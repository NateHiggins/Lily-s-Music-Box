shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color = vec3(0.32, 0.06, 0.10);
uniform vec3 gold_color = vec3(0.72, 0.43, 0.10);
uniform float gait_amount = 0.12;
varying vec4 fauna_data;

void vertex() {
	fauna_data = INSTANCE_CUSTOM;
	float phase = INSTANCE_CUSTOM.r * 6.2831853;
	float gait = sin(TIME * (0.42 + INSTANCE_CUSTOM.g * 0.35) + phase);
	VERTEX.y += gait * gait_amount * INSTANCE_CUSTOM.b;
	VERTEX.xz *= 1.0 + gait * 0.06 * INSTANCE_CUSTOM.b;
}

void fragment() {
	float band = clamp(fauna_data.a, 0.0, 1.0);
	ALBEDO = mix(base_color, gold_color, band);
	METALLIC = 0.28;
	EMISSION = ALBEDO * (0.004 + band * 0.022);
	ROUGHNESS = 0.64;
}
