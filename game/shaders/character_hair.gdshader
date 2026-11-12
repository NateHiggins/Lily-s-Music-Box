shader_type spatial;
// Clump-card hair: cut-out with depth and soft (coverage) edges, both faces
// drawn with the underside darker, a highlight band across the flow, and the
// outer third of every card swaying with the head. No sorting, no new bones.
render_mode cull_disabled, depth_draw_opaque, alpha_to_coverage;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_disable;
// Raw authoring maps use R; imported glTF metallic-roughness maps use G.
uniform vec3 roughness_channel = vec3(1.0, 0.0, 0.0);
uniform float underside : hint_range(0.0, 1.0) = 0.62;
uniform float cut : hint_range(0.0, 1.0) = 0.42;
// Model-space push from the head's own motion, set by whoever moves the head.
uniform vec3 sway = vec3(0.0);
uniform float breeze : hint_range(0.0, 0.02) = 0.0025;
uniform bool is_cap = false;

void vertex() {
	if (!is_cap) {
		// UV2.y runs 0 at the root to 1 at the tip: the roots are pinned and
		// only the outer third of a card moves.
		float tip = smoothstep(0.62, 1.0, UV2.y);
		float phase = VERTEX.x * 37.0 + VERTEX.z * 29.0;
		VERTEX += (sway + vec3(sin(TIME * 1.7 + phase), 0.0, cos(TIME * 1.3 + phase * 1.3)) * breeze) * tip;
	}
}

void fragment() {
	vec4 tone = texture(albedo_tex, UV);
	ALBEDO = tone.rgb * (FRONT_FACING ? 1.0 : underside) * (is_cap ? 0.55 : 1.0);
	ROUGHNESS = dot(texture(rough_tex, UV).rgb, roughness_channel);
	SPECULAR = 0.22;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.4;
	ANISOTROPY = 0.4;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	// Keep thin tips from dissolving in the far mip levels. The cap is solid:
	// it must say so, or coverage treats it as see-through.
	float level = textureQueryLod(albedo_tex, UV).y;
	ALPHA = is_cap ? 1.0 : clamp(tone.a * (1.0 + 0.35 * level), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = cut;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0));
}
