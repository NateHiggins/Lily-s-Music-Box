shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx, unshaded;

#include "res://shaders/dream_cellular_surface.gdshaderinc"
// DREAM SALIVA (design/DREAM_SALIVA_DIRECTION.md).
//
//   "iridescent holographic reflective saliva goo ... that crystalizes like
//    superchilled frost in a otherworldly metalic neon rainbow with
//    dimensional breaking properties that persist and decay like its being
//    eroded by an eon of time in a couple seconds"
//
// Five demands, each of which fails differently, so each is built separately.
//
// IRIDESCENT means STRUCTURAL COLOUR: the hue must move with the viewing
// angle and with the lamp. A fixed rainbow gradient painted on a surface is
// the failure mode, so the hue here comes from a thin-film interference term
// driven by the angle between view and surface — look at it from somewhere
// else and it is a different colour.
//
// CRYSTALLISES LIKE FROST means it PROPAGATES rather than appearing: a
// noise-warped front runs outward, faster along some directions than others,
// with a bright leading edge. You can catch it in the act.
//
// ERODED BY AN EON IN A COUPLE OF SECONDS is the hard one, and it is why the
// stages are authored rather than lerped. Different properties die at
// different times — the structural colour goes before the substance does,
// then it pits, then it cracks, then only a ghost of mineral is left. A
// uniform fade is exactly what this must not look like.
//
// One mesh, one draw, up to MAX_PATCHES contacts. The frame is
// submission-bound (design/DT4_PERFORMANCE_REAUDIT.md).

const int MAX_PATCHES = 24;

// xyz centre, w radius
uniform vec4 patch_pos[24];
// xyz normal, w age in seconds
uniform vec4 patch_nrm[24];
// x seed, y intensity, z lifetime, w the slice the patch was laid at
uniform vec4 patch_par[24];
// xy are tangent/bitangent aspect, z selects the visit-persistent anatomical
// memory language, w is its generation trace.
uniform vec4 patch_shape[24];
uniform int patch_count = 0;
uniform float dream_w = 0.0;

varying vec2 v_local;
varying float v_age;
varying float v_seed;
varying float v_life;
varying float v_intensity;
varying vec3 v_world;
varying vec3 v_normal;
varying vec4 v_shape;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

varying vec3 v_tx;
varying vec3 v_ty;
varying float v_born_w;

