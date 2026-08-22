// DREAM ENTITY SURFACE — the reusable material stack for Dream anatomy
// (DREAM_TENTACLE_DIRECTION §5–7, §21). Two material states fight for the
// same body: FLESH (soft, dense, wet, lit from within) and GOLD (precious
// metal flowing slowly along the anatomy, cracked with heated light,
// engraved at close range). Everything is mask-driven; the masks are
// computed once per pixel and exposed so a host shader can read or
// override them (contact, transformation, phase). World-space noise, no
// textures, so nothing repeats.
//
// Host contract: include after `dream_corruption_layers.gdshaderinc`; call
//   DeMasks m = de_masks(pw, uv, n, view_dir, time, seed, relief, contact, lod);
//   DeOut o = de_shade(m, pw, uv, n, view_dir, time, seed, lod);
// and write o.* to the outputs. `uv` is (around, along) on a limb; any
// 2-D parameterisation works. `relief` is the host's height (folds pool
// wetness in its dips); `contact` is the host's contact-activity mask.

group_uniforms dream_material;
uniform vec3 flesh_deep : source_color = vec3(0.060, 0.015, 0.110);
uniform vec3 flesh_body : source_color = vec3(0.230, 0.050, 0.320);
uniform vec3 flesh_crest : source_color = vec3(0.440, 0.170, 0.560);
uniform float wetness : hint_range(0.0, 1.0) = 0.8;
uniform float subsurface : hint_range(0.0, 2.0) = 1.0;
uniform float microdetail : hint_range(0.0, 1.0) = 0.7;
uniform vec3 gold : source_color = vec3(0.859, 0.659, 0.298);
uniform vec3 gold_hot : source_color = vec3(1.0, 0.620, 0.180);
uniform float gold_coverage : hint_range(0.0, 1.0) = 0.42;
uniform float gold_emission : hint_range(0.0, 2.0) = 1.0;
uniform float gold_flow : hint_range(0.0, 1.0) = 0.12;
uniform float gold_ornament : hint_range(0.0, 1.0) = 0.6;
uniform vec3 vein_color : source_color = vec3(0.502, 0.063, 0.122);
uniform float vein_pulse : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_period_s = 1.5;
uniform vec3 sucker_color : source_color = vec3(0.780, 0.459, 0.565);
uniform float phase_instability : hint_range(0.0, 1.0) = 0.35;
uniform float iridescent_rim : hint_range(0.0, 1.0) = 0.5;
// Debug (§25): gray for the silhouette / motion tests; per-system toggles.
uniform bool debug_gray = false;
uniform bool dbg_gold_flow = true;
uniform bool dbg_gold_emission = true;
uniform bool dbg_vein_pulse = true;
uniform bool dbg_rim = true;
uniform bool dbg_phase = true;
group_uniforms;

struct DeMasks {
	float gold;        // gold coverage
	float crack;       // heated cracks within the gold
	float vein;        // raised vein relief
	float pulse;       // the pressure pulse travelling tipward
	float wet;         // wet film (pools in dips, at boundaries)
	float sss;         // subsurface intensity (thin, backlit)
	float phase;       // phase instability
	float rim;         // iridescent rim
	float contact;     // contact activity (host)
	float transformed; // transformed / converted (host)
	float micro;       // microdetail variation
	float ornament;    // engraved ornament in the gold (close range)
};

struct DeOut {
	vec3 albedo;
	float metallic;
	float roughness;
	float specular;
	vec3 emission;
	vec3 backlight;
	vec3 normal_map;
};

// The gold's illumination is not a flame: slices of a luminous structure
// moving through another axis — three masks at different scales and rates
// that gate each other.
float de_gold_slices(vec3 pw, vec2 uv, float time, float seed) {
	float a = dream_corruption_noise3(pw * 2.6 + vec3(time * 0.21, seed, -time * 0.13));
	float b = dream_corruption_noise3(vec3(uv.y * 5.0 + time * 0.37, uv.x * 2.0, seed * 3.0));
	float c = dream_corruption_noise3(pw * 7.0 + vec3(0.0, time * 0.9, 0.0));
	float s1 = smoothstep(0.42, 0.58, a);
	float s2 = smoothstep(0.35, 0.65, b);
	return 0.55 + 0.45 * mix(s1, 1.0 - s1, s2) * (0.7 + 0.3 * smoothstep(0.3, 0.7, c));
}

