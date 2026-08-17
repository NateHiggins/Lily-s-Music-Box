shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// THE STOCLET FRIEZE, TAKEN APART AND HUNG ON THE ARCHITECTURE.
//
// Owner reference: Klimt's "The Tree of Life, Expectation and Fulfilment"
// (Stoclet Frieze, 1905-11). The important thing about that painting is that
// it is NOT one texture. It is five or six distinct pattern languages sharing
// one palette, each bounded by flat ground so none of them turns to wallpaper:
//
//   the cream ivory field        vast, nearly unornamented, lets the rest read
//   the spiral tendril tree      thin gold LINE work, coiling, structural
//   the triangle robe            stacked chevrons, sharp, black/cream/teal
//   the ovoid robe               concentric eyes and ovals, dense, watching
//   the mosaic block field       small black/white/gold rectangles, textile
//   the flowerbed                scattered coloured dots along the bottom
//
// So each surface class in the maze wears one of them. That is the point of
// doing it this way rather than skinning everything alike: the ornament stops
// being decoration and becomes WAYFINDING. In a maze whose whole job is to
// make you lost, the pattern tells you what a thing IS — floor underfoot,
// wall beside you, door ahead, and the watching eyes mean danger.
//
// THE GOLD IS METALLIC, NOT EMISSIVE, in every motif. Gold leaf is not a light
// source; it is a mirror with a colour. The lamp is the only thing that wakes
// it and there is pitch blackness beyond the pool (owner ruling: "a dramatic
// dark dropoff and pitch blackness beyond"), so the world is only beautiful
// where you are looking — and being lit is what is hunting you.

// ---------------------------------------------------------------- motifs ---
#define MOTIF_IVORY 0
#define MOTIF_SPIRAL 1
#define MOTIF_MOSAIC 2
#define MOTIF_TRIANGLE 3
#define MOTIF_EYE 4
#define MOTIF_FLOWERBED 5
uniform int motif : hint_range(0, 5) = 1;

// --------------------------------------------------------------- palette ---
// Read off the frieze rather than invented. The cream is the ground of the
// whole painting; the golds run from a dark bole through leaf to a pale
// near-white highlight; the accents are the three Klimt actually used.
uniform vec3 ivory : source_color = vec3(0.913, 0.874, 0.760);
uniform vec3 bole : source_color = vec3(0.352, 0.207, 0.086);
uniform vec3 gold_deep : source_color = vec3(0.545, 0.361, 0.110);
uniform vec3 gold_mid : source_color = vec3(0.792, 0.612, 0.196);
uniform vec3 gold_pale : source_color = vec3(0.945, 0.855, 0.560);
uniform vec3 ink : source_color = vec3(0.070, 0.062, 0.058);
uniform vec3 accent_teal : source_color = vec3(0.180, 0.404, 0.360);
uniform vec3 accent_lapis : source_color = vec3(0.145, 0.216, 0.463);
uniform vec3 accent_oxblood : source_color = vec3(0.451, 0.098, 0.106);

// THE ONE DEPARTURE FROM THE PAINTING, AND IT IS DELIBERATE.
//
// The Stoclet Frieze is gold ON CREAM: a luminous ivory ground carrying darker
// gold line work. Rendered literally in a corridor lit by one hot lamp, that
// ground is the brightest thing in frame and blows to white the moment the
// beam touches it — the first pass did exactly that, and the ornament vanished
// inside its own highlight.
//
// So the VALUE structure inverts while the hue structure does not. Klimt's
// marks, Klimt's palette, Klimt's bounding rules, all laid on a dark ground so
// the leaf is the bright thing. That is what "barely lit by a guttering lamp"
// requires, and it is also just how gilding reads at night: the ground goes to
// nothing and the metal is all that answers the light.
uniform float ground_dark : hint_range(0.0, 1.0) = 0.22;

// ----------------------------------------------------------------- shape ---
uniform float pattern_scale : hint_range(0.2, 40.0) = 7.0;
uniform float ink_weight : hint_range(0.0, 1.0) = 0.55;
uniform float accent_amount : hint_range(0.0, 1.0) = 0.45;
uniform float gold_metallic : hint_range(0.0, 1.0) = 0.28;
uniform float gold_roughness : hint_range(0.0, 1.0) = 0.16;
uniform float ground_roughness : hint_range(0.0, 1.0) = 0.88;
// A whisper of self-glow in the deepest leaf. NOT a light source: with the
// ambient gone this is all that stops leaf being pure black outside the pool,
// and it is held far below anything that would read as emissive.
uniform float leaf_ember : hint_range(0.0, 0.30) = 0.05;
// Sub-hertz. The brief bans flashing outright and makes it non-negotiable.
uniform float breathe_speed : hint_range(0.0, 0.4) = 0.05;

