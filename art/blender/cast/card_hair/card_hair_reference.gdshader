shader_type spatial;
// Clump-card hair: cut-out with depth and soft (coverage) edges, both faces
// drawn with the underside darker, a highlight band across the flow, and the
// outer third of every card swaying with the head. No sorting, no new bones.
render_mode cull_disabled, depth_draw_opaque, alpha_to_coverage;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float underside : hint_range(0.0, 1.0) = 0.62;
uniform float cut : hint_range(0.0, 1.0) = 0.42;
// Model-space push from the head's own motion, set by whoever moves the head.
uniform vec3 sway = vec3(0.0);
uniform float breeze : hint_range(0.0, 0.02) = 0.0025;
uniform bool is_cap = false;
// The cap as visible short hair: how dark it is, and how far its edge breaks into strands (0 = a clean edge).
uniform float cap_shade : hint_range(0.0, 1.5) = 0.55;
uniform float cap_feather : hint_range(0.0, 1.0) = 0.0;
uniform float cap_bald : hint_range(0.0, 1.0) = 0.0;
// The whole head of hair is lit as one rounded mass, so cards do not read as separate planks.
uniform vec3 hair_centre = vec3(0.0, 1.345, 0.04);
uniform float roundness : hint_range(0.0, 1.0) = 0.0;
// Dark hair is seen by its shine: 0 is matt, 1 is glossy.
uniform float gloss : hint_range(0.0, 1.0) = 0.15;

void vertex() {
	if (roundness > 0.0) {
		// Below the skull the centre follows the hair down, so hanging hair is lit from its outside.
		vec3 from = vec3(hair_centre.x, min(hair_centre.y, VERTEX.y + 0.02), hair_centre.z);
		vec3 outward = normalize(VERTEX - from);
		// A card wound to face the head has a normal opposite to the outward one; mixing the two as they stand
		// cancels and leaves a normal pointing at the floor, which draws a dark band round hanging hair.
		vec3 own = dot(NORMAL, outward) < 0.0 ? -NORMAL : NORMAL;
		NORMAL = normalize(mix(own, outward, roundness));
	}
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
	if (roundness > 0.0 && !FRONT_FACING) {
		// The rounded normal already points out of the head; a card seen from behind must not turn it inward.
		NORMAL = -NORMAL;
	}
	ALBEDO = tone.rgb * (FRONT_FACING ? 1.0 : underside) * (is_cap ? cap_shade : 1.0);
	ROUGHNESS = texture(rough_tex, UV).r * mix(1.0, 0.92, gloss);
	SPECULAR = mix(0.14, 0.22, gloss);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.3;
	// Keep thin tips from dissolving in the far mip levels. The cap is solid:
	// it must say so, or coverage treats it as see-through.
	float level = textureQueryLod(albedo_tex, UV).y;
	float solid = 1.0;
	if (is_cap && cap_feather > 0.0) {
		// UV2 runs round the head in x and crown (0) to edge (1) in y. Each narrow column of hair ends at its own length.
		float column = floor(UV2.x * 340.0);
		float chance = fract(sin(column * 12.9898) * 43758.5453);
		// Locks of hair end together, but one lock runs into the next: stepped lengths would draw a hairline of square teeth.
		float lock = UV2.x * 46.0;
		float here = fract(sin(floor(lock) * 78.233) * 12543.123);
		float next = fract(sin((floor(lock) + 1.0) * 78.233) * 12543.123);
		float bunch = mix(here, next, smoothstep(0.0, 1.0, fract(lock)));
		float ends = 1.0 - cap_feather * 0.24 * (0.15 + 0.5 * chance + 0.35 * bunch);
		solid = clamp((ends - UV2.y) * 60.0 + 0.5, 0.0, 1.0);
		// A bare crown: the hair's upper edge thins out the same way.
		float begins = cap_bald * cap_feather * 0.3 * (0.2 + 0.5 * bunch + 0.3 * chance);
		solid *= clamp((UV2.y - begins) * 60.0 + 0.5, 0.0, 1.0);
	}
	ALPHA = is_cap ? solid : clamp(tone.a * (1.0 + 0.35 * level), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = cut;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0));
}
