// DREAM ENTITY SURFACE — the hero material for Dream anatomy.
// DIRECTION_2 §A–§B, DIRECTION_3 §A–§E. **Forward+ only.**
//
// The model is DENSE MEAT WITH A MICROSCOPIC FLUID FILM. Six things must
// stay separable under a moving flashlight (DIRECTION_3 §L):
//
//   1. an opaque, moderately rough purple surface layer
//   2. real subsurface transport under it, driven by THICKNESS, tending to
//      crimson–fuchsia where the tissue is thin (SSS_* outputs, sss_mode_skin)
//   3. mesostructure — vascular branching, cords, striation, nodules —
//      revealed because light travels through the tissue around it
//   4. three independent normal scales (anatomical folds / tissue creases /
//      pores), so the skin holds at macro and at gameplay distance
//   5. an irregular oil film ON TOP as clearcoat, with its OWN normal
//   6. gold as biomineral: an irregular grown field with a mineralizing
//      transition, never a band and never a coat
//
// plus sparse iridophore structural colour under the skin (the cephalopod
// principle, not the anatomy) and a papilla field the organism can raise.
//
// Host contract: include after `dream_corruption_layers.gdshaderinc`; build
// a DeCtx from the host's own anatomy, then
//   DeMasks m = de_masks(pw, uv, n, view_dir, time, seed, ctx);
//   DeOut o = de_shade(m, pw, uv, n, view_dir, time, seed, ctx);
// and write o.* to the outputs (including SSS_*, CLEARCOAT*, and the film
// normal via a second NORMAL_MAP pass — see `de_film_normal`).

group_uniforms dream_flesh;
uniform vec3 flesh_deep : source_color = vec3(0.048, 0.011, 0.062);
uniform vec3 flesh_body : source_color = vec3(0.205, 0.045, 0.170);
uniform vec3 flesh_crest : source_color = vec3(0.372, 0.112, 0.290);
uniform vec3 flesh_perfusion : source_color = vec3(0.480, 0.075, 0.180);
uniform float macro_m = 0.28;      // metres: anatomical masses
uniform float meso_m = 0.055;      // metres: vascular clouds, compartments
uniform float micro_m = 0.0028;    // metres: pores
uniform float submicro_m = 0.0018; // metres: roughness break-up only
uniform float normal_anatomical : hint_range(0.0, 3.0) = 1.0;
uniform float normal_tissue : hint_range(0.0, 3.0) = 1.0;
uniform float normal_pore : hint_range(0.0, 3.0) = 1.0;
uniform float flesh_roughness : hint_range(0.0, 1.0) = 0.54;
uniform float iridophore : hint_range(0.0, 1.0) = 0.40;
uniform float papilla : hint_range(0.0, 1.0) = 0.5;
group_uniforms;

group_uniforms dream_sss;
uniform float sss_amount : hint_range(0.0, 1.0) = 0.75;
// Blood, not wax. Deep transmit is what survives thick tissue; thin
// transmit is the fuchsia that only appears where the tissue is a
// membrane.
uniform vec3 sss_transmit_deep : source_color = vec3(0.42, 0.030, 0.055);
uniform vec3 sss_transmit_thin : source_color = vec3(0.92, 0.115, 0.255);
uniform float sss_depth_m = 0.006;
uniform float sss_boost : hint_range(0.0, 1.0) = 0.20;
group_uniforms;

group_uniforms dream_film;
uniform float wetness : hint_range(0.0, 1.0) = 0.75;
uniform float film_roughness : hint_range(0.0, 0.5) = 0.14;
// The film has its own drift, so it does not move with the flesh (§C).
uniform float film_drift = 0.035;
group_uniforms;

group_uniforms dream_gold;
uniform vec3 gold : source_color = vec3(0.859, 0.659, 0.298);
uniform vec3 gold_hot : source_color = vec3(1.0, 0.620, 0.180);
uniform float gold_mineralization : hint_range(0.0, 1.0) = 0.22;
uniform float gold_emission : hint_range(0.0, 3.0) = 0.9;
uniform float gold_flow : hint_range(0.0, 1.0) = 0.08;
group_uniforms;