// ------------------------------------------------------------- the melt ---
// MOLTEN GOLD, AND THE PROBLEM IT HAS TO SOLVE FIRST.
//
// Owner: "make the whites map to a molten golden liquid reflection, like
// things are actually made of gold that melts and morphs when light hits it."
//
// Metal reflects its environment. This world HAS no environment -- no sky, no
// reflection probe, ambient disabled by ruling -- so a high-metallic surface
// here is a mirror of nothing and renders black. That has already bitten this
// shader once; see the note on gold_metallic.
//
// So the thing the gold reflects is THE LAMP. A procedural environment is
// evaluated per fragment and gated by proximity to the lamp, which is both the
// cheap answer and the honest one: in a black corridor with one light, the
// only thing a mirror can show you IS that light. It also keeps the mechanic
// intact, because the reflection cannot exist where the lamp is not -- the
// gold still has to be found.
uniform vec3 lamp_pos = vec3(0.0);
uniform float lamp_energy = 1.0;
uniform float melt_radius : hint_range(0.5, 12.0) = 4.6;
uniform float melt_flow : hint_range(0.0, 3.0) = 1.0;
uniform float melt_amount : hint_range(0.0, 1.0) = 1.0;

// --------------------------------------------------------- the breathing ---
// "Let the maze breathe." The frieze's power is dense ornament against BARE
// ground -- the tree has empty cream around it, and uniform clothing is what
// turns ornament into wallpaper. A low-frequency field opens and closes the
// leaf so a wall runs from thicket to nothing and back.
uniform float breathe_scale : hint_range(0.01, 2.0) = 0.16;
uniform float breathe_depth : hint_range(0.0, 1.0) = 0.75;
// The whole domain drifts, slowly, always. This is the funhouse: sub-hertz,
// never a flicker, but the wall you looked away from is not quite the wall you
// look back at.
uniform float drift_speed : hint_range(0.0, 0.2) = 0.014;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Cheap value noise and a two-octave fbm. Enough for flow and for the
// breathing field; nothing here needs gradient noise.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.62 + vnoise(p * 2.17 + 5.2) * 0.38;
}

// THE FAKE ENVIRONMENT. A studio in a function: a hot band above falling to
// dark below, with a tight highlight at the top. Sampling it by the reflection
// vector gives metal something to be a mirror OF, and gating the result on
// lamp proximity means the only thing it ever mirrors is the lamp.
vec3 fake_env(vec3 r, vec3 hot, vec3 cool) {
	float up = r.y * 0.5 + 0.5;
	vec3 c = mix(cool * 0.12, hot, smoothstep(0.30, 0.92, up));
	c += hot * pow(smoothstep(0.62, 1.0, up), 5.0) * 0.9;
	return c;
}

// THE WORLD THAT ONLY EXISTS IN THE REFLECTION.
//
// Owner: "create an elaborate image prompt for the klimt world that only
// exists in the reflection in the molten gold."
//
// The corridor you walk is bare gilded architecture. The world the gold
// REMEMBERS -- the residents, the rooms as Klimt would have painted them, the
// Tenant among them -- exists nowhere in the scene graph. It is an
// equirectangular plate sampled only by the reflection vector of molten metal,
// so the only way to see it is to melt a surface with your lamp and catch it
// at the right angle. Look directly and there is nothing there.
//
// `reflected_world` is unset until the plate is generated
// (design/KLIMT_REFLECTED_WORLD_PROMPTS.md), and the procedural studio below
// stands in meanwhile so the metal always has something to mirror.
uniform sampler2D reflected_world : source_color, hint_default_black,
		filter_linear_mipmap, repeat_enable;
uniform float reflected_world_gain : hint_range(0.0, 4.0) = 1.0;

