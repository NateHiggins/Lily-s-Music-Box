shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream_irradiance.gdshaderinc"
#include "res://shaders/dream_phase_transition.gdshaderinc"
#include "res://shaders/dream_corruption_layers.gdshaderinc"

// EN-1 LAYER PROBE — the owner's re-layered dream, as a stand-in surface that
// can be photographed one layer at a time beside the shipping Klimt filter
// (design/DREAM_ENCROACHMENT_BRIEF.md). Not production.
//
//   bit 1  BASE   the idealised Orison surface, PBR, UNWARPED: the same maps
//                 the waking building ships, lit by the real service lamp.
//   bit 2  FLESH  purplish living tissue grown from the durable exposure
//                 field: lobed patches with an edge, wine/plum cells, tendon
//                 folds, faint vessels, wet film, a wrap-lit rim, breathing
//                 below 0.1 Hz. Physically shaded — roughness, specular,
//                 normal — never a colour wash.
//   bit 4  SKIN   antique gold as a metallic SKIN with thickness over the
//                 flesh where exposure is high: beaten-leaf micro relief,
//                 torn edges that show the flesh beneath, real metallic and
//                 roughness, no emission. It reflects what is there; in the
//                 dark it is dark.
//   bit 8  WELD   the seam where the encroachment is fused to the apartment:
//                 a molten bead along the growth front, heat-gradient colour
//                 from dull red through orange to a yellow-white core, slow
//                 flow along the seam, a bulged profile. Emissive because
//                 molten metal glows; motion slow, never a flash.
//   bit 16 PORTAL at high gold phase the weld's core opens: inside it the
//                 surface shows another place. The probe samples the case's
//                 reflected-world plate by the reflection vector as a
//                 stand-in for R6's live bounded camera feed.
//
// Uniform names match the Klimt surface so DreamMazeRoot's collector pushes
// exposure_tex, lamp pose and the incarnation bundle into this material too.

uniform int layer_mask = 31;
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_tile_m : hint_range(0.1, 8.0) = 1.15;
uniform float base_rough_mul = 1.0;
uniform sampler2D reflected_world : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;

uniform sampler3D exposure_tex : filter_linear, repeat_enable, hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;
uniform float exposure_gain : hint_range(0.0, 4.0) = 1.0;
uniform vec4 phase_stage_thresholds = vec4(0.10, 0.34, 0.48, 0.78);
uniform vec2 phase_gold_thresholds = vec2(0.70, 0.92);
uniform vec3 lamp_origin = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform vec3 lamp_splash = vec3(0.0);
uniform float lamp_reach = 4.6;
uniform float lamp_cos_outer = 0.86;
uniform float lamp_energy = 1.0;

// Flesh palette: aubergine ground, wine body, plum crest. Linear, authored.
uniform vec3 flesh_deep : source_color = vec3(0.140, 0.030, 0.125);
uniform vec3 flesh_body : source_color = vec3(0.420, 0.085, 0.300);
uniform vec3 flesh_crest : source_color = vec3(0.620, 0.230, 0.470);
uniform float flesh_cell_scale = 3.2;
uniform float flesh_relief = 0.85;
uniform float flesh_breath_hz = 0.07;
// Skin: antique gold leaf.
uniform vec3 gold_leaf : source_color = vec3(0.760, 0.540, 0.205);
uniform vec3 gold_tarnish : source_color = vec3(0.300, 0.190, 0.075);
uniform float leaf_sheet_m = 0.08;
uniform float skin_roughness = 0.28;
// Weld: where along the growth drive the seam sits, and how wide.
uniform float weld_level = 0.24;
uniform float weld_width = 0.028;
uniform float weld_glow = 1.1;
uniform vec3 weld_red : source_color = vec3(0.45, 0.07, 0.02);
uniform vec3 weld_orange : source_color = vec3(0.96, 0.42, 0.08);
uniform vec3 weld_core : source_color = vec3(1.00, 0.88, 0.52);
uniform float portal_open = 0.55;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

bool layer(int bit) {
	return (layer_mask & bit) != 0;
}

// World-box projection: the dominant normal axis picks the plane, metres
// divide by the set's tile size — the builder's own rule, unwarped.
vec2 box_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return p.zy;
	return p.xy;
}

vec3 heat_colour(float t) {
	// 0 cold edge .. 1 molten core
	vec3 c = mix(weld_red, weld_orange, smoothstep(0.0, 0.55, t));
	return mix(c, weld_core, smoothstep(0.55, 1.0, t));
}

