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
#define MOTIF_CANOPY 0
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
// WHERE THE BEAM LANDS, and the reflection is a disc around it. `lamp_pos`
// is the splash point on the surface, NOT the lamp: a sphere centred on the
// lamp wraps the pool around whatever is nearest the player's hand, which put
// gold on walls the beam was not pointing at. `lamp_origin` is the fixture
// itself, kept only so the falloff can fade with how far the beam has thrown.
// THE LAMP IS A CONE THIS SHADER EVALUATES, NOT A LIGHT THAT FALLS ON IT.
//
// Owner direction: "instead of casting a light it makes the shaders animate
// and react." So what arrives is the lamp's POSE -- where it is, which way it
// points, how wide and how far -- and the surface decides for itself what to
// do about being looked at. Nothing here depends on the renderer's lighting,
// which is what was delivering flat per-face reflections and rectangular
// patches: a spotlight in Compatibility shades a box, and a box shades flat.
//
// It is also the truer idea. The gold is not lit by the lamp; it WAKES under
// it. Ornament resolves, metal softens and runs, rings travel out from where
// the beam is touching. Look away and it cools and forgets.
uniform vec3 lamp_origin = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform float lamp_reach = 4.6;
uniform float lamp_cos_outer = 0.86;
// How much of the cone's edge is falloff rather than hard boundary. A hard
// edge reads as a stencil; this is a lamp in a wire cage.
uniform float lamp_edge_soft : hint_range(0.01, 1.0) = 0.42;
uniform float lamp_energy = 1.0;
// SMALL, or the circle is never seen. At 4.6 m the disc was wider than the
// wall segments it landed on, so every face was entirely inside the pool and
// the falloff read as a rectangle -- the box's own edges standing in for a
// boundary the melt never reached.
uniform float melt_radius : hint_range(0.2, 12.0) = 1.35;
uniform float melt_flow : hint_range(0.0, 3.0) = 1.0;
// BEATEN LEAF IS NEVER FLAT, and this is the fix for the rectangles. A flat
// face has one normal, so its reflection vector is nearly constant across the
// whole face and the environment lands on it as ONE FLAT PATCH OF COLOUR --
// which is exactly the "weird rectangular frames" the light was arriving in.
// Every box in the maze was showing a single sample of the sky.
//
// So the surface carries a permanent micro-relief, independent of the melt:
// hammer marks, the tooth of gesso under leaf, the unevenness of a hand-laid
// sheet. It costs one fbm and it is what makes a wall a surface rather than a
// polygon.
uniform float leaf_relief : hint_range(0.0, 1.0) = 0.55;
// THE POOL EDGE. A spotlight cone is a perfect circle and reads as a stencil.
// Breaking the falloff with noise gives the light a ragged, guttering edge
// where it meets the geometry -- the lamp is a dirty tungsten bulb in a wire
// cage, not a projector.
uniform float pool_character : hint_range(0.0, 1.0) = 0.62;
// THE BEAM IS HEAT. Owner: "like the lantern beam is heat melting the surface
// into a rippling living surface that animates."
//
// So the melt is not a static wet patch, it is a surface under a blowtorch:
// rings travel OUTWARD from the splash the way heat spreads through metal,
// and a slow churn crawls underneath them so the pool is never twice the same
// shape. Both are gated on the disc, so the instant the beam moves the old
// pool cools and stops moving -- what animates is what is being heated NOW.
uniform float ripple_rate : hint_range(0.0, 6.0) = 2.1;
uniform float ripple_scale : hint_range(0.0, 40.0) = 13.0;
uniform float ripple_depth : hint_range(0.0, 2.0) = 0.85;
// THE DISH. Owner: "make the melted part of the wall the lamp points at
// concave, not flat."
//
// Metal under heat slumps: the middle goes first and runs, and what is left is
// a bowl with a lip. Flat-but-shiny reads as varnish; a dish reads as
// something that has actually GIVEN WAY, and it is the difference between a
// wall with a highlight on it and a wall that is failing while you look at it.
//
// The geometry cannot move -- these are static boxes and the collision has to
// stay honest, because a player must never be able to walk into a hole that is
// only a shader. So the concavity lives entirely in the NORMAL: the surface
// lies about its shape and the light believes it. At the rim the normal tilts
// inward toward the centre, at the centre it is unchanged, and the eye reads
// the whole patch as a depression.
uniform float dish_depth : hint_range(0.0, 3.0) = 1.35;
uniform float melt_amount : hint_range(0.0, 1.0) = 1.0;
// How liquid a surface is ever allowed to get. Below 1.0 on purpose: the
// pattern has to survive its own melting.
const float MOLTEN_CEILING = 0.62;

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