// Engraved ornament: filigree lines and a clockwork tessellation, moving
// very slowly, only where the gold is and only near the camera.
float de_ornament(vec2 uv, float time, float lod) {
	vec2 g = uv * vec2(18.0, 70.0);
	vec2 cell = fract(g) - 0.5;
	float ring = abs(length(cell) - 0.32);
	float lines = min(abs(cell.x), abs(cell.y));
	float tess = 1.0 - smoothstep(0.02, 0.05, min(ring, lines));
	float fil = pow(abs(sin(uv.y * 160.0 + sin(uv.x * 22.0 + time * 0.05) * 2.0)), 14.0);
	return clamp(max(tess * 0.8, fil * 0.6), 0.0, 1.0) * lod;
}

DeMasks de_masks(vec3 pw, vec2 uv, vec3 n, vec3 view_dir, float time, float seed,
		float relief, float contact, float lod) {
	DeMasks m;
	float u = uv.x;
	float v = uv.y;
	// Gold: seams flowing along the anatomy, pooled patches, the boundary
	// softened so the two states interpenetrate.
	float flow_t = time * gold_flow;
	// Two helical seams winding along the anatomy, their width breathing
	// with a slow warp; pooled patches where the gold has gathered; a faint
	// lattice of finer vessels between.
	float warp = dream_corruption_fbm3(vec3(u * 1.5, v * 3.0 - flow_t, seed)) - 0.5;
	float h1 = sin((u + v * 1.35) * 6.2831853 + warp * 2.2 + seed);
	float h2 = sin((u * 1.0 - v * 0.8) * 6.2831853 + warp * 1.6 + seed * 2.0 + 1.9);
	float width = 0.80 + 0.12 * gold_coverage;
	float seam_m = max(smoothstep(width, width + 0.08, h1), smoothstep(width + 0.05, width + 0.12, h2));
	float lattice = dream_corruption_vessels(vec3(u * 2.0, v * 5.0 - flow_t, seed) * 1.6, 0.85, 0.9);
	float pools = dream_corruption_fbm3(vec3(u * 3.0, v * 8.0 - flow_t * 0.6, seed) * 2.0);
	float pool_m = smoothstep(0.74 - gold_coverage * 0.18, 0.80 - gold_coverage * 0.18, pools);
	m.gold = clamp(seam_m + pool_m + smoothstep(0.6, 0.9, lattice) * 0.35 * gold_coverage, 0.0, 1.0);
	// Heated cracks inside the gold.
	float cracks = dream_corruption_vessels(vec3(u * 7.0, v * 26.0, seed + 4.0) * 1.3, 0.9, 0.96);
	m.crack = smoothstep(0.55, 0.85, cracks) * m.gold;
	// Veins: the host passes their relief; the pulse travels tipward.
	m.vein = clamp(relief, 0.0, 1.0);
	float pulse_phase = v * 6.0 - time / max(0.2, pulse_period_s);
	m.pulse = pow(0.5 + 0.5 * sin(pulse_phase * 6.2831853), 6.0) * vein_pulse;
	if (!dbg_vein_pulse) { m.pulse = 0.0; }
	// Wet film: everywhere a little, pooled in dips, folds and at the
	// gold / flesh boundary, and around contact.
	float boundary = m.gold * (1.0 - m.gold) * 4.0;
	float folds = dream_corruption_fbm3(pw * 14.0 + seed);
	m.wet = wetness * clamp(0.35 + 0.45 * smoothstep(0.55, 0.8, folds) + 0.4 * boundary + 0.5 * contact, 0.0, 1.0);
	// Subsurface: thin where the view grazes, and at the crests.
	float ndv = clamp(dot(n, view_dir), 0.0, 1.0);
	m.sss = subsurface * pow(1.0 - ndv, 2.0) * (0.5 + 0.5 * smoothstep(0.4, 0.8, folds));
	// Phase instability: a narrow band moving along the anatomy.
	float band = dream_corruption_noise3(vec3(v * 3.0 - time * 0.17, seed * 2.0, 1.0));
	m.phase = phase_instability * smoothstep(0.62, 0.70, band) * (1.0 - smoothstep(0.74, 0.82, band));
	if (!dbg_phase) { m.phase = 0.0; }
	// Iridescent rim: a thin Fresnel band.
	m.rim = iridescent_rim * pow(1.0 - ndv, 4.5);
	if (!dbg_rim) { m.rim = 0.0; }
	m.contact = contact;
	m.transformed = 0.0;
	m.micro = microdetail * (0.5 + 0.5 * dream_corruption_noise3(pw * 40.0));
	m.ornament = gold_ornament * de_ornament(uv, time, lod) * m.gold;
	return m;
}

