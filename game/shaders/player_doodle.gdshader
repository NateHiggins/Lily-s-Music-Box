shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// The supplied ink and paper remain the image. Only the native head skin
// receives a flat neutral fill; torso and limbs keep their existing PBR.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 stock_tint : source_color = vec4(1.0);
uniform float roughness_gain = 1.0;
uniform float normal_strength = 0.45;
uniform int head_bind = -1;
uniform float face_luminance : hint_range(0.0, 1.0) = 0.65;
varying float head_weight;

void vertex() {
	head_weight = 0.0;
	for (int i = 0; i < 4; i++) {
		if (int(BONE_INDICES[i]) == head_bind) {
			head_weight += BONE_WEIGHTS[i];
		}
	}
}

void fragment() {
	vec3 paper = texture(albedo_tex, UV).rgb * stock_tint.rgb;
	float face = smoothstep(0.80, 0.99, head_weight);
	ALBEDO = paper * (1.0 - face);
	ROUGHNESS = texture(rough_tex, UV).r * roughness_gain;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	SPECULAR = 0.5 * (1.0 - face);
	METALLIC = 0.0;
	// Cancel the renderer's emissive exposure normalization, as a printed
	// mark with its own legibility floor. Black ink stays black; no lamp,
	// extra light, next pass or shadow bypass. The body retains scene lighting.
	EMISSION = paper * face * face_luminance * EXPOSURE;
}