// ------------------------------------------------------------- the jewels ---
// Coloured stones in gold settings, hung in the tendrils. They are the one
// place the palette is allowed to sing, and they are the source of the floor:
// what drips off the canopy is what the mosaic underfoot is made of.
uniform float jewel_density : hint_range(0.0, 1.0) = 0.30;
uniform float jewel_gleam : hint_range(0.0, 2.0) = 0.85;

// -------------------------------------------------------- canopy and sky ---
// The ceiling is not a ceiling. It is tree canopy opening onto starfield: the
// tendrils close overhead in thickets and part into voids with stars in them,
// so a corridor with a roof reads as a corridor with a NIGHT over it.
uniform float canopy_close : hint_range(0.0, 1.0) = 0.52;
uniform float star_density : hint_range(0.0, 1.0) = 0.55;
uniform vec3 star_colour : source_color = vec3(0.86, 0.90, 1.0);

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Cheap value noise and a two-octave fbm. Enough for flow and for the
// breathing field; nothing here needs gradient noise.
// DEFINED FIRST, and it has to be. GLSL has no forward declarations, so a
// helper must appear above every function that calls it. `jewel()` was
// written above this one and calls it on its first line, which made the
// whole shader fail to compile -- and a spatial shader that fails to
// compile does not announce itself, it just falls back to a default
// material. Every 'washed out' frame between then and now was the
// FALLBACK being photographed, not a lighting problem, and several
// passes of tuning were spent on an image the shader was not drawing.
float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

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

// THE WORLD IN THE GOLD -- PROJECTED, NOT MIRRORED, AND THAT IS A CORRECTION.
//
// This sampled the plate by the REFLECTION VECTOR for several passes and never
// produced a recognisable thing, because the physics is against it: a flat
// surface reflects a very narrow cone of directions, so a mirror lookup
// stretches a few pixels of a 1774x887 plate across a whole wall. That is a
// smooth gradient by construction. No amount of gain or ripple recovers a face
// from it, and I spent passes trying.
//
// So the plate is PROJECTED onto the surface instead, triplanar like the
// ornament, and warped by the same flow that melts the gold. The concept is
// intact and arguably sharpened: the residents are IN the metal rather than
// reflected in it, they are still visible only where the lamp has woken the
// surface, and they still cannot be walked to. What changes is that you can
// now see who they are.
vec3 sample_reflected_world(vec2 q, float flow) {
	// Scaled so a figure is roughly body height on the wall rather than
	// microscopic: the plate is a frieze and wants to read at frieze size.
	vec2 uv = q * 0.055 + vec2(0.5, 0.5);
	uv += vec2(flow, flow * 0.6) * 0.06;
	return texture(reflected_world, uv).rgb * reflected_world_gain;
}