group_uniforms dream_state;
// §E of DIRECTION_2: one organism, several clocks. `pulse_phase` is the
// vascular clock and deliberately does NOT share a period with breath,
// blink, gold or crystal.
uniform float attention : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_phase : hint_range(0.0, 1.0) = 0.0;
uniform float breath_phase : hint_range(0.0, 1.0) = 0.0;
uniform float startle : hint_range(0.0, 1.0) = 0.0;
uniform float dream_phase : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

group_uniforms dream_debug;
uniform bool debug_gray = false;
uniform bool dbg_macro = true;
uniform bool dbg_meso = true;
uniform bool dbg_pores = true;
uniform bool dbg_sss = true;
uniform bool dbg_wetness = true;
uniform bool dbg_iridophore = true;
uniform bool dbg_gold = true;
uniform bool dbg_gold_emission = true;
uniform bool dbg_papilla = true;
uniform bool dbg_vascular = true;
group_uniforms;

// What the host knows about its own anatomy at this point.
// The world-space size of one pixel here. Any detail finer than this
// aliases into glitter, so every fine field is faded against it rather
// than against distance — the honest measure, and it works at any FOV,
// any resolution and any camera speed. Fragment stage only.
float de_pixel_m(vec3 pw) {
	return length(vec3(fwidth(pw.x), fwidth(pw.y), fwidth(pw.z)));
}

// 1 where a feature of this size is comfortably larger than a pixel, 0
// where it is at or below one.
float de_resolvable(float feature_m, float pixel_m) {
	return smoothstep(1.0, 3.0, feature_m / max(1e-6, pixel_m));
}

struct DeCtx {
	float thickness;  // 0 = membrane (lid, stretched skin, tip) .. 1 = muscular root
	float vein;       // the host's hero vein relief
	float contact;    // contact activity
	float gold_root;  // a mineral penetration site: scarred, compressed flesh
	float socket;     // an orbital / follicle socket: deep, wet, thin
	float stretch;    // skin under tension (iridophores show)
	float lod;        // 1 near .. 0 far
};

struct DeMasks {
	float gold;
	float mineral;
	float seam;
	float vein;
	float vascular;   // the meso vascular field, seen THROUGH tissue
	float pulse;
	float wet;
	float pore;
	float papilla;
	float irid;
	float thickness;
	float lod;
};

struct DeOut {
	vec3 albedo;
	float metallic;
	float roughness;
	float specular;
	vec3 emission;
	vec3 backlight;
	float sss;
	vec4 sss_transmit;
	float sss_depth;
	float sss_boost;
	float clearcoat;
	float clearcoat_roughness;
	vec3 normal_map;
	float ao;
};

// -------------------------------------------------------------- helpers

// A domain warp, so nothing reads as axis-aligned procedural noise.
vec3 de_warp(vec3 p, float amount, float seed) {
	return p + vec3(
		dream_corruption_fbm3(p * 0.7 + seed) - 0.5,
		dream_corruption_fbm3(p * 0.7 + seed + 11.3) - 0.5,
		dream_corruption_fbm3(p * 0.7 + seed + 23.1) - 0.5) * amount;
}

// Mesostructure (§A): vascular branching at two scales, fibrous cords
// running along the anatomy, and denser nodules. Colour and transport, not
// relief — light reaches it through the tissue above.
float de_vascular(vec3 p, vec2 uv, float seed) {
	vec3 w = de_warp(p * 1.6, 0.55, seed + 3.0);
	float big = dream_corruption_vessels(w * 1.1, 0.55, 0.88);
	float fine = dream_corruption_vessels(w * 3.7 - seed, 0.75, 0.93);
	// Cords: elongated along the limb's axis (uv.y), not isotropic.
	float cords = pow(abs(sin(uv.x * 21.0 + dream_corruption_fbm3(w * 0.8) * 7.0)), 6.0)
			* smoothstep(0.0, 0.3, uv.y);
	float nodules = smoothstep(0.72, 0.9, dream_corruption_cells(w * 2.4, 0.0, seed));
	return clamp(big * 0.75 + fine * 0.5 + cords * 0.25 + nodules * 0.4, 0.0, 1.0);
}

// Pores and follicle pits: small pits, large flats. Skin, not sponge.
float de_pores(vec3 p, float seed) {
	float c = dream_corruption_cells(p, 0.0, seed * 0.1);
	float pit = smoothstep(0.52, 0.10, c);
	return pit * (0.6 + 0.4 * dream_corruption_noise3(p * 3.1 + seed));
}