// Constrained spectral palette for the rim (§21): violet, green, gold, rose.
vec3 de_spectral(float t) {
	vec3 c0 = vec3(0.45, 0.22, 0.62);
	vec3 c1 = vec3(0.25, 0.55, 0.38);
	vec3 c2 = vec3(0.85, 0.66, 0.30);
	vec3 c3 = vec3(0.78, 0.36, 0.52);
	float x = fract(t) * 4.0;
	vec3 c = mix(c0, c1, clamp(x, 0.0, 1.0));
	c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
	c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
	c = mix(c, c0, clamp(x - 3.0, 0.0, 1.0));
	return c;
}

DeOut de_shade(DeMasks m, vec3 pw, vec2 uv, vec3 n, vec3 view_dir, float time, float seed, float lod) {
	DeOut o;
	// Flesh at two scales: soft tissue folds, then skin microdetail.
	float folds = dream_corruption_fbm3(pw * 9.0 + vec3(0.0, time * 0.05, seed));
	float cells = dream_corruption_cells(pw * 16.0, time, 0.6);
	float micro = dream_corruption_noise3(pw * 90.0) * m.micro * lod;
	vec3 flesh = mix(flesh_deep, flesh_body, smoothstep(0.25, 0.75, folds));
	flesh = mix(flesh, flesh_crest, cells * 0.35 + micro * 0.15);
	flesh = mix(flesh, vein_color, m.vein * 0.85);
	// Gold, precious. The room has nothing for a mirror-metal to reflect
	// (no probes in Compatibility), so the lustre is carried by a bright
	// albedo, a high specular and a low, steady glow rather than by
	// metallic reflection alone.
	vec3 au = gold * (1.05 + 0.15 * m.ornament);
	au = mix(au, gold * 0.62, m.ornament * 0.5);
	float gm = m.gold;
	o.albedo = mix(flesh, au, gm);
	o.metallic = gm * 0.55 * (1.0 - m.crack * 0.4);
	// Roughness: flesh soft but wet where the film is; gold tight.
	float flesh_rough = mix(0.48, 0.10, m.wet);
	o.roughness = mix(flesh_rough, mix(0.26, 0.16, m.ornament), gm);
	o.specular = mix(0.5 + 0.3 * m.wet, 0.95, gm);
	// Emission: the heated cracks and the slices of the luminous structure;
	// the pulse in the veins; the subsurface glow where thin.
	float slices = de_gold_slices(pw, uv, time, seed);
	vec3 e = vec3(0.0);
	if (dbg_gold_emission) {
		e += (gold_hot * m.crack * 0.9 + gold * gm * 0.22) * slices * gold_emission;
	}
	e += vein_color * m.pulse * m.vein * 0.5;
	// Lit from within (DIRECTION 6): the flesh carries its own violet, so it
	// stays violet under a tungsten torch that would otherwise read it red.
	e += (flesh_body * 0.10 + flesh_crest * m.sss * 0.30) * subsurface * (1.0 - gm);
	o.emission = e;
	o.backlight = flesh * 0.5 * (1.0 - gm) * subsurface;
	// The rim: colours of interference, not pigment.
	float spec_t = dot(n, vec3(0.3, 0.5, 0.8)) * 0.5 + folds * 0.5 + time * 0.02;
	vec3 irid = de_spectral(spec_t);
	o.albedo = mix(o.albedo, irid, m.rim * 0.55 * (1.0 - gm));
	o.emission += irid * m.rim * 0.35;
	// Microstructure as a normal: folds and skin grain from finite
	// differences of the same fields (cheap, repetition-free).
	float e1 = 0.012;
	float f_x = dream_corruption_fbm3((pw + vec3(e1, 0.0, 0.0)) * 9.0 + vec3(0.0, time * 0.05, seed)) - folds;
	float f_y = dream_corruption_fbm3((pw + vec3(0.0, e1, 0.0)) * 9.0 + vec3(0.0, time * 0.05, seed)) - folds;
	float g_x = dream_corruption_noise3((pw + vec3(0.004, 0.0, 0.0)) * 90.0) - dream_corruption_noise3(pw * 90.0);
	float g_y = dream_corruption_noise3((pw + vec3(0.0, 0.004, 0.0)) * 90.0) - dream_corruption_noise3(pw * 90.0);
	vec2 slope = vec2(f_x, f_y) * 5.0 * (1.0 - gm * 0.7) + vec2(g_x, g_y) * 2.5 * m.micro * lod;
	slope += vec2(m.ornament) * 0.6 * gm;
	o.normal_map = normalize(vec3(-slope, 1.0));
	if (debug_gray) {
		o.albedo = vec3(0.62);
		o.metallic = 0.0;
		o.roughness = 0.55;
		o.specular = 0.5;
		o.emission = vec3(0.0);
		o.backlight = vec3(0.0);
	}
	return o;
}
