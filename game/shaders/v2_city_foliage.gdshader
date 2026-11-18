shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// City greenery leaves (orison_v2_city_greenery.gd): the catalogued plant finish on
// the stock's metric UVs, multiplied by the crown's vertex shading and the season,
// moving in the weather's wind. Opaque blades; no cut-out.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(2.0);
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float roughness_scale = 1.0;
uniform float normal_scale : hint_range(0.0, 2.0) = 0.35;
// Wind across the city, metres of bend at the crown top per metre of height above
// `bend_start`, and the leaves' own flutter. Set from the weather a few times a minute.
uniform vec2 wind_direction = vec2(0.96, -0.27);
uniform float wind_strength : hint_range(0.0, 1.5) = 0.35;
uniform float gust = 0.0;
uniform float bend_start = 2.6;
uniform float bend_per_m = 0.012;
uniform float flutter_m = 0.025;

void vertex() {
	// Instance origin in world space: a whole tree sways in its own phase.
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(origin.xz, vec2(0.137, 0.311));
	float height = max(VERTEX.y - bend_start, 0.0);
	float strength = wind_strength * (1.0 + gust * (0.5 + 0.5 * sin(TIME * 0.37 + phase * 0.5)));
	float sway = (0.65 + 0.35 * sin(TIME * 0.9 + phase)) * strength;
	vec3 bend = vec3(wind_direction.x, 0.0, wind_direction.y) * height * height * bend_per_m * sway;
	// Local wind: undo the instance's turn and scale so every tree leans the same way.
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	vec3 local_bend = to_local * bend;
	// Each leaf trembles on its own: hash its rest position.
	float leaf = fract(sin(dot(floor(VERTEX * 7.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float flutter = sin(TIME * (6.0 + leaf * 5.0) + leaf * 6.2831) * flutter_m * strength * smoothstep(0.0, 1.0, VERTEX.y);
	VERTEX += local_bend + NORMAL * flutter;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	ALBEDO = texture(albedo_tex, uv).rgb * COLOR.rgb * season_tint;
	ROUGHNESS = texture(rough_tex, uv).r * roughness_scale;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	// A thin leaf lets light through: a little backlight from the sun side.
	BACKLIGHT = ALBEDO * 0.35;
}
