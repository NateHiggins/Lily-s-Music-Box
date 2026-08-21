// FA-V1 shared fauna style/channel helpers. Keep the byte arithmetic highp:
// INSTANCE_CUSTOM values reach 65535 and must round-trip on every backend.

highp float fauna_high_byte(highp float packed_value) {
	highp float exact = floor(clamp(packed_value, 0.0, 65535.0) + 0.5);
	return floor(exact / 256.0);
}

highp float fauna_low_byte(highp float packed_value) {
	highp float exact = floor(clamp(packed_value, 0.0, 65535.0) + 0.5);
	return exact - floor(exact / 256.0) * 256.0;
}

float fauna_unit(highp float byte_value) {
	return clamp(byte_value / 255.0, 0.0, 1.0);
}

float fauna_flag(highp float flags, float bit_value) {
	return mod(floor(flags / bit_value), 2.0);
}

float fauna_lamp_awake(vec3 world_position, vec3 lamp_origin_value,
		vec3 lamp_direction, float lamp_reach_value, float lamp_cos_outer_value,
		float lamp_energy_value) {
	vec3 to_fragment = world_position - lamp_origin_value;
	float distance_m = length(to_fragment);
	vec3 ray = distance_m > 0.0001
			? to_fragment / distance_m : vec3(0.0, 0.0, -1.0);
	float cone = smoothstep(lamp_cos_outer_value,
			mix(lamp_cos_outer_value, 1.0, 0.18), dot(ray, lamp_direction));
	float reach = pow(1.0 - clamp(distance_m / max(0.5, lamp_reach_value),
			0.0, 1.0), 0.62);
	return cone * reach * clamp(lamp_energy_value, 0.0, 1.35);
}

float fauna_cloisonne_wire(vec3 local_position, float pattern_jitter,
		float family_motif_value) {
	float scale = mix(24.0, 38.0, pattern_jitter);
	float line_a = abs(sin((local_position.x + local_position.z * 0.35)
			* scale + family_motif_value * 1.71));
	float line_b = abs(sin((local_position.z - local_position.y * 0.50)
			* scale * 0.83 - family_motif_value * 0.91));
	return 1.0 - smoothstep(0.045, 0.13, min(line_a, line_b));
}
