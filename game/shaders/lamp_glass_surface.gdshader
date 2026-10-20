shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;
// Clear dielectric: no diffuse paint term. The engine owns every light and
// shadow, while the separate optical haze layer accounts for scattering.
// Authored normals bend opaque scenery. As with StandardMaterial3D refraction,
// the screen copy excludes transparent scenery; this is not caustic transport.
uniform float surface_roughness : hint_range(0.02,0.4) = 0.06;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0,2.0) = 1.0;
uniform float refraction_strength : hint_range(0.0,0.1) = 0.035;
uniform sampler2D scene_color : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)),0.0,1.0);
	float fresnel = 0.04 + 0.96*pow(1.0-facing,5.0);
	ALBEDO = vec3(0.0);
	METALLIC = 0.0;
	// Legacy glass roughness is packed in GREEN; red is a constant white mask.
	ROUGHNESS = clamp(surface_roughness * (0.75 + 0.5 * texture(rough_tex, UV).g), 0.02, 0.4);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	SPECULAR = 0.5;
	vec2 slope = (NORMAL_MAP.xy * 2.0 - 1.0) * normal_strength;
	vec3 optical_normal = normalize(TANGENT * slope.x + BINORMAL * slope.y
		+ NORMAL * sqrt(max(0.0, 1.0 - dot(slope,slope))));
	vec2 refracted_uv = clamp(SCREEN_UV - optical_normal.xy * refraction_strength, vec2(0.001),vec2(0.999));
	float depth = textureLod(scene_depth,refracted_uv,0.0).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(refracted_uv * 2.0 - 1.0,depth,1.0);
	// Reject foreground samples at silhouettes, tapering displacement over 20 cm.
	float clearance = VERTEX.z - behind.z / behind.w;
	vec2 sample_uv = mix(SCREEN_UV,refracted_uv,smoothstep(0.0,0.2,clearance));
	// This carries already-lit scenery, not an independent luminous source.
	EMISSION = textureLod(scene_color,sample_uv,ROUGHNESS * 8.0).rgb * (1.0-fresnel) * EXPOSURE;
	ALPHA = 1.0;
}