// The microscopic mineral class (§B1): flecks and dendritic grain crowding
// toward a root, so flesh → mineralizing flesh → crystal → solid metal.
float de_mineral_grain(vec3 p, float root, float seed) {
	if (root < 0.001) {
		return 0.0;
	}
	// Grains at a size the eye reads as crystal, not glitter: coarse cells
	// and a dendritic front, both gated hard on how close the root is.
	float grains = dream_corruption_cells(p * 13.0, 0.0, seed);
	float flecks = smoothstep(0.68, 0.90, grains);
	float dendrite = dream_corruption_vessels(p * 6.0 + seed * 2.0, 0.9, 0.93);
	return clamp(flecks * 0.5 + smoothstep(0.5, 0.85, dendrite) * 0.85, 0.0, 1.0)
			* smoothstep(0.08, 0.7, root);
}

// A restrained spectral set for the iridophores: violet, plum, green-gold,
// copper, rose. Never a full rainbow.
vec3 de_iridescence(float t) {
	vec3 c0 = vec3(0.34, 0.19, 0.50);
	vec3 c1 = vec3(0.28, 0.40, 0.29);
	vec3 c2 = vec3(0.70, 0.56, 0.25);
	vec3 c3 = vec3(0.60, 0.29, 0.38);
	float x = fract(t) * 4.0;
	vec3 c = mix(c0, c1, clamp(x, 0.0, 1.0));
	c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
	c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
	return mix(c, c0, clamp(x - 3.0, 0.0, 1.0));
}

DeMasks de_masks(vec3 pw, vec2 uv, vec3 n, vec3 view_dir, float time, float seed, DeCtx ctx) {
	DeMasks m;
	m.lod = ctx.lod;
	m.vein = clamp(ctx.vein, 0.0, 1.0);
	m.thickness = clamp(ctx.thickness, 0.0, 1.0);
	// The vascular clock: a pressure wave travelling along the anatomy.
	m.pulse = pow(0.5 + 0.5 * sin((uv.y * 4.0 - pulse_phase * 6.2831853)), 4.0);
	m.vascular = dbg_vascular ? de_vascular(pw, uv, seed) : 0.0;
	// --- gold as biomineral (§B, §E) -------------------------------------
	// SPARSE BY CONSTRUCTION. The first pass SUMMED two already-broad noise
	// thresholds, so `grown` saturated and the whole limb turned to metal.
	// `gold_mineralization` is now an AREA FRACTION: the mask keeps only the
	// top of the field, and the field itself is a single ridged structure.
	// PLATE-SCALE, not speckle-scale. The previous field was high frequency,
	// so its sparse top was a scatter of pinpoints — read as glitter, which
	// is the one thing flesh never does. 5–15 cm structures, soft-edged.
	vec3 gp = de_warp(pw * 0.55, 0.5, seed + 31.0) - vec3(0.0, time * gold_flow * 0.05, 0.0);
	float ridge = dream_corruption_vessels(gp * 0.9 + seed, 0.6, 0.86);
	float clumps = dream_corruption_cells(gp * 0.8, 0.0, seed * 0.3);
	float cut = mix(0.92, 0.55, clamp(gold_mineralization, 0.0, 1.0));
	float grown = smoothstep(cut, cut + 0.22, ridge)
			* smoothstep(0.45, 0.80, clumps);
	// A root is where METAL COMES THROUGH — the solid metal there is
	// geometry. What the flesh shows is the mineralizing transition: a
	// stain of metal in tissue, never a plating of it.
	m.gold = dbg_gold ? clamp(grown * 0.85 + ctx.gold_root * 0.18, 0.0, 1.0) : 0.0;
	// The mineral transition belongs to REAL roots — where the skeleton's
	// geometry comes through — not to every patch of the shader's field.
	m.mineral = de_mineral_grain(pw, ctx.gold_root, seed);
	// Seams are joints and growth fronts: the boundary of the gold field.
	float edge = m.gold * (1.0 - m.gold) * 4.0;
	m.seam = clamp(edge * 0.85 + m.mineral * 0.2, 0.0, 1.0);
	// --- skin -------------------------------------------------------------
	float pixel_m = de_pixel_m(pw);
	m.pore = dbg_pores
			? de_pores(pw / max(0.0002, micro_m), seed) * de_resolvable(micro_m, pixel_m) : 0.0;
	float pap_field = dream_corruption_cells(de_warp(pw * 7.0, 0.45, seed + 5.0), 0.0, seed);
	m.papilla = dbg_papilla
			? smoothstep(0.64, 0.86, pap_field) * papilla * (0.2 + 0.8 * attention) : 0.0;
	// --- the film (§C) ----------------------------------------------------
	// Beads, smears, dry islands; pooled in creases, sockets, the gold
	// boundary and at contact. Its own slow drift.
	vec3 fp = de_warp(pw * 5.0 + vec3(0.0, time * film_drift, 0.0), 0.5, seed + 9.0);
	float sheet = smoothstep(0.40, 0.70, dream_corruption_fbm3(fp));
	float beads = smoothstep(0.70, 0.88, dream_corruption_cells(fp * 6.0, 0.0, seed + 2.0));
	float dry = smoothstep(0.30, 0.10, dream_corruption_fbm3(fp * 0.5 + 4.0));
	m.wet = dbg_wetness ? wetness * clamp(
			(0.18 + 0.55 * sheet + 0.5 * beads) * (1.0 - dry * 0.8)
			+ 0.5 * ctx.socket + 0.4 * edge + 0.5 * ctx.contact, 0.0, 1.0) : 0.0;
	// --- iridophores (§A8) ------------------------------------------------
	float ndv = clamp(dot(n, view_dir), 0.0, 1.0);
	float graze = pow(1.0 - ndv, 3.0);
	float patches = smoothstep(0.70, 0.88,
			dream_corruption_cells(de_warp(pw * 3.2, 0.6, seed + 17.0), 0.0, seed * 2.0));
	m.irid = dbg_iridophore ? iridophore * patches * graze
			* (0.3 + 0.4 * ctx.stretch + 0.35 * attention + 0.35 * m.gold) : 0.0;
	return m;
}

