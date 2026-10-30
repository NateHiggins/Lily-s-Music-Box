shader_type spatial;
render_mode cull_back;

// UV is the authored metric PBR chart. UV2=(rail fraction, height fraction)
// survives glTF export independently; never infer either from a tiled UV.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meters_per_tile = 0.65;
uniform float normal_depth = 0.08;
uniform float gather : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cloth_tint : source_color = vec4(1.0);

vec3 curtain_point(float u, float h, float amount) {
	float angle = mix(-PI + 0.065 + (TAU - 0.13) * u, -0.21 + 0.42 * u, amount);
	float fold = mix(0.008, 0.033, amount) * pow(max(0.0, 1.0 - h), 0.65)
		* sin(u * TAU * 24.0 + 0.35 * h);
	return vec3((0.600 + 0.145 * h + fold) * cos(angle),
		0.345 + 1.9 * h, -(0.260 + 0.095 * h + fold) * sin(angle));
}

mat3 curtain_frame(float u, float h, float amount) {
	// Small finite differences include the pleats and elliptical taper. This
	// runs per vertex only, and keeps the normal map attached while gathering.
	float low = max(0.0, h - 0.001);
	float high = min(1.0, h + 0.001);
	vec3 across = (curtain_point(u + 0.001, h, amount)
		- curtain_point(u - 0.001, h, amount)) / 0.002;
	vec3 up = (curtain_point(u, high, amount)
		- curtain_point(u, low, amount)) / (high - low);
	return mat3(across, up, normalize(cross(across, up)));
}

void vertex() {
	float u = UV2.x;
	float h = UV2.y;
	float phase = clamp(gather, 0.0, 1.0);
	float before = -PI + 0.065 + (TAU - 0.13) * u;
	float angle = mix(before, -0.21 + 0.42 * u, phase) - before;
	float c = cos(angle);
	float s = sin(angle);
	mat3 rotation = mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
	vec3 thickness = VERTEX - curtain_point(u, h, 0.0);
	VERTEX = curtain_point(u, h, phase) + rotation * thickness;
	mat3 deformation = curtain_frame(u, h, phase) * inverse(curtain_frame(u, h, 0.0));
	NORMAL = normalize(transpose(inverse(deformation)) * NORMAL);
	TANGENT = normalize(deformation * TANGENT);
	BINORMAL = normalize(deformation * BINORMAL);
}

void fragment() {
	vec2 chart = UV / max(0.001, meters_per_tile);
	ALBEDO = texture(albedo_tex, chart).rgb * cloth_tint.rgb;
	ROUGHNESS = clamp(texture(rough_tex, chart).r, 0.05, 1.0);
	NORMAL_MAP = texture(normal_tex, chart).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
