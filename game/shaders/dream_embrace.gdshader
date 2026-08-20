shader_type spatial;
render_mode cull_front, depth_draw_opaque, unshaded;

#include "res://shaders/dream_corruption_layers.gdshaderinc"

// A single inward-facing shell around the existing player camera. Fragment
// coverage advances from every screen edge toward the centre; no directional
// limb, attacker or cut-to-black enters the frame.
uniform float close_amount : hint_range(0.0, 1.0) = 0.0;
uniform float biological_afterglow : hint_range(0.0, 0.35) = 0.27;
uniform float lamp_enabled : hint_range(0.0, 1.0) = 1.0;
uniform int debug_view : hint_range(0, 2) = 0;

varying vec3 v_local;


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


void vertex() {
	v_local = VERTEX;
}


void fragment() {
	vec2 centred = SCREEN_UV * 2.0 - 1.0;
	vec2 square_uv = abs(centred);
	float from_edge = max(square_uv.x, square_uv.y);
	float angle = atan(centred.y, centred.x);
	float slow_fold = sin(angle * 5.0 + close_amount * 2.1) * 0.030
			+ sin(angle * 9.0 - close_amount * 1.3) * 0.014;
	float coarse = value_noise(vec2(angle * 1.27, close_amount * 2.0))
			* 0.025 - 0.0125;
	float frontier = 1.035 - close_amount * 1.13 + slow_fold + coarse;
	float coverage = smoothstep(frontier - 0.012, frontier + 0.012,
			from_edge);
	if (coverage < 0.5) {
		discard;
	}

	// Multi-scale, domain-warped flesh with narrow metallic stress vessels.
	// Every field is evaluated in local 3D, so it wraps the inward sphere with
	// no polar or UV seam and carries the same visual genome as the room growth.
	vec3 p = normalize(v_local) * 8.2;
	float phase = 0.37;
	float cells = dream_corruption_cells(p * 0.74, TIME, phase);
	float folds = dream_corruption_folds(p * 0.52, TIME, phase + 0.17);
	float microfold = dream_corruption_folds(p * 1.29, TIME * 0.73,
			phase + 0.61);
	float wetfilm = dream_corruption_wetfilm(p * 0.82, TIME, phase);
	// The shared long-vessel function is excellent on limbs but its three
	// directional wave families disclose a coordinate grid when viewed from
	// inside a sphere. Here capillaries follow warped cell boundaries instead.
	float cell_edge = 1.0 - smoothstep(0.045, 0.155,
			abs(cells - 0.52));
	float folded_branch = smoothstep(0.68, 0.96, microfold)
			* smoothstep(0.22, 0.82, folds);
	float vein = clamp(cell_edge * 0.82 + folded_branch * 0.34, 0.0, 1.0);
	float height = cells * 0.27 + folds * 0.51 + microfold * 0.22;

	vec3 deep_plum = vec3(0.018, 0.0015, 0.035);
	vec3 bruise_violet = vec3(0.150, 0.012, 0.190);
	vec3 warm_tissue = vec3(0.320, 0.025, 0.120);
	// This surface sits less than a metre from the real service lamp. It is a
	// capture envelope, not ordinary room geometry, so it owns its exposure:
	// the player's switch reveals burnished metal without the singular near-
	// light response bleaching the whole interior to parchment.
	vec3 old_gold = vec3(0.060, 0.018, 0.0015);
	vec3 warm_gold = vec3(0.460, 0.160, 0.012);
	vec3 pale_leaf = vec3(0.950, 0.550, 0.080);
	vec3 tissue = mix(deep_plum, bruise_violet, 0.18 + cells * 0.66);
	tissue = mix(tissue, warm_tissue, folds * 0.24 + microfold * 0.11);
	tissue *= 0.56 + height * 0.58;
	vec3 leaf = mix(old_gold, warm_gold, 0.42 + cells * 0.36);
	leaf = mix(leaf, pale_leaf, wetfilm * 0.28);
	float gold_mask = clamp(vein * 0.64 + folds * cells * 0.10,
			0.0, 1.0);
	vec3 body = mix(tissue, leaf, gold_mask);

	// When the player has deliberately extinguished the lamp, the interior is
	// the Tenant's body rather than self-lit metal: a faint wine/plum biological
	// warmth remains, with only a trace along the vessel turns.
	vec3 dark_body = mix(vec3(0.12, 0.006, 0.044),
			vec3(0.28, 0.030, 0.135), cells * 0.58 + folds * 0.28);
	vec3 biological_glow = (dark_body
			* (0.54 + wetfilm * 0.32 + microfold * 0.14)
			+ old_gold * vein * 0.18) * biological_afterglow * 3.0;
	float lamp_pool = 0.40 + (1.0 - smoothstep(0.06, 1.22,
			length(centred))) * 0.46;
	vec3 wet_glint = pale_leaf * pow(wetfilm, 3.0)
			* (0.08 + gold_mask * 0.24);
	vec3 lamp_reveal = body * (1.10 + lamp_pool * 0.90)
			+ wet_glint * 1.40;
	ALBEDO = mix(biological_glow, lamp_reveal, lamp_enabled);
	EMISSION = vec3(0.0);

	if (debug_view == 1) {
		ALBEDO = vec3(coverage, 0.0, 1.0 - coverage);
	} else if (debug_view == 2) {
		ALBEDO = vec3(close_amount);
	}
}