// The film's own normal (§C): a second, high-frequency field that does NOT
// share the flesh's warp or drift, so the two do not move together. The
// host writes this after the base pass.
vec3 de_film_normal(vec3 pw, float time, float seed, float wet) {
	if (wet < 0.02) {
		return vec3(0.0, 0.0, 1.0);
	}
	// The film's own scale is 4 mm; below a pixel it is gloss, not beads.
	float fade = de_resolvable(0.004, de_pixel_m(pw));
	if (fade < 0.02) {
		return vec3(0.0, 0.0, 1.0);
	}
	vec3 p = pw / 0.004 + vec3(0.0, time * film_drift * 6.0, time * film_drift * 2.0);
	float h = dream_corruption_fbm3(p) + 0.6 * dream_corruption_cells(p * 2.0, 0.0, seed);
	float dx = dream_corruption_fbm3(p + vec3(0.4, 0.0, 0.0))
			+ 0.6 * dream_corruption_cells((p + vec3(0.4, 0.0, 0.0)) * 2.0, 0.0, seed) - h;
	float dy = dream_corruption_fbm3(p + vec3(0.0, 0.4, 0.0))
			+ 0.6 * dream_corruption_cells((p + vec3(0.0, 0.4, 0.0)) * 2.0, 0.0, seed) - h;
	return normalize(vec3(-dx * 1.1 * wet * fade, -dy * 1.1 * wet * fade, 1.0));
}

