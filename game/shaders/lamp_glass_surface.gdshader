shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;
// Clear dielectric: no diffuse paint term. The engine owns every light and
// shadow, while the separate optical haze layer accounts for scattering.
// No screen-texture refraction, stochastic alpha or time-dependent distortion.
uniform float surface_roughness : hint_range(0.02,0.4) = 0.06;
void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)),0.0,1.0);
	float fresnel = 0.04 + 0.96*pow(1.0-facing,5.0);
	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.5;
	ALPHA = clamp(fresnel,0.04,0.92);
	EMISSION = vec3(0.0);
}
