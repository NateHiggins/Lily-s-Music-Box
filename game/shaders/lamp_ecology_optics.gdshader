shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 lamp_position;
uniform vec3 lamp_direction = vec3(0.0, 0.0, -1.0);
uniform float lamp_intensity = 1.0;
uniform vec3 tissue_color : source_color = vec3(0.24, 0.025, 0.08);
uniform vec3 vessel_color : source_color = vec3(0.48, 0.055, 0.12);

varying vec3 world_position;
varying vec3 object_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	object_position = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 to_light = normalize(lamp_position - world_position);
	float incidence = dot(n, to_light);
	float grazing = pow(1.0 - abs(dot(n, normalize(VIEW))), 2.2);
	float ridges = 0.5 + 0.5 * sin(object_position.y * 34.0
		+ object_position.x * 17.0 + hash31(floor(object_position * 12.0)) * 2.0);
	float paired_dic = clamp(0.5 + incidence * 0.48, 0.0, 1.0);
	float membrane = smoothstep(0.26, 0.92, grazing);
	float internal = smoothstep(0.63, 0.83,
		0.5 + 0.34 * sin(object_position.x * 19.0)
		+ 0.24 * sin(object_position.y * 27.0 + object_position.z * 11.0));
	float back = clamp(-incidence, 0.0, 1.0) * lamp_intensity;
	ALBEDO = mix(tissue_color * (0.52 + ridges * 0.34), vessel_color,
		internal * (0.18 + back * 0.52));
	ALBEDO *= mix(0.72, 1.24, paired_dic);
	ROUGHNESS = mix(0.46, 0.12, ridges * 0.72);
	SPECULAR = 0.82;
	METALLIC = 0.0;
	SSS_STRENGTH = 0.38;
	SSS_TRANSMITTANCE_COLOR = vec4(0.92, 0.10, 0.16, 1.0);
	SSS_TRANSMITTANCE_DEPTH = 0.48;
	SSS_TRANSMITTANCE_BOOST = 0.62;
	BACKLIGHT = mix(tissue_color, vec3(0.92, 0.16, 0.12),
		internal * 0.66 + membrane * 0.34) * lamp_intensity;
	// No emission: physiology is revealed only by actual light/transmission.
	EMISSION = vec3(0.0);
}
