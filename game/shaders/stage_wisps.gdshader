shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// The loose strands at the edge of a sculpted stage hairdo (the builder's "<person>_stage_wisps_<part>" surface).
// Their texture's v runs from the root (1) to the tip (0), so each strand swings more toward its tip and never
// at the root, where it meets the sculpted hair. game/scripts/characters/cast_model_presentation.gd binds the
// imported textures and colour; the motion is a slow, uneven drift, as fine hair moves in a warm room.
// Stage looks polish (Lily's ruling stage_polish_r1_20261114: "do the fringe sway").

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal = false;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic;
uniform bool use_rough = false;
uniform vec3 roughness_channel = vec3(0.0, 1.0, 0.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float sway_amplitude : hint_range(0.0, 0.03) = 0.0045;
uniform float sway_speed : hint_range(0.0, 6.0) = 1.1;

void vertex() {
	float along = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.6);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 11.0 + world.z * 7.0 + world.y * 5.0;
	float drift = sin(TIME * sway_speed + phase) + 0.45 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
	float turn = cos(TIME * sway_speed * 0.8 + phase * 1.3);
	VERTEX.x += drift * sway_amplitude * along;
	VERTEX.z += turn * sway_amplitude * 0.7 * along;
}

void fragment() {
	vec4 colour = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = use_rough ? clamp(dot(texture(rough_tex, UV).rgb, roughness_channel) * roughness, 0.0, 1.0) : roughness;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