void fragment() {
	vec3 n = normalize(v_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	float ndv = clamp(dot(n, view_dir), 0.0, 1.0);
	vec2 uv = box_uv(v_world, n) / max(0.05, base_tile_m);

	// ---- exposure state -------------------------------------------------
	float field_y = clamp(v_world.y / max(0.001, exposure_height), 0.0625, 0.9375);
	vec2 field = texture(exposure_tex, vec3(v_world.x / exposure_extent,
			v_world.z / exposure_extent, field_y)).rg;
	vec4 irr = dream_irradiance(v_world, n, field, lamp_origin);
	float heat = irr.w;
	float retained = clamp(field.r * exposure_gain, 0.0, 1.0);
	// An organic edge: the front is a contour of retained exposure nudged by
	// a fixed world-space field, so it has lobes, not a radius.
	float lobes = dream_corruption_fbm3(v_world * 1.7 + 3.1) - 0.5;
	float drive = clamp(retained + lobes * 0.18 * smoothstep(0.05, 0.14, retained), 0.0, 1.0);
	vec4 phase = dream_phase_state(drive, phase_stage_thresholds, phase_gold_thresholds);

	// ---- layer 0: base ---------------------------------------------------
	vec3 albedo = vec3(0.5);
	float rough = 0.8;
	float metal = 0.0;
	float spec = 0.5;
	vec3 normal_ts = vec3(0.0, 0.0, 1.0);
	if (layer(1)) {
		albedo = texture(base_albedo, uv).rgb;
		rough = clamp(texture(base_rough, uv).r * base_rough_mul, 0.04, 1.0);
		normal_ts = texture(base_normal, uv).rgb * 2.0 - 1.0;
	}
	// Tangent frame for bending the normal in world space.
	vec3 up_ref = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tan_a = normalize(cross(up_ref, n));
	vec3 tan_b = cross(n, tan_a);
	vec3 bent = normalize(n + (tan_a * normal_ts.x + tan_b * normal_ts.y) * 0.45);
	vec3 emission = vec3(0.0);

	// ---- layer 2: flesh --------------------------------------------------
	float flesh = 0.0;
	if (layer(2)) {
		float t = TIME;
		float breath = 0.5 + 0.5 * sin(t * 6.2831853 * flesh_breath_hz + v_world.x * 0.7);
		vec3 fp = v_world * flesh_cell_scale;
		float cells = dream_corruption_cells(fp, t, 0.0);
		float folds = dream_corruption_folds(fp * 0.8, t, 0.3);
		float vessels = dream_corruption_vessels(fp * 1.4, 0.2, 0.93);
		float wet = dream_corruption_wetfilm(fp * 1.1, t, 0.1);
		// Coverage: patches appear at low drive and knit together as it rises.
		float cover_drive = smoothstep(0.10, 0.36, drive) * (0.45 + 0.55 * smoothstep(0.36, 0.80, drive));
		flesh = smoothstep(0.58 - cover_drive * 0.42, 0.64 - cover_drive * 0.42, cells * 0.7 + lobes * 0.6 + 0.3);
		flesh *= smoothstep(0.08, 0.18, drive);
		vec3 tissue = mix(flesh_deep, flesh_body, smoothstep(0.25, 0.75, cells));
		tissue = mix(tissue, flesh_crest, folds * 0.55);
		tissue = mix(tissue, flesh_deep * 0.6, vessels * 0.6);
		// Wrap-lit rim: thin tissue lets the wine through at grazing angles.
		tissue += flesh_body * pow(1.0 - ndv, 2.6) * 0.32 * (0.8 + 0.2 * breath);
		albedo = mix(albedo, tissue, flesh);
		rough = mix(rough, mix(0.55, 0.24, wet), flesh);
		spec = mix(spec, 0.62, flesh);
		// Relief from the cell/fold fields by finite difference.
		float e = 0.012;
		float c0 = dream_corruption_cells(fp, t, 0.0) + folds * 0.8;
		float cx = dream_corruption_cells(fp + vec3(e, 0.0, 0.0), t, 0.0)
				+ dream_corruption_folds((fp + vec3(e, 0.0, 0.0)) * 0.8, t, 0.3) * 0.8;
		float cy = dream_corruption_cells(fp + vec3(0.0, e, 0.0), t, 0.0)
				+ dream_corruption_folds((fp + vec3(0.0, e, 0.0)) * 0.8, t, 0.3) * 0.8;
		vec3 flesh_n = (tan_a * (cx - c0) + tan_b * (cy - c0)) * 5.0 * flesh_relief;
		bent = normalize(mix(bent, normalize(n + flesh_n), flesh));
	}

	// ---- layer 4: skin ---------------------------------------------------
	float skin = 0.0;
	if (layer(4)) {
		float leaf_field = dream_corruption_fbm3(v_world * 2.3 + 9.0);
		float skin_drive = smoothstep(0.28, 0.72, drive);
		skin = smoothstep(0.50, 0.58, leaf_field * 0.6 + skin_drive * 0.62);
		skin *= flesh;                       // a skin over flesh, never over bare plaster
		// Beaten leaf: sheets of leaf_sheet_m with per-sheet roughness and
		// a hammered micro-normal; tarnish along the torn edge.
		vec2 sheet = floor(uv * base_tile_m / leaf_sheet_m);
		float sheet_h = fract(sin(dot(sheet, vec2(127.1, 311.7))) * 43758.5453);
		float hammer = dream_corruption_noise3(v_world * 18.0);
		float edge = smoothstep(0.50, 0.64, leaf_field * 0.6 + skin_drive * 0.62);
		vec3 gold = mix(gold_tarnish, gold_leaf, 0.35 + 0.65 * edge);
		gold *= 0.97 + 0.03 * sheet_h;
		albedo = mix(albedo, gold, skin);
		metal = mix(metal, 1.0, skin);
		rough = mix(rough, skin_roughness + 0.06 * sheet_h + 0.05 * hammer, skin);
		spec = mix(spec, 0.9, skin);
		float he = 0.02;
		float h0 = dream_corruption_noise3(v_world * 18.0);
		float hx = dream_corruption_noise3((v_world + tan_a * he) * 18.0);
		float hy = dream_corruption_noise3((v_world + tan_b * he) * 18.0);
		vec3 skin_n = (tan_a * (hx - h0) + tan_b * (hy - h0)) * 0.5;
		bent = normalize(mix(bent, normalize(n + skin_n), skin));
	}

	// ---- layer 8: weld ---------------------------------------------------
	float bead = 0.0;
	if (layer(8)) {
		float d = (drive - weld_level) / max(0.005, weld_width);
		bead = exp(-d * d);
		// Slow flow along the seam: the bead's brightness and profile drift.
		float along = dream_corruption_fbm3(v_world * 3.3 + vec3(TIME * 0.08, 0.0, -TIME * 0.05));
		float core = bead * (0.70 + 0.30 * along);
		vec3 hc = heat_colour(core);
		albedo = mix(albedo, hc * 0.25, bead);
		metal = mix(metal, 1.0, bead);
		rough = mix(rough, 0.12, bead);
		spec = mix(spec, 0.95, bead);
		// A bulged bead profile: the normal tilts away from the seam centre.
		float pulse = 0.92 + 0.08 * sin(TIME * 0.63 + v_world.y * 2.0);
		emission += hc * core * weld_glow * pulse;
		float be = 0.03;
		float dx = (texture(exposure_tex, vec3((v_world.x + be * tan_a.x) / exposure_extent,
				(v_world.z + be * tan_a.z) / exposure_extent, field_y)).r - field.r);
		float dy = (texture(exposure_tex, vec3((v_world.x + be * tan_b.x) / exposure_extent,
				(v_world.z + be * tan_b.z) / exposure_extent, field_y)).r - field.r);
		vec3 bulge = (tan_a * dx + tan_b * dy) * sign(drive - weld_level) * 60.0 * bead;
		bent = normalize(mix(bent, normalize(n - bulge), bead * 0.8));
	}

	// ---- layer 16: portal core ------------------------------------------
	if (layer(16)) {
		float open = bead * smoothstep(portal_open - 0.12, portal_open + 0.12, phase.z + drive * 0.3)
				* smoothstep(0.55, 0.9, bead);
		vec3 r = reflect(-view_dir, bent);
		float ang = TIME * 0.04;
		vec3 rr = vec3(r.x * cos(ang) - r.z * sin(ang), r.y, r.x * sin(ang) + r.z * cos(ang));
		vec2 eq = vec2(atan(rr.z, rr.x) / 6.2831853 + 0.5, acos(clamp(rr.y, -1.0, 1.0)) / 3.14159265);
		vec3 elsewhere = texture(reflected_world, eq).rgb;
		albedo = mix(albedo, elsewhere * 0.6, open);
		emission = mix(emission, elsewhere * 1.4, open);
		metal = mix(metal, 0.0, open);
		rough = mix(rough, 0.5, open);
	}

	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = (VIEW_MATRIX * vec4(bent, 0.0)).xyz;
	EMISSION = emission;
}
