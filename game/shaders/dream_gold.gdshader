shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// THE GOLD SKELETON (DIRECTION_2 §B7–B8, DIRECTION_3 §E) — living
// biomineral, not jewellery. True metal, with roughness varied at several
// scales so the highlight reveals HOW EACH PIECE GREW:
//
//   * polished contact ridges where plates bear on each other
//   * satin along the growth direction (anisotropic, flowed)
//   * crystalline grain across it
//   * rough fracture in the recesses and at the buried ends
//
// The seams that glow are JOINTS AND GROWTH FRONTS, never lava: the light
// lives at a plate's rim and brightens when the plate moves
// (INSTANCE_CUSTOM.r carries that motion from the skeleton controller).
#include "res://shaders/dream_corruption_layers.gdshaderinc"

uniform vec3 gold : source_color = vec3(0.90, 0.70, 0.32);
uniform vec3 gold_deep : source_color = vec3(0.42, 0.27, 0.09);
uniform vec3 gold_hot : source_color = vec3(1.0, 0.62, 0.18);
uniform float seed = 0.0;
uniform bool is_dendrite = false;
// How much this piece is moving right now: the seam under a moving plate
// brightens and dims as it reseats (§B8, HERO_PASS §3).
uniform float motion : hint_range(0.0, 1.0) = 0.0;
uniform bool debug_gray = false;

varying vec2 v_uv;
varying vec3 v_local;
varying vec3 v_world;
varying float v_motion;
varying float v_piece;

void vertex() {
	v_uv = UV;
	v_local = VERTEX;
	v_motion = is_dendrite ? INSTANCE_CUSTOM.r : motion;
	v_piece = INSTANCE_CUSTOM.g;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_uv;
	// How far into the flesh this fragment is: the plate's ends and the
	// dendrite's base are buried, and buried metal is dull and dark.
	float buried = is_dendrite
			? smoothstep(0.25, -0.15, v_local.y)
			: smoothstep(0.12, -0.35, v_local.y);
	// Growth direction: along the piece (uv.y). The satin follows it.
	float grain_along = dream_corruption_fbm3(vec3(uv * vec2(3.0, 26.0), seed));
	float grain_across = dream_corruption_fbm3(vec3(uv * vec2(30.0, 2.0), seed + 5.0));
	// Crystal facets in the metal itself.
	float facets = dream_corruption_cells(vec3(uv * 14.0, seed), 0.0, 0.4);
	// The crown wears polished; the flanks stay satin; the recesses are rough.
	float crown = smoothstep(0.35, 0.9, v_local.y + 0.35);
	float rough = mix(0.46, 0.13, crown);
	rough += 0.16 * (grain_across - 0.5);
	rough -= 0.10 * smoothstep(0.55, 0.85, facets);
	rough = mix(rough, 0.62, buried);
	vec3 albedo = mix(gold, gold_deep, buried * 0.8);
	albedo *= 0.80 + 0.28 * grain_along;
	albedo = mix(albedo, gold * 1.08, smoothstep(0.6, 0.95, facets) * (1.0 - buried) * 0.5);
	// The seam: the rim of the piece, brightening as it moves (§B8). It is
	// a line of light in a joint, not a crack in lava.
	float rim = is_dendrite
			? smoothstep(0.75, 1.0, uv.y)
			: max(smoothstep(0.86, 1.0, abs(uv.x * 2.0 - 1.0)), smoothstep(0.88, 1.0, abs(uv.y * 2.0 - 1.0)));
	float joint = rim * (0.12 + 0.88 * v_motion) * (1.0 - buried);
	ALBEDO = albedo;
	METALLIC = mix(1.0, 0.45, buried);
	ROUGHNESS = clamp(rough, 0.05, 0.9);
	SPECULAR = 0.85;
	// Anisotropy along the growth direction: the highlight stretches the
	// way the mineral grew (§B7).
	// Enough to show the growth direction, not enough to smear the metal
	// into a pale ribbon.
	ANISOTROPY = mix(0.30, 0.08, buried);
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	EMISSION = gold_hot * joint * 0.9;
	// Contact darkness where it enters tissue.
	AO = 1.0 - buried * 0.5;
	AO_LIGHT_AFFECT = 0.4;
	if (debug_gray) {
		ALBEDO = vec3(0.55);
		METALLIC = 0.0;
		ROUGHNESS = 0.45;
		EMISSION = vec3(0.0);
		ANISOTROPY = 0.0;
	}
}