DeOut de_shade(DeMasks m, vec3 pw, vec2 uv, vec3 n, vec3 view_dir, float time, float seed, DeCtx ctx) {
	DeOut o;
	// ---- colour at four frequencies (§A2) --------------------------------
	float macro = dbg_macro
			? dream_corruption_fbm3(de_warp(pw / max(0.02, macro_m) * 0.35, 0.8, seed)) : 0.5;
	float meso = dbg_meso
			? dream_corruption_fbm3(de_warp(pw / max(0.005, meso_m) * 0.12, 0.6, seed + 7.0)) : 0.5;
	float pixel_m = de_pixel_m(pw);
	float submicro_fade = de_resolvable(submicro_m, pixel_m);
	float submicro = dream_corruption_noise3(pw / max(0.0002, submicro_m) * 0.02);

	vec3 albedo = mix(flesh_deep, flesh_body, smoothstep(0.22, 0.80, macro));
	albedo = mix(albedo, flesh_crest, smoothstep(0.48, 0.92, meso) * (0.30 + 0.35 * (1.0 - m.thickness)));
	// The vascular field tints the tissue above it; the pulse pushes warmth
	// into it. Never a drawn line — it is a cloud with structure in it.
	albedo = mix(albedo, flesh_perfusion, m.vascular * (0.18 + 0.16 * m.pulse) * (0.4 + 0.6 * (1.0 - m.thickness)));
	// Pooled blood immediately around the pulse reads darker, not brighter (§D).
	albedo *= 1.0 - m.vascular * m.pulse * 0.10;
	// The host's hero veins: darker, fuller.
	albedo = mix(albedo, flesh_deep * 0.75 + flesh_perfusion * 0.2, m.vein * 0.5);
	// Pores darken slightly; scarring around mineral roots is pale and tight.
	albedo *= 1.0 - m.pore * 0.14;
	// Skin grain in the albedo, only while a pixel can hold it.
	float grain = dream_corruption_noise3(pw / max(0.0002, micro_m) * 0.35);
	albedo *= 1.0 - (grain - 0.5) * 0.10 * de_resolvable(micro_m * 2.0, pixel_m);
	albedo = mix(albedo, flesh_crest * 0.85 + vec3(0.055), ctx.gold_root * 0.35);
	if (m.irid > 0.001) {
		float t = macro * 0.6 + meso * 0.5 + dot(n, vec3(0.4, 0.6, 0.7)) * 0.4 + time * 0.008;
		albedo = mix(albedo, de_iridescence(t), m.irid * 0.45);
	}
	// ---- gold, and the transition into it (§B1, §E) ----------------------
	float gm = m.gold;
	vec3 au = gold * (0.95 + 0.2 * m.mineral);
	// Mineralizing flesh is neither: dark tissue with metal precipitated in
	// it, still mostly tissue. Nothing here becomes a gold surface.
	vec3 transition = mix(albedo, au * 0.7, 0.32);
	albedo = mix(albedo, transition, m.mineral * (1.0 - gm) * 0.7);
	albedo = mix(albedo, au, gm);
	// ---- roughness: moderate flesh, varied metal -------------------------
	float rough = flesh_roughness + 0.10 * (submicro - 0.5) * submicro_fade + 0.07 * m.pore
			- 0.05 * m.pulse * m.vascular;
	float gold_rough = mix(0.44, 0.13, smoothstep(0.25, 0.9, m.mineral))
			+ 0.14 * (dream_corruption_noise3(pw * 20.0 + seed) - 0.5);
	rough = clamp(mix(rough, gold_rough, gm), 0.05, 0.95);
	// ---- subsurface, expressing thickness (§A, §B of DIRECTION_3) --------
	float thin = 1.0 - m.thickness;
	// Sharpened: thick tissue swallows light, membranes glow. Not a rim.
	float scatter = thin * thin * thin;
	o.sss = dbg_sss ? sss_amount * (0.10 + 0.90 * scatter) * (1.0 - gm) : 0.0;
	// The transmitted colour itself changes with thickness: deep tissue
	// gives up almost-black red, a membrane gives fuchsia.
	vec3 transmit = mix(sss_transmit_deep, sss_transmit_thin, scatter);
	// Where the vascular field is dense the transmitted light is bloodier.
	transmit = mix(transmit, sss_transmit_thin * 1.1, m.vascular * 0.35 * (0.5 + 0.5 * m.pulse));
	o.sss_transmit = vec4(transmit, 1.0);
	o.sss_depth = sss_depth_m * mix(0.3, 1.0, scatter);
	o.sss_boost = sss_boost * (0.3 + 0.7 * scatter);
	// §A5: the terminator's warm bleed, restrained, tied to thin tissue only.
	o.backlight = sss_transmit_deep * 0.14 * scatter * (1.0 - gm) * (0.65 + 0.35 * m.pulse);
	// ---- the film as clearcoat (§C) --------------------------------------
	o.clearcoat = m.wet * 0.85 * (1.0 - gm * 0.65);
	// A tight second lobe over a busy normal is exactly how skin turns into
	// glitter: the film's roughness has to stay wide enough to integrate
	// the microstructure under it.
	o.clearcoat_roughness = clamp(film_roughness + 0.10 * (1.0 - m.wet) + 0.10 * m.pore, 0.06, 0.5);
	albedo *= 1.0 - m.wet * 0.10;
	// ---- emission: seams and mineral only --------------------------------
	vec3 e = vec3(0.0);
	if (dbg_gold_emission) {
		float breath = 0.72 + 0.28 * sin(breath_phase * 6.2831853);
		e += gold_hot * m.seam * gold_emission * 0.45 * breath;
		e += gold * gm * 0.04 * gold_emission;
		e += gold_hot * gm * attention * 0.05;
	}
	// ---- three normal scales (§A3) ---------------------------------------
	float d1 = 0.02;
	float a_x = dream_corruption_fbm3(de_warp((pw + vec3(d1, 0.0, 0.0)) / max(0.02, macro_m) * 0.35, 0.8, seed)) - macro;
	float a_y = dream_corruption_fbm3(de_warp((pw + vec3(0.0, d1, 0.0)) / max(0.02, macro_m) * 0.35, 0.8, seed)) - macro;
	float d2 = 0.006;
	float t_x = dream_corruption_fbm3(de_warp((pw + vec3(d2, 0.0, 0.0)) / max(0.005, meso_m) * 0.12, 0.6, seed + 7.0)) - meso;
	float t_y = dream_corruption_fbm3(de_warp((pw + vec3(0.0, d2, 0.0)) / max(0.005, meso_m) * 0.12, 0.6, seed + 7.0)) - meso;
	float d3 = 0.0006;
	float p0 = de_pores(pw / max(0.0002, micro_m), seed);
	float p_x = de_pores((pw + vec3(d3, 0.0, 0.0)) / max(0.0002, micro_m), seed) - p0;
	float p_y = de_pores((pw + vec3(0.0, d3, 0.0)) / max(0.0002, micro_m), seed) - p0;
	float ndv = clamp(dot(n, view_dir), 0.0, 1.0);
	// Grazing angles ease the finest scale so skin is not sandpaper; a wet
	// film fills the microscopic valleys.
	float pore_fade = mix(0.45, 1.0, ndv) * de_resolvable(micro_m, pixel_m) * (1.0 - m.wet * 0.5);
	vec2 slope =
			vec2(a_x, a_y) * (2.2 * normal_anatomical)
			+ vec2(t_x, t_y) * (5.5 * normal_tissue)
			+ vec2(p_x, p_y) * (5.5 * normal_pore * pore_fade)
			+ vec2(m.mineral) * 0.5
			+ vec2(m.papilla) * 0.4;
	slope *= 1.0 - gm * 0.5;
	o.normal_map = normalize(vec3(-slope, 1.0));
	// Specular anti-aliasing: a normal this busy sparkles unless the
	// roughness rises where its variance is high. Without this the skin
	// reads as glitter under a moving light, which is the one thing flesh
	// never does.
	float variance = dot(vec2(p_x, p_y), vec2(p_x, p_y)) * 900.0 * pore_fade
			+ dot(vec2(t_x, t_y), vec2(t_x, t_y)) * 60.0;
	rough = clamp(sqrt(rough * rough + clamp(variance, 0.0, 0.35)), 0.05, 0.95);
	// ---- resolve ---------------------------------------------------------
	o.albedo = albedo;
	// The transition carries only a little metallic response; the skeleton's
	// own geometry is the metal.
	o.metallic = clamp(gm * 0.9 + m.mineral * (1.0 - gm) * 0.25, 0.0, 1.0);
	o.roughness = rough;
	o.specular = mix(0.5, 0.85, gm);
	o.emission = e;
	o.ao = clamp(1.0 - ctx.socket * 0.5 - m.pore * 0.22 * m.lod - ctx.gold_root * 0.18, 0.0, 1.0);
	if (debug_gray) {
		o.albedo = vec3(0.58);
		o.metallic = 0.0;
		o.roughness = 0.55;
		o.specular = 0.5;
		o.emission = vec3(0.0);
		o.backlight = vec3(0.0);
		o.sss = 0.0;
		o.clearcoat = 0.0;
		o.ao = 1.0;
	}
	return o;
}
