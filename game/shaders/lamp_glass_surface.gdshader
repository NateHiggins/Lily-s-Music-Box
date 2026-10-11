shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;
// Clear dielectric: no diffuse paint term. The engine owns every light and
// shadow, while the separate optical haze layer accounts for scattering.
// No screen-texture refraction, stochastic alpha or time-dependent distortion.
uniform float surface_roughness : hint_range(0.02,0.4) = 0.06;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0,0.2) = 0.035;
void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)),0.0,1.0);
	float fresnel = 0.04 + 0.96*pow(1.0-facing,5.0);
	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	ROUGHNESS = clamp(surface_roughness * (0.75 + 0.5 * texture(rough_tex, UV).r), 0.02, 0.4);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	SPECULAR = 0.5;
	ALPHA = clamp(fresnel,0.04,0.92);
	EMISSION = vec3(0.0);
}