vec3 sample_reflected_world(vec3 r) {
	vec3 d = normalize(r);
	// Equirectangular lookup. The world turns slowly with the domain drift, so
	// what the gold remembers is never quite in the same place twice.
	vec2 uv = vec2(atan(d.z, d.x) / TAU + 0.5 + TIME * drift_speed * 0.35,
			acos(clamp(d.y, -1.0, 1.0)) / PI);
	vec3 plate = texture(reflected_world, uv).rgb * reflected_world_gain;
	// The procedural studio, kept as the floor under the plate: a hot band
	// above falling to dark, so bare metal still reads as metal before any
	// image exists.
	vec3 studio = fake_env(d, gold_mid * 1.35, bole);
	return max(studio, plate);
}

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

// THE TENDRIL. An Archimedean coil drawn as a LINE, which is the whole
// character of the tree: Klimt's branches are not filled shapes, they are a
// wire that turns and turns. Bands fall out of comparing radius against angle.
float spiral_line(vec2 q, float turns, float spacing, float width) {
	float a = atan(q.y, q.x) / TAU + 0.5;
	float r = length(q);
	float f = fract(r / spacing - a * turns);
	float d = min(f, 1.0 - f);
	return smoothstep(width, 0.0, d);
}

// THE EYE. Concentric rings around a dark pupil, scattered one per cell. The
// most unsettling mark in the frieze, so it is reserved for danger.
float eye_field(vec2 q, float cell_size, out float pupil) {
	vec2 g = q / cell_size;
	vec2 c = floor(g);
	float h = hash21(c);
	vec2 f = fract(g) - 0.5 - (vec2(h, fract(h * 7.3)) - 0.5) * 0.3;
	float r = length(f);
	pupil = smoothstep(0.12, 0.07, r);
	float rings = sin(r * (28.0 + h * 22.0));
	return smoothstep(0.25, 0.85, rings) * smoothstep(0.48, 0.30, r);
}

// THE MOSAIC. Small rectangles with a gap between them, jittered per cell so
// the field never reads as graph paper. This is the frieze's textile.
float mosaic_field(vec2 q, float cell_size, out float tone) {
	vec2 g = q / cell_size;
	vec2 c = floor(g);
	float h = hash21(c);
	vec2 f = fract(g);
	float pad = 0.08 + h * 0.10;
	float m = step(pad, f.x) * step(f.x, 1.0 - pad)
			* step(pad, f.y) * step(f.y, 1.0 - pad);
	tone = h;
	return m;
}

// THE CHEVRON. Stacked triangles, sharp and directional — the Expectation
// figure's robe. Direction is the reason doors wear it.
float triangle_field(vec2 q, float cell_size, out float band) {
	vec2 g = q / cell_size;
	vec2 c = floor(g);
	vec2 f = fract(g);
	band = hash21(c);
	float t = abs(f.x - 0.5) * 2.0;
	return step(f.y, 1.0 - t);
}

