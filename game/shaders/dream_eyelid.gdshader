shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE LIDS (DIRECTION_2 §C5, DIRECTION_3 §I) — three of them, on three
// anatomical vectors, each a real shell with thickness rather than a card.
//
// A lid is the same tissue as the limb, but thin: it scatters hard, it is
// wet on its inner margin, and it carries its own vasculature. The third
// lid (the nictitating membrane) is thinner still and partly translucent —
// pale violet with gold vascular filaments and a pearlescent sheen, with a
// small muscular leading edge.
//
// Local space: the lid is a curved shell whose +y is out of the orbit and
// whose UV.x runs along its sweep, UV.y from its root (0) to its margin (1).
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

// 0 dorsal flesh lid, 1 ventral/lateral flesh lid, 2 nictitating membrane.
uniform int lid_kind = 0;
uniform float closure : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform vec3 membrane_tint : source_color = vec3(0.52, 0.36, 0.60);
uniform vec3 membrane_filament : source_color = vec3(0.86, 0.70, 0.34);

varying vec2 v_uv;
varying vec3 v_world;
varying float v_margin;

void vertex() {
	v_uv = UV;
	// The margin: the free edge of the lid. It compresses when closed —
	// tissue has to go somewhere.
	float margin = smoothstep(0.72, 1.0, UV.y);
	v_margin = margin;
	vec3 p = VERTEX;
	// Compression: the closed lid thickens toward its margin and the whole
	// shell bows a little out of the orbit.
	p.y += margin * closure * 0.16;
	p *= 1.0 + closure * 0.03 * margin;
	VERTEX = p;
	v_world = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float lod = 1.0;
	// A lid is a membrane: thin everywhere, thinnest at its free margin.
	// The nictitating lid is thinner than either flesh lid.
	float base_thickness = lid_kind == 2 ? 0.06 : 0.30;
	float thickness = clamp(base_thickness * (1.0 - v_margin * 0.8), 0.0, 1.0);
	DeCtx ctx;
	ctx.thickness = thickness;
	ctx.vein = 0.0;
	ctx.contact = 0.0;
	ctx.gold_root = 0.0;
	// The inner margin is always wet.
	ctx.socket = v_margin * 0.9;
	ctx.stretch = 0.4 + 0.5 * closure;
	ctx.lod = lod;
	DeMasks m = de_masks(v_world, v_uv, n, view_dir, TIME, seed, ctx);
	// No mineral on a lid: it has to fold.
	m.gold = 0.0;
	m.mineral = 0.0;
	DeOut o = de_shade(m, v_world, v_uv, n, view_dir, TIME, seed, ctx);
	if (lid_kind == 2) {
		// The nictitating membrane: pale violet tissue with fine gold
		// vascular filaments, faintly pearlescent, and genuinely
		// translucent — the eye stays readable through it.
		float filaments = dream_corruption_vessels(vec3(v_uv * vec2(9.0, 22.0), seed), 0.85, 0.94);
		vec3 tissue = membrane_tint * (0.7 + 0.4 * dream_corruption_fbm3(v_world * 30.0 + seed));
		tissue = mix(tissue, membrane_filament, smoothstep(0.5, 0.85, filaments) * 0.75);
		float ndv = clamp(dot(n, view_dir), 0.0, 1.0);
		float pearl = pow(1.0 - ndv, 2.5);
		o.albedo = mix(tissue, tissue * 1.4 + vec3(0.10, 0.08, 0.14), pearl * 0.5);
		o.roughness = 0.22;
		o.clearcoat = 0.9;
		o.clearcoat_roughness = 0.06;
		o.sss = 0.95;
		o.sss_transmit = vec4(membrane_tint * 1.3, 1.0);
		o.sss_depth = 0.0015;
		o.metallic = 0.0;
		// The leading edge is a small muscular thickening, opaque.
		float lead = smoothstep(0.90, 1.0, v_uv.y);
		o.albedo = mix(o.albedo, membrane_tint * 0.45, lead);
		o.sss = mix(o.sss, 0.3, lead);
		ALPHA = mix(0.62, 0.95, lead + pearl * 0.4);
	} else {
		// A flesh lid: wet inside, and the closed margin compresses into a
		// pale, bloodless line — tissue under pressure.
		float pinch = v_margin * closure;
		o.albedo = mix(o.albedo, o.albedo * 1.25 + vec3(0.03, 0.01, 0.02), pinch * 0.5);
		o.roughness = mix(o.roughness, 0.16, v_margin * 0.7);
		o.clearcoat = max(o.clearcoat, v_margin * 0.8);
		ALPHA = 1.0;
	}
	ALBEDO = o.albedo;
	METALLIC = o.metallic;
	ROUGHNESS = o.roughness;
	SPECULAR = o.specular;
	EMISSION = o.emission;
	BACKLIGHT = o.backlight;
	AO = o.ao;
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.7 + BINORMAL * nm.y * 0.7);
}