void vertex() {
	int p = int(UV2.x + 0.5);
	vec4 pos = patch_pos[p];
	vec4 nrm = patch_nrm[p];
	vec4 par = patch_par[p];
	vec4 shape = patch_shape[p];
	vec3 n = normalize(nrm.xyz + vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tx = normalize(cross(any, n));
	vec3 ty = cross(n, tx);
	// The unit disc in the mesh becomes a patch on the surface it was left on,
	// lifted a hair so it does not fight the wall for the depth buffer.
	vec2 uv = VERTEX.xy;
	float dead = par.z > 0.0 && nrm.w > par.z ? 0.0 : 1.0;
	vec2 aspect = max(shape.xy, vec2(0.001));
	vec3 world = pos.xyz + (tx * uv.x * aspect.x + ty * uv.y * aspect.y)
			* pos.w * dead + n * 0.004;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = n;
	v_local = uv;
	v_age = nrm.w;
	v_seed = par.x;
	v_intensity = par.y;
	v_life = par.z;
	v_world = world;
	v_normal = n;
	v_tx = tx;
	v_ty = ty;
	v_born_w = par.w;
	v_shape = shape;
}

void fragment() {
	float r = length(v_local);
	if (r > 1.0 || v_life == 0.0) {
		discard;
	}
	float age = v_age;
	float life = v_life;
	float memory = step(0.5, v_shape.z);
	float effective_life = life < 0.0 ? 1.0 : life;
	float t = memory > 0.5 ? 0.72 : clamp(age / max(0.001, effective_life), 0.0, 1.0);
	vec2 np = v_local * 3.4 + vec2(v_seed * 11.0, v_seed * 7.0);

	// ---- THE FROST FRONT ------------------------------------------------
	// It propagates. The boundary is warped so it runs faster along some
	// directions than others, the way frost follows a scratch in glass.
	float warp = fbm(np * 1.6) * 0.55 + fbm(np * 4.1) * 0.22;
	float front = memory > 0.5 ? 1.4 : clamp(age / 0.55, 0.0, 1.4);
	float edge_r = r + warp * 0.62 - 0.30;
	float covered = smoothstep(front, front - 0.16, edge_r);
	if (covered <= 0.003) {
		discard;
	}
	// A bright leading edge, only while it is still running.
	float lead = smoothstep(front - 0.10, front, edge_r)
			* smoothstep(front + 0.05, front - 0.02, edge_r)
			* (1.0 - smoothstep(0.5, 1.0, age / 0.75));

	// ---- EROSION, NOT A FADE --------------------------------------------
	// Pits open and widen; then cracks; then only a ghost. Each on its own
	// clock, so the thing decays unevenly the way something old does.
	float pit_t = smoothstep(0.45, 1.00, t);
	float pits = smoothstep(0.52 - 0.30 * pit_t, 0.58 - 0.30 * pit_t, fbm(np * 5.2 + 3.1));
	float crack_t = smoothstep(0.46, 1.0, t);
	float cracks = smoothstep(0.46, 0.50, abs(fbm(np * 3.1 + 11.0) - 0.5) * 2.0);
	float substance = covered * (1.0 - pits * pit_t) * (1.0 - (1.0 - cracks) * crack_t * 0.70);
	// The very edge thins first, always -- and it is NOT A CIRCLE. Once the
	// front had run past the disc the outer boundary was the mesh's own rim,
	// so a fully grown patch photographed as a perfect circle: a decal, not
	// something spilled. The boundary carries the same warp the front did.
	// THE EDGE THINS; IT DOES NOT EAT THE PATCH. Retreating to 0.70 of the
	// radius compounded with the pitting, the cracking and the cross-section
	// cut, and photographed at two thirds of its life the goo was already a
	// few specks -- which is a fade with extra steps, and loses the ghost the
	// direction asks it to leave behind.
	substance *= smoothstep(1.0, 0.82 - 0.14 * t, r + warp * 0.42 - 0.19);
	if (substance <= 0.004) {
		discard;
	}

	// ---- DIMENSIONAL BREAKING (the fifth demand) ------------------------
	//
	//     "the surface it sits on should stop being reliably
	//      three-dimensional where the goo is thick"
	//
	// This is the antagonist's own substance, so it carries the antagonist's
	// own law. The goo is not a film on the wall: it is a CROSS-SECTION of
	// something with a fourth extent, and the wall shows you only the slice at
	// the Dream's current w. Parts of it therefore have no cross-section here
	// at all -- holes with hard, unweathered edges, which is a different thing
	// entirely from the soft pitting the erosion above opens, and they MIGRATE
	// as the slice advances rather than only widening.
	//
	// r_visible = sqrt(r^2 - w^2), the field's own equation
	// (DREAM_FIELD_DIRECTION), applied to a smear of spit.
	//
	// Measured relative to the slice the patch was LAID at. `dream_w` only
	// ever increases -- at 0.115 per second it moves about 0.41 across a
	// patch's whole life -- so an absolute reading would leave every patch
	// stranded slices away from its own substance.
	float w_since = dream_w - v_born_w;
	// Thick goo only. A thin smear at the rim is just wet, and wet is three
	// dimensional. It also waits for the frost: fresh spit is a fluid, and it
	// is the CRYSTAL that has the extra axis.
	float thick = covered * v_intensity * (1.0 - 0.55 * t);
	float w_at = (fbm(np * 2.7 + 31.0) - 0.5) * 0.56;
	float w_ext = 0.12 + 0.42 * fbm(np * 1.7 + 91.0);
	float dw = w_since - w_at;
	float section = w_ext * w_ext - dw * dw;
	float present = section > 0.0 ? sqrt(section) / w_ext : 0.0;

	// ---- STRUCTURAL COLOUR ----------------------------------------------
	// Thin-film interference: hue from the VIEW ANGLE, not from a gradient.
	// It also dies before the substance does, which is what makes the decay
	// read as erosion rather than as opacity going down.
	vec3 view_dir = normalize(VIEW);
	// BROAD BANDS, NOT A DIFFRACTION GRATING. The first version used 1/facing
	// directly, which reaches fifty at grazing angles and cycled the hue fifty
	// times across one patch -- photographed, it was a fine moiré that read as
	// a CD surface rather than as structural colour on something wet. The
	// angle still drives it, so the hue still moves as you move; it just
	// sweeps a couple of bands instead of dozens.
	float facing = clamp(abs(dot(normalize(v_normal), view_dir)), 0.22, 1.0);
	// The angle gives the patch its overall hue and makes it shift as you
	// move; the spatial term gives it BANDS. With only the angle it came out
	// one flat colour across the whole patch, because a flat patch has one
	// facing -- a neon rainbow needs more than one band in it.
	float film = (0.55 + 0.75 * (1.0 - facing)) * 1.6
			+ fbm(np * 1.1) * 1.7 + fbm(np * 3.3) * 0.5
			+ dream_w * 0.20 + v_seed * 2.0;
	vec3 iris = 0.5 + 0.5 * cos(6.2831853 * (film + vec3(0.0, 0.33, 0.67)));
	// Neon and metallic rather than pastel: pushed away from grey, hard.
	iris = pow(clamp(iris, vec3(0.0), vec3(1.0)), vec3(2.1));
	iris /= max(0.22, (iris.r + iris.g + iris.b) * 0.42);
	// The colour must die BEFORE the substance -- that ordering is what makes
	// this erosion and not a fade -- but dying by two thirds of the way
	// through left the whole second half of the life as a colourless smear,
	// so most of what was photographed was the ghost. It now goes late, and
	// only just before the substance follows it.
	float colour_life = 1.0 - smoothstep(0.35, 0.90, t);

	// AND THE INTERIOR IS NOT WHERE THE WALL IS. The crystal structure is
	// sampled at a view-dependent offset, so it swims against the surface as
	// you move past it -- a window behaves like that and a stain does not.
	// This is the half of the effect you notice while walking; the holes are
	// the half you notice while standing still.
	vec3 tv = view_dir - v_normal * dot(view_dir, v_normal);
	vec2 ip = np + vec2(dot(tv, v_tx), dot(tv, v_ty)) * thick * 0.30;

	// Crystal facets: flat cells that catch the light in one direction each.
	// WARPED BEFORE THEY ARE CUT. Flooring a plain grid gave square facets in
	// a square lattice, which photographed as a checkerboard of pixel blocks
	// -- the one pattern frost never makes. Displacing the lookup first leaves
	// the same flat cells catching light in their own directions, in irregular
	// shapes that do not line up with each other.
	vec2 fp = ip + vec2(fbm(ip * 1.3 + 4.0), fbm(ip * 1.3 + 19.0)) * 0.62;
	vec2 cell = floor(fp * 6.0);
	float facet = hash21(cell);
	float crystallised = memory > 0.5 ? 1.0
			: smoothstep(0.10, 0.55, age / max(0.001, effective_life * 0.5));
	float glint = pow(max(0.0, dot(view_dir, normalize(v_normal
			+ vec3(facet - 0.5, hash21(cell + 7.0) - 0.5, 0.0) * 0.85))), 22.0);

	// The section cut, gated on the frost and on thickness. A hard step, not
	// a smoothstep: a cross-section has an edge, it does not fade out.
	float breaking = crystallised * smoothstep(0.30, 0.75, thick);
	substance *= mix(1.0, step(0.22, present), breaking);
	if (substance <= 0.004) {
		discard;
	}
	// Right at the cut the exposed face glows: it is an interior surface that
	// was never meant to face a room.
	float rim = breaking * smoothstep(0.46, 0.24, present) * step(0.22, present);

	vec3 wet = vec3(0.62, 0.70, 0.78) * 0.35;
	vec3 body = mix(wet, iris, colour_life * crystallised);
	body += iris * glint * crystallised * colour_life * 2.4;
	body += vec3(1.0, 0.96, 0.9) * lead * 1.8;
	body += iris * rim * 1.9;
	// The ghost: what is left once the colour has gone is dull mineral.
	// Dull mineral, and DARK -- what an eon leaves on a wall is a stain, and
	// at 0.20 over a lit pale panel it was barely separable from the panel.
	vec3 ghost = vec3(0.11, 0.09, 0.14);
	body = mix(ghost, body, colour_life * 0.85 + 0.15);
	// A hero sheath remembers systems, not merely wetness: a wine-dark
	// membrane with branching capillary negatives and mineral sutures where a
	// complete organ stopped crossing our slice. It remains attractive enough
	// to approach and wrong enough to read as an absence.
	float branch_a = abs(v_local.y - sin(v_local.x * 7.0 + v_seed) * 0.16);
	float branch_b = abs(v_local.x - sin(v_local.y * 11.0 - v_seed) * 0.10);
	float capillary = smoothstep(0.055, 0.012, min(branch_a, branch_b));
	float branch_warp_a = (fbm(v_local * vec2(2.1, 3.7)
			+ vec2(v_seed, 13.0)) - 0.5) * 0.62;
	float branch_warp_b = (fbm(v_local.yx * vec2(3.4, 2.5)
			+ vec2(29.0, v_seed)) - 0.5) * 0.56;
	float suture_a = abs(v_local.y + v_local.x * 0.22 - branch_warp_a);
	float suture_b = abs(v_local.x - v_local.y * 0.18 - 0.18 - branch_warp_b);
	float interrupted = smoothstep(0.38, 0.58, fbm(np * 2.3 + 81.0));
	float suture = smoothstep(0.022, 0.006, min(suture_a, suture_b))
			* smoothstep(0.98, 0.34, r) * interrupted;
	float vesicles = smoothstep(0.79, 0.91, fbm(np * 4.8 + 37.0))
			* smoothstep(0.96, 0.30, r) * (1.0 - capillary);
	vec3 sheath = mix(vec3(0.050, 0.006, 0.038), vec3(0.19, 0.018, 0.105),
			fbm(np * 1.8));
	sheath *= 1.0 - capillary * 0.90;
	sheath += vec3(0.62, 0.34, 0.065) * suture * (0.55 + facet * 0.45);
	sheath += vec3(0.62, 0.55, 0.40) * vesicles * 0.34;
	body = mix(body, sheath, memory);
	vec4 failed_state = vec4(1.0, 1.0, 0.0, 0.0);
	vec4 residue_cell = cell_membrane(v_world * 5.0, v_normal, view_dir, v_seed,
			vec4(.90,.08,.18,.24), vec4(0.0, v_intensity, 0.0, 0.0),
			vec4(0.0), failed_state, age);
	float coagulated = smoothstep(.42,.68, residue_cell.x + capillary * .22);
	body = mix(body, body * vec3(.42,.28,.38), memory * coagulated * .48);
	body += vec3(.28,.07,.18) * residue_cell.w * memory * .12;
	float sheath_substance = covered * smoothstep(1.0, 0.76,
			r + warp * 0.42 - 0.19) * (0.92 + suture * 0.08);
	substance = mix(substance, sheath_substance, memory);

	ALBEDO = body * v_intensity;
	// The ghost keeps most of its opacity. What goes is the COLOUR, which is
	// what makes the decay read as erosion rather than as something dimming.
	ALPHA = clamp(substance * (0.72 + 0.28 * colour_life) * v_intensity, 0.0, 1.0);
	ALPHA = mix(ALPHA, clamp(substance * 0.86 * v_intensity, 0.0, 1.0), memory);
	EMISSION = body * (0.35 * colour_life + lead * 1.2 + rim * 1.4) * v_intensity;
	EMISSION += vec3(0.38, 0.17, 0.035) * suture * memory * 0.18;
}