void fragment() {
	// TRIPLANAR: the maze is graybox boxes with no usable UVs, and projecting
	// from world space also runs the ornament CONTINUOUSLY from one module
	// into the next. The building is leafed, not textured object by object.
	vec3 n = normalize(v_normal);
	vec3 w = pow(abs(n), vec3(6.0));
	w /= (w.x + w.y + w.z);
	vec3 p = v_world * pattern_scale;
	float t = TIME * breathe_speed;

	// HEAT: how close this fragment is to the lamp. Everything molten is gated
	// on it, so the gold liquefies only where the light actually lands and the
	// rest of the corridor stays solid, cold and dark.
	float heat = clamp(1.0 - distance(v_world, lamp_pos) / melt_radius,
			0.0, 1.0);
	heat = pow(heat, 1.7) * clamp(lamp_energy, 0.0, 4.0) * melt_amount;

	// THE FLOW. Domain warp, animated, scaled by heat -- so the ornament is
	// crisp where it is cold and runs where the light is on it. That is what
	// "melts and morphs when light hits it" means in a shader: the pattern's
	// own coordinates are what liquefy.
	float ft = TIME * melt_flow;
	vec2 warp = vec2(
			fbm(p.xz * 0.9 + vec2(ft * 0.21, ft * 0.13)),
			fbm(p.xz * 0.9 + vec2(7.3 - ft * 0.17, 2.1 + ft * 0.11))) - 0.5;
	vec2 drift = vec2(TIME * drift_speed, TIME * drift_speed * 0.61);

	// Sample the DOMINANT plane only. Blending three planes of line work turns
	// a spiral into a smear; the frieze's marks are crisp and have to stay so.
	vec2 q = p.xy;
	if (w.y > w.x && w.y > w.z) {
		q = p.xz;
	} else if (w.x > w.z) {
		q = p.zy;
	}
	q += drift + warp * heat * 0.55;

	vec3 albedo = ivory;
	float leaf = 0.0;
	float ink_mask = 0.0;
	vec3 accent = accent_teal;
	float accent_mask = 0.0;

	if (motif == MOTIF_IVORY) {
		// THE FIELD. Almost nothing: a warm ground with the faintest tooth and
		// the occasional fleck of leaf. Its whole job is to be quiet so the
		// other surfaces can speak, which is what a ceiling should do.
		// The quiet field, and quiet has to mean DARK here. A literal cream
		// ground next to melted gold reads as a flat lit panel -- a bright
		// featureless rectangle, which is the one thing a ceiling must never
		// be in a room whose whole subject is what the lamp finds. So the
		// ivory survives as a tint on near-black, and the field is carried by
		// rare flecks of leaf rather than by its own value.
		float grain = hash21(floor(q * 26.0));
		albedo = mix(ivory, ivory * 0.94, grain) * ground_dark * 0.35;
		float fleck = step(0.9955, hash21(floor(q * 9.0)));
		leaf = fleck;
		albedo = mix(albedo, gold_mid, fleck);
	} else if (motif == MOTIF_SPIRAL) {
		// THE TREE. Coils on an ivory ground, in two sizes so the wall has a
		// hierarchy rather than one repeating curl.
		vec2 cell = floor(q * 0.5);
		float h = hash21(cell);
		vec2 local = fract(q * 0.5) - 0.5;
		float big = spiral_line(local, 3.0 + h * 2.0, 0.115, 0.085);
		float small = spiral_line(local * 2.4 + 0.31, 2.0, 0.13, 0.10);
		float tendril = clamp(big + small * 0.6, 0.0, 1.0);
		// The connecting wire between coils, so the tree is one plant.
		float wire = smoothstep(0.035, 0.0,
				abs(local.y + sin(local.x * 6.0 + h * 6.28) * 0.12));
		tendril = clamp(tendril + wire * 0.5, 0.0, 1.0);
		leaf = tendril;
		albedo = mix(ivory * ground_dark, gold_mid, tendril);
		albedo = mix(albedo, gold_pale, smoothstep(0.75, 1.0, tendril));
		// The frieze hangs small dark buds and eyes off the branches.
		ink_mask = step(0.972, hash21(floor(q * 3.1)));
		accent_mask = step(0.986, hash21(floor(q * 2.3 + 11.0)));
		accent = accent_teal;
	} else if (motif == MOTIF_MOSAIC) {
		// THE TEXTILE, underfoot. Mostly gold, some ink, a little cream —
		// the ratio is what keeps a floor readable while still being ornament.
		float tone = 0.0;
		float m = mosaic_field(q, 0.09, tone);
		vec3 block = gold_deep;
		if (tone > 0.93) {
			block = ivory;
		} else if (tone > 0.74) {
			block = ink;
		} else if (tone > 0.30) {
			block = gold_mid;
		}
		albedo = mix(bole * ground_dark, block, m);
		leaf = m * step(tone, 0.74) * 0.95;
		ink_mask = m * step(0.74, tone) * step(tone, 0.93);
		accent_mask = m * step(0.975, hash21(floor(q / 0.09) + 3.7));
		accent = accent_oxblood;
	} else if (motif == MOTIF_TRIANGLE) {
		// THE ROBE OF EXPECTATION, on the doors. Directional and hard-edged,
		// so an opening announces itself as a thing you go THROUGH.
		float band = 0.0;
		float tri = triangle_field(q, 0.16, band);
		vec3 c = band > 0.72 ? ivory : (band > 0.4 ? ink : gold_mid);
		albedo = mix(ivory * ground_dark * 0.9, c, tri);
		leaf = tri * step(band, 0.4);
		ink_mask = tri * step(0.4, band) * step(band, 0.72);
		accent_mask = step(0.94, band) * tri;
		accent = accent_lapis;
	} else if (motif == MOTIF_EYE) {
		// THE ROBE OF FULFILMENT, on the hazards. Concentric eyes on a rich
		// bole ground. If a surface in this maze is watching you, it is
		// because it can hurt you.
		float pupil = 0.0;
		float rings = eye_field(q, 0.22, pupil);
		albedo = mix(bole * ground_dark * 2.2, gold_mid, rings);
		albedo = mix(albedo, ink, pupil);
		leaf = rings;
		ink_mask = pupil;
		accent_mask = step(0.93, hash21(floor(q / 0.22))) * rings;
		accent = accent_oxblood;
	} else {
		// THE FLOWERBED, at the foot of everything. Scattered coloured dots on
		// dark earth — the one place in the frieze where the palette opens up.
		vec2 g = q / 0.07;
		vec2 c = floor(g);
		float h = hash21(c);
		vec2 f = fract(g) - 0.5;
		float dot_mask = smoothstep(0.34, 0.20, length(f));
		vec3 petal = accent_teal;
		if (h > 0.78) {
			petal = accent_oxblood;
		} else if (h > 0.56) {
			petal = gold_mid;
		} else if (h > 0.34) {
			petal = accent_lapis;
		} else if (h > 0.16) {
			petal = ivory;
		}
		albedo = mix(bole * ground_dark, petal, dot_mask * step(0.35, h));
		leaf = dot_mask * step(0.56, h) * step(h, 0.78);
	}

	// THE MAZE BREATHES. A low-frequency field opens and closes the ornament so
	// a wall runs from thicket to bare ground and back, which is how the frieze
	// itself is composed -- dense marks against empty cream. Uniform clothing is
	// what turns ornament into wallpaper.
	float open = fbm(v_world.xz * breathe_scale
			+ vec2(0.0, TIME * drift_speed * 0.5));
	open = smoothstep(0.34, 0.72, open);
	float bare = 1.0 - breathe_depth * (1.0 - open);
	leaf *= bare;
	ink_mask *= bare;
	accent_mask *= bare;

	// One breath across everything, well under a hertz, so the leaf is never
	// quite still and never flickers.
	float breath = 0.94 + 0.06 * sin(t * TAU + v_world.x * 0.15);

	albedo = mix(albedo, accent, accent_mask * accent_amount);
	albedo = mix(albedo, ink, ink_mask * ink_weight);
	float metal = leaf * (1.0 - ink_mask);

	// THE MELT. Where the lamp is close and the surface is leaf, the gold stops
	// being a patterned solid and becomes liquid: the normal is perturbed by the
	// same flow that warped the pattern, roughness collapses toward a mirror,
	// and the fake environment is sampled through the result.
	float molten = metal * heat;

	// NO TANGENT FRAME EXISTS -- this is triplanar on untextured boxes, so
	// NORMAL_MAP is unavailable and a tangent-space perturbation would be
	// meaningless. Build an arbitrary orthonormal basis from the normal instead.
	// Arbitrary is fine: flow on a pool of metal has no preferred direction.
	vec3 up_ref = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tan_a = normalize(cross(up_ref, n));
	vec3 tan_b = cross(n, tan_a);
	float e = 0.06;
	vec2 fp = p.xz * 1.7 + vec2(ft * 0.23, ft * 0.19);
	float h0 = fbm(fp);
	float hx = fbm(fp + vec2(e, 0.0));
	float hy = fbm(fp + vec2(0.0, e));
	vec3 bumped = normalize(n
			+ (tan_a * (hx - h0) + tan_b * (hy - h0)) * 42.0 * molten);

	vec3 refl = reflect(-normalize(VIEW), bumped);
	vec3 env = sample_reflected_world(refl);

	ALBEDO = mix(albedo * breath,
			albedo * breath * 0.85 + gold_mid * 0.22, molten);
	METALLIC = mix(metal * gold_metallic, 0.95, molten);
	SPECULAR = mix(mix(0.25, 0.85, metal), 0.9, molten);
	// A mirror is smooth. The collapse toward zero roughness is most of why the
	// surface reads as liquid rather than as a shinier wall.
	ROUGHNESS = mix(mix(ground_roughness, gold_roughness, metal), 0.14,
			molten);
	NORMAL = mix(n, bumped, molten);
	// The reflection rides on EMISSION because Compatibility gives a shader no
	// other way to put an environment on a surface. It is gated by `molten`,
	// which is gated by heat, so it appears only where the lamp is -- the gold
	// still cannot glow on its own.
	EMISSION = albedo * metal * leaf_ember + env * molten * 0.30;
}