// A STONE IN A SETTING. A coloured cabochon inside a gold bezel, which is how
// every jewel in the frieze is drawn -- never a bare dot of colour, always a
// metal ring holding something. The ring is what makes it read as jewellery
// rather than as confetti.
// Returns coverage in .x, the metal bezel in .y, and which stone in .z.
vec3 jewel(vec2 q, float cell_size, float density) {
	vec2 g = q / cell_size;
	vec2 c = floor(g);
	float h = hash21(c);
	if (h > density) {
		return vec3(0.0);
	}
	vec2 f = fract(g) - 0.5;
	f += (vec2(fract(h * 31.7), fract(h * 71.3)) - 0.5) * 0.34;
	float r = length(f);
	float size = 0.16 + fract(h * 13.1) * 0.13;
	float stone = smoothstep(size, size * 0.72, r);
	float bezel = smoothstep(size * 1.34, size * 1.05, r) - stone;
	return vec3(stone, max(bezel, 0.0), fract(h * 97.3));
}


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
	// THE CONE, EVALUATED HERE. Distance falloff along the beam, angular
	// falloff across it, and the product is how awake this patch of surface
	// is. Because it is analytic it is continuous across every box in the
	// maze -- there are no per-object lighting decisions left to produce a
	// rectangle.
	vec3 to_frag = v_world - lamp_origin;
	float along = length(to_frag);
	vec3 ray = along > 0.0001 ? to_frag / along : vec3(0.0, 0.0, -1.0);
	float cone = smoothstep(lamp_cos_outer,
			mix(lamp_cos_outer, 1.0, lamp_edge_soft), dot(ray, lamp_dir));
	// Linear, not squared. Squared over a 4.6 m reach left a wall at 2.6 m
	// sitting at 19% and reading as black, while the floor a metre under the
	// lamp burned -- the beam lit the player's shoes and nothing they were
	// looking at.
	float reach = 1.0 - clamp(along / max(0.5, lamp_reach), 0.0, 1.0);
	reach = pow(reach, 0.65);
	// Facing matters: a surface edge-on to the beam wakes less than one square
	// to it, which is what keeps a corridor from lighting like a tunnel.
	float facing = clamp(dot(n, -ray), 0.0, 1.0);
	facing = mix(0.35, 1.0, facing);
	float heat = cone * reach * facing;
	// The splash -- where the beam's axis meets this surface -- is still what
	// the rings travel out from, and it is derived here rather than raycast.
	vec3 splash = lamp_origin + lamp_dir * (along * dot(ray, lamp_dir));
	heat = pow(heat, 1.7) * clamp(lamp_energy, 0.0, 4.0) * melt_amount;

	// THE FLOW. Domain warp, animated, scaled by heat -- so the ornament is
	// crisp where it is cold and runs where the light is on it. That is what
	// "melts and morphs when light hits it" means in a shader: the pattern's
	// own coordinates are what liquefy.
	float ft = TIME * melt_flow;
	// RINGS OUT OF THE SPLASH. Radial, travelling outward, and fading as they
	// go: this is the mark that says HEAT rather than "wet". The phase is a
	// function of world distance from the splash, so the rings stay pinned to
	// the point the beam is touching even while the player moves.
	float rad = distance(v_world, splash);
	float ring_fade = clamp(1.0 - rad / max(0.5, melt_radius), 0.0, 1.0);
	float rings_out = sin(rad * ripple_scale - TIME * ripple_rate)
			* ring_fade * ring_fade;
	// And a slow churn under them, so the metal is moving even where the rings
	// have passed. Two octaves at different rates never repeat visibly.
	float churn = fbm(v_world.xz * 3.1 + vec2(ft * 0.31, -ft * 0.24)) - 0.5;
	churn += (fbm(v_world.xz * 7.7 - vec2(ft * 0.19, ft * 0.27)) - 0.5) * 0.5;
	float living = (rings_out * 0.7 + churn * 1.3) * ripple_depth;
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
	q += drift + (warp + vec2(living, living * 0.7)) * heat * 0.55;

	vec3 albedo = ivory;
	float leaf = 0.0;
	float ink_mask = 0.0;
	vec3 accent = accent_teal;
	float accent_mask = 0.0;
	// Stones read as glass, not as metal: they take their own gleam and must
	// not be handed the leaf's molten treatment.
	float jewel_face = 0.0;
	// Stars carry their own light. Nothing else here does.
	float sky_glow = 0.0;

	if (motif == MOTIF_CANOPY) {
		// CANOPY OPENING ONTO NIGHT. A low-frequency field decides where the
		// tree closes overhead and where it parts; the thickets get tendrils,
		// the gaps get sky. Overhead is the one surface a player never has to
		// navigate by, so it is where the world can afford to stop being a
		// building at all.
		float cover = smoothstep(0.38, 0.70,
				fbm(q * 0.30 + vec2(TIME * drift_speed * 0.4, 0.0)));
		cover = mix(cover, 1.0, canopy_close * 0.35);
		vec2 local = fract(q * 0.42) - 0.5;
		float h = hash21(floor(q * 0.42));
		float branch = clamp(
				spiral_line(local, 2.0 + h * 3.0, 0.13, 0.075)
				+ spiral_line(local * 2.2 + 0.4, 2.0, 0.15, 0.09) * 0.55,
				0.0, 1.0);
		branch *= cover;
		// THE STARS. Points, not areas, and they carry their own faint light --
		// the single exception to "gold is never emissive", because a star IS a
		// light and not a leaf. They only appear where the canopy has parted.
		float sky = 1.0 - cover;
		float star_cell = hash21(floor(q * 34.0));
		float star = step(1.0 - star_density * 0.035, star_cell) * sky;
		float twinkle = 0.6 + 0.4 * sin(TIME * 0.7 + star_cell * 40.0);
		albedo = mix(ivory * ground_dark * 0.18, gold_mid, branch);
		albedo = mix(albedo, star_colour, star);
		leaf = branch;
		sky_glow = star * twinkle;
		// Jewels hang in the thickets, never in the open sky.
		vec3 jw = jewel(q, 0.30, jewel_density * cover);
		if (jw.x + jw.y > 0.0) {
			vec3 stone = jw.z > 0.66 ? accent_oxblood
					: (jw.z > 0.33 ? accent_lapis : accent_teal);
			albedo = mix(albedo, stone, jw.x);
			albedo = mix(albedo, gold_pale, jw.y);
			leaf = max(leaf, jw.y);
			jewel_face = jw.x;
		}
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
		accent = accent_teal;
		// STONES IN THE TENDRILS. Hung where the tree is dense, so the jewels
		// belong to the branches rather than being scattered over them -- and
		// so there is somewhere for them to fall FROM.
		vec3 jw = jewel(q, 0.26, jewel_density * (0.35 + tendril * 0.9));
		if (jw.x + jw.y > 0.0) {
			vec3 stone = jw.z > 0.66 ? accent_oxblood
					: (jw.z > 0.33 ? accent_lapis : accent_teal);
			albedo = mix(albedo, stone, jw.x);
			albedo = mix(albedo, gold_pale, jw.y);
			leaf = max(leaf, jw.y);
			jewel_face = jw.x;
		}
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
		accent = accent_oxblood;
		// WHERE THE DRIPS LANDED AND SET. Jewel-coloured tiles, clustered by a
		// low-frequency splash field rather than sprinkled evenly, so the floor
		// reads as having been rained on in places. The mosaic underfoot is
		// made of what fell off the canopy.
		float splash = smoothstep(0.46, 0.78, fbm(q * 0.55 + 19.0));
		float set_stone = m * step(0.62, hash21(floor(q / 0.09) + 3.7)) * splash;
		float which = hash21(floor(q / 0.09) + 77.0);
		vec3 stone = which > 0.66 ? accent_oxblood
				: (which > 0.33 ? accent_lapis : accent_teal);
		albedo = mix(albedo, stone, set_stone);
		jewel_face = max(jewel_face, set_stone * 0.7);
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
	// CAPPED, so a surface never fully liquefies. At full melt the normal is
	// smoothed, roughness collapses and the reflection swamps the albedo --
	// which erases the very ornament the melt is supposed to be happening TO.
	// Gold that has melted into a featureless pool is just a highlight.
	float molten = min(metal * heat, MOLTEN_CEILING);
	float woken = smoothstep(0.02, 0.55, heat);

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
	// The relief is ALWAYS present and the flow rides on top of it. Without
	// the first term the reflection has nothing to vary across and returns to
	// flat rectangles the moment the melt fades.
	vec2 rp = p.xz * 6.5;
	float r0 = fbm(rp);
	float rx = fbm(rp + vec2(e, 0.0));
	float ry = fbm(rp + vec2(0.0, e));
	vec3 relief = (tan_a * (rx - r0) + tan_b * (ry - r0)) * 26.0 * leaf_relief;
	// The living term goes into the NORMAL as well as the pattern. Without
	// this the ornament slides around on a flat plate; with it the plate
	// itself is undulating and the light moves across the swell.
	vec3 wave = (tan_a * rings_out + tan_b * churn) * 1.9 * molten
			* ripple_depth;

	// THE DISH. Direction from this fragment back toward the splash, flattened
	// into the surface, so every point on the rim leans in toward the middle.
	// Strength peaks at the rim and falls to nothing at dead centre -- which
	// is what a bowl's normals actually do, and why this reads as depth rather
	// than as a dark ring.
	vec3 to_centre = splash - v_world;
	to_centre -= n * dot(to_centre, n);
	float dish_r = clamp(rad / max(0.25, melt_radius), 0.0, 1.0);
	float lip = sin(dish_r * PI);
	vec3 dish = vec3(0.0);
	if (length(to_centre) > 0.0001) {
		dish = normalize(to_centre) * lip * dish_depth * molten;
	}
	vec3 bumped = normalize(n + relief + wave + dish
			+ (tan_a * (hx - h0) + tan_b * (hy - h0)) * 42.0 * molten);

	vec3 refl = reflect(-normalize(VIEW), bumped);
	vec3 env = sample_reflected_world(q, living);

	// A stone is not leaf and must not melt: glass has its own hard little
	// highlight and no flow at all, which is what separates a jewel from a
	// puddle of gold beside it.
	molten *= 1.0 - jewel_face;

	// THE WAKING. This is the shader doing what the light used to: the
	// ornament is nearly absent on cold surface and resolves as the cone
	// finds it, so sweeping the beam does not reveal a lit wall -- it brings
	// a wall INTO EXISTENCE and lets it fall back out.
	vec3 cold = albedo * 0.06;
	vec3 warm = mix(albedo * breath,
			albedo * breath * 0.85 + gold_mid * 0.22, molten);
	// THE WAKING IS EMISSIVE, and it has to be. The cone response was
	// modulating ALBEDO, which the renderer then multiplies by the actual
	// light -- and the actual light is now deliberately dim, because the
	// shader took its job. So the surface was being darkened twice and the
	// whole world went black.
	//
	// If the lamp WAKES the gold rather than lighting it, then the waking is
	// the surface's own output. The SpotLight3D keeps only the one job no
	// shader can do -- casting the Tenant's borrowed shadow -- and everything
	// visible here is the metal answering for itself.
	ALBEDO = mix(cold, warm, woken);
	// Modest. The waking is what makes the gold visible at all now, so it is
	// tempting to push it -- but emission is not attenuated by anything and at
	// arm's length from a wall it blows the frame white. This is the level at
	// which a surface reads as answering the beam rather than as a lamp in its
	// own right.
	float wake_glow = woken * (0.05 + 0.26 * heat);
	METALLIC = mix(metal * gold_metallic, 0.95, molten);
	SPECULAR = mix(mix(0.25, 0.85, metal), 0.9, molten);
	// A mirror is smooth. The collapse toward zero roughness is most of why the
	// surface reads as liquid rather than as a shinier wall.
	ROUGHNESS = mix(mix(ground_roughness, gold_roughness, metal), 0.14,
			molten);
	ROUGHNESS = mix(ROUGHNESS, 0.08, jewel_face);
	SPECULAR = mix(SPECULAR, 1.0, jewel_face * 0.8);
	NORMAL = mix(n, bumped, molten);
	// The reflection rides on EMISSION because Compatibility gives a shader no
	// other way to put an environment on a surface. It is gated by `molten`,
	// which is gated by heat, so it appears only where the lamp is -- the gold
	// still cannot glow on its own.
	// HOLD DETAIL AT THE CORE (owner ruling). The reflection used to run away
	// with the highlight and blow the middle of every molten pool to flat
	// white. Compressing it through its own reciprocal keeps the pool bright
	// while leaving the pattern legible right through the hottest part -- the
	// point being that molten gold has FIGURE in it, and a blown core has none.
	// Gated on WOKEN rather than on the melt, so the figures resolve as the
	// beam finds them instead of only in the hottest centre of the pool.
	vec3 lit = env * woken * heat * 0.9;
	lit = lit / (1.0 + lit * 0.85);
	EMISSION = warm * wake_glow + albedo * metal * leaf_ember + lit
			+ star_colour * sky_glow * 0.55
			+ albedo * jewel_face * jewel_gleam * 0.16;
}
