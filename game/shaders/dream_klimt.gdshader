shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream_architecture_relief.gdshaderinc"
#include "res://shaders/dream_phase_transition.gdshaderinc"

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

// ================================================ THE REAL SURFACE, FIRST ===
// Owner: "the pattern is way too regular and too much of the environment is
// revealed as a simple hallway. can we use this shader as a filter over the
// normal texture system?"
//
// Yes, and it is the better architecture -- it also puts back something the
// original brief demanded and the procedural pass had quietly thrown away:
// "at arm's length, this is indisputably the Orison." A generated spiral field
// can never deliver that, because it is not the building; it is a pattern the
// building has been replaced BY. Photographed plaster is.
//
// So the base is the real material library -- 1024px albedo, normal and
// roughness per surface, the same plaster, tin ceiling and terrazzo the waking
// Orison names in its own catalog -- and everything this shader used to draw
// becomes a FILTER consuming it. The dream is now the Orison being eaten
// rather than a golden corridor that resembles one.
//
// It also fixes the regularity outright. The irregularity is photographic now:
// real stains, real trowel marks, real wear. No amount of fbm buys that.
uniform sampler2D base_albedo : source_color, filter_linear_mipmap,
		repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap,
		repeat_enable;
uniform sampler2D base_rough : hint_default_white, filter_linear_mipmap,
		repeat_enable;
// Real-world size of one texture tile, so a 1024px plaster sheet is about a
// metre of wall rather than an arbitrary UV repeat.
uniform float base_tile_m : hint_range(0.1, 8.0) = 1.15;
// How much of the frame is still the real building versus the gold that is
// consuming it. This is the dial the whole look now turns on.
uniform float consumed : hint_range(0.0, 1.0) = 0.55;
// How much of the latent gold shows with no lamp on it. Deliberately low but
// never zero: the world has to stay navigable in the dark (owner ruling
// 2026-08-18), and a surface at flat zero reveal is a black shape with no
// grain to read a corner by. This is what the black level actually lights.
uniform float unlit_reveal : hint_range(0.0, 1.0) = 0.22;

// ============================================== THE EXPOSURE FIELD ==========
// WHAT THE LAMP HAS ALREADY TAKEN, AND DOES NOT GIVE BACK.
//
// Workstream A of design/DREAM_SURFACE_REDESIGN_BRIEF.md, whose diagnosis of
// what used to be here is exact: "Exposure is instantaneous, not accumulated.
// `heat` is recomputed every frame from the lamp cone, so gold appears while
// lit and vanishes when the beam moves. Every plate shows the opposite: the
// conversion STAYS."
//
// So the conversion no longer reads the cone. It reads a coarse world-space
// volume that DreamExposureField accumulates on the CPU -- written by the lamp
// by dwell, seeded per room by DreamAtlas.decay(), and zeroed only when the
// pocket forgets the room it belongs to. `heat` still exists and still does
// the thing it was always right about: the MELT, which is the live beam
// heating metal and correctly stops when the beam leaves.
//
// hint_default_black is load-bearing, not tidiness. An unbound sampler in
// Godot defaults to WHITE, and white here means "every surface fully
// converted" -- so any path that builds a Klimt material without a field
// (every headless suite, the shot harnesses, DreamWalk before the root
// finishes) would render a solid gold building and look like a shader bug
// rather than a missing binding. Black fails to the real Orison.
uniform sampler3D exposure_tex : filter_linear, repeat_enable,
		hint_default_black;
// The tile, in metres. XZ wrap; see dream_exposure_field.gd for why the field
// tiles instead of following the player.
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;
// How hard the field pushes the dream through the real building.
//
// THIS REPLACES `lamp_reveal_gain`, which is retired rather than renamed: its
// meaning ("how hard the CONE pushes") no longer exists, and a uniform that
// keeps its name while changing what it multiplies is how a tuning value
// silently stops meaning what every comment around it says.
//
// It also carries the dormant lock. DreamMazeBuilder sets it to zero on scar
// materials, and `responds` below turns that into a hard gate rather than a
// small number -- "Dormant scars must stay visibly dead: they never turn gold
// at any light level" is a ruled requirement, and a smoothstep against noise
// leaks a few percent of gold in its darkest valleys, which is not zero.
uniform float exposure_gain : hint_range(0.0, 4.0) = 1.0;
// R5: one transition controller for the real Orison and the body under it.
// The first pair preserves R2's architectural onset; the second pair owns the
// rupture.  The later pair is the only currently licensed material phase:
// flesh into persistent living gold. Frost/liquid/embrace remain proposals.
uniform vec4 phase_stage_thresholds = vec4(0.10, 0.34, 0.48, 0.78);
uniform vec2 phase_gold_thresholds = vec2(0.70, 0.92);
// THE FRONTIER, and workstream B in one line: "Threshold the exposure field
// through domain-warped fbm so the boundary bulges and creeps." These are the
// shape of that threshold.
//
// `front_scale` is in world metres and NOT in pattern units, so the growth
// front keeps its real-world size when a surface class retunes pattern_scale
// -- the mass creeping across a wall and the mass creeping across the floor
// beside it have to be the same organism at the same scale or the corner
// gives it away.
uniform float front_scale : hint_range(0.05, 4.0) = 0.55;
uniform float front_warp : hint_range(0.0, 3.0) = 1.15;
// How narrow the transition is. Small, because the plates show a ragged but
// CRISP edge -- tesserae stop, plaster starts. The raggedness comes from the
// noise the threshold is taken against, not from blurring the boundary.
uniform float growth_soft : hint_range(0.001, 0.5) = 0.085;
// A little conversion before the field has really arrived, so a surface the
// beam has merely crossed is touched rather than untouched.
uniform float growth_bias : hint_range(-0.5, 0.5) = 0.05;
// FILAMENTS RUNNING AHEAD OF THE MASS. Ridged noise has thin, connected,
// low-lying valleys, so mixing it into the threshold field converts narrow
// tendrils well before the bulk around them -- which is what "it should read
// as spreading, with fine filaments running ahead of the main mass" asks for,
// and what separates lichen from a stain.
uniform float filament_reach : hint_range(0.0, 1.0) = 0.42;
// R2: the infection favours the Orison's actual construction joints. Bounds
// are room-local facts supplied by DreamRoomBuilder; the shader consumes them
// only as a bias on the one durable exposure field.
uniform vec4 architecture_bounds = vec4(0.0);
uniform float architecture_clear_ceiling = 3.015;
uniform int architecture_surface : hint_range(0, 7) = 0;
uniform float architecture_pull : hint_range(0.0, 0.35) = 0.0;
// Meter-valued height terms. They perturb the durable solid surface and never
// change collision, silhouette or navigation.
uniform float tessera_relief_m : hint_range(0.0, 0.03) = 0.011;
uniform float medallion_relief_m : hint_range(0.0, 0.06) = 0.034;
uniform float relief_parallax : hint_range(0.0, 1.0) = 0.62;
// 0 normal, 1 architecture pull, 2 relief height, 3 stage bands.
uniform int surface_debug_view : hint_range(0, 3) = 0;
// WHAT COOLED GOLD LOOKS LIKE WITH NO BEAM ON IT.
//
// The brief's acceptance list wants "gold that persists after the beam has
// moved away", and persistence nobody can see is not persistence: everything
// visible in this shader is carried by EMISSION gated on `woken`, which is
// gated on the live cone, so converted-but-unlit gold would render at
// `albedo * 0.06` and be indistinguishable from the plaster it replaced.
//
// This is deliberately far below the lit value. The constraint that "gold is
// metallic, never emissive" is really the ruling that THE LAMP IS A DECISION,
// and it survives: lighting a converted wall is still worth an order of
// magnitude more than not. What this buys is that you can see you already
// took it.
//
// SET FROM MEASUREMENT, WITH THE RATIO STATED -- the kickoff log's rule, and
// the first value here broke it. 0.075 was a guess, and the acceptance frame
// it produced was black: mean frame luminance 0.05 against 0.03 for a room
// that had never been lit, which is not a difference anyone can see.
//
// Swept at 0.075 / 1.5 / 4.0 through DreamExposureShot and read back off the
// PNGs (art/renders/dream_exposure/sweep_*):
//
//   glow   unlit-converted   lit      ratio
//   0.075       0.03         5.22     invisible
//   1.50        0.74         7.40     ~10%
//   4.00       15.15        16.73     ~91%  -- the lamp stops mattering
//
// 4.0 renders a room you have already swept as brightly with the lamp off as
// with it on, which would retire the one decision the whole passage turns on.
// 1.5 is an order of magnitude below the lit surface: legible enough that you
// can see you already took this wall, dim enough that you still want the beam.
uniform float settled_glow : hint_range(0.0, 6.0) = 1.5;

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
uniform float accent_amount : hint_range(0.0, 1.0) = 0.80;
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
// WHERE THE BEAM ACTUALLY LANDS, raycast on the CPU and handed over as ONE
// POINT. This was previously derived per fragment by projecting the fragment
// onto the beam axis, which makes `rad` the perpendicular distance from the
// AXIS -- so the melt was an infinite cylinder running down the beam instead
// of a pool on a wall, and every face the cylinder passed through lit up whole.
// Those were the rectangular prisms of light.
uniform vec3 lamp_splash = vec3(0.0);
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
uniform float melt_radius : hint_range(0.2, 12.0) = 1.9;
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

// THE BOWL IS THE ONLY MIRROR. Owner ruling, and it is the physically honest
// model as well as the better-looking one: molten metal is a mirror, and solid
// metal a few centimetres away is not -- it is just hot, and hot metal GLOWS
// FROM INSIDE.
//
// Before this the reflection was gated on the whole cone, so every flat face
// the beam touched took a broad patch of environment. A flat face reflects one
// narrow solid angle, so that patch was near-constant across the face and
// landed as a rectangle -- the "rectangular prisms of light". Confining the
// mirror to the dish removes every large flat reflective area in the scene,
// which is what was producing them.
uniform float bowl_tightness : hint_range(0.5, 8.0) = 2.6;
// Partially masked, never a clean disc: a disturbed liquid surface only
// mirrors where it happens to be flat at that instant.
uniform float bowl_breakup : hint_range(0.0, 1.0) = 0.62;
// Incandescence. What the gold does everywhere the bowl is not: glows with the
// heat it is taking, deep ember at the edge of the beam through to pale gold
// where it is about to run.
uniform vec3 ember_cold : source_color = vec3(0.420, 0.105, 0.030);
uniform vec3 ember_hot : source_color = vec3(1.0, 0.62, 0.22);

// ============================================================== THE PAINT ===
// Owner: "i need it to look painted with liquid metal gold and oil paint,
// being actively reshaped by ghosts of the past and flights of fantasy, fresh
// and vibrant with unreality."
//
// Procedural line-work alone cannot get there. A drawn spiral is a diagram of
// an ornament; what makes a Klimt panel is that the ornament is MADE OF
// something -- leaf laid in squares that do not quite meet, oil dragged in
// loaded strokes that hold their own edge, cracks opening across both as they
// age. All of that is material rather than pattern, so it goes in as its own
// layers underneath the motifs rather than as more motifs.
//
// Five layers, each doing a job no other one can:
//   BRUSH        directional strokes that break colour and carry impasto
//   LEAF SEAMS   the square sheets gold is actually applied in
//   CRAQUELURE   the crack network across aged leaf and paint
//   GLAZE        slow hue drift, so no two square metres are the same gold
//   GHOSTS       the reflected world surfacing through the surface
uniform float paint_amount : hint_range(0.0, 1.0) = 0.85;
// Stroke scale and how hard the paint stands off the panel.
uniform float brush_scale : hint_range(1.0, 60.0) = 22.0;
uniform float impasto : hint_range(0.0, 4.0) = 1.6;
// Gold is beaten into squares roughly 80 mm across and laid overlapping. The
// seams catch light differently and are most of why real gilding has a grid
// you can only see at an angle.
uniform float leaf_sheet_m : hint_range(0.02, 0.5) = 0.085;
uniform float leaf_seam_strength : hint_range(0.0, 1.0) = 0.55;
uniform float craquelure : hint_range(0.0, 1.0) = 0.45;
// Hue drift across the panel. "Fresh and vibrant with unreality" is mostly
// this: a single flat gold reads as plastic, and a gold that wanders through
// green-gold, rose-gold and bronze reads as pigment.
uniform float glaze_drift : hint_range(0.0, 1.0) = 0.62;
uniform vec3 glaze_a : source_color = vec3(0.36, 0.62, 0.30);
uniform vec3 glaze_b : source_color = vec3(0.72, 0.28, 0.42);
uniform vec3 glaze_c : source_color = vec3(0.22, 0.42, 0.78);
// THE GHOSTS. The residents surfacing through the ornament, unbidden and
// nowhere near the lamp -- flights of fantasy rather than reflection. Slow,
// large, and never quite resolving.
uniform float ghost_amount : hint_range(0.0, 1.0) = 0.72;
uniform float ghost_scale : hint_range(0.005, 0.2) = 0.020;
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


// A FLOW FIELD FOR THE BRUSH. Strokes must follow something or they read as
// noise; a painter's hand follows the form. Two octaves of angle noise give a
// field that curls around the panel, and every stroke lies along it.
vec2 brush_dir(vec2 q) {
	float a = fbm(q * 0.35) * TAU * 2.0 + fbm(q * 0.9 + 4.1) * 2.0;
	return vec2(cos(a), sin(a));
}

// LOADED STROKES. Sampling along the flow direction and against it gives a
// smeared, ridged field -- long in the direction of travel, sharp across it,
// which is what a bristle actually leaves. Returns the stroke body in .x and
// its ridge (the raised edge where paint piles up) in .y.
vec2 brush(vec2 q, float scale) {
	vec2 dir = brush_dir(q * 0.5);
	vec2 across = vec2(-dir.y, dir.x);
	// Stretched along the stroke, compressed across it.
	vec2 sq = vec2(dot(q, dir) * 0.22, dot(q, across)) * scale;
	float body = fbm(sq);
	float ridge = 1.0 - abs(fract(sq.y * 0.5) * 2.0 - 1.0);
	ridge = pow(clamp(ridge, 0.0, 1.0), 3.0);
	return vec2(body, ridge * smoothstep(0.35, 0.75, body));
}

// THE SHEETS. Gold leaf arrives in squares and is laid by hand overlapping, so
// the panel carries a faint grid of doubled edges. Returns seam proximity.
float leaf_seams(vec2 q, float sheet) {
	vec2 g = q / sheet;
	// Each row and column is nudged, because no gilder lays a true grid.
	g.x += hash21(vec2(floor(g.y), 3.0)) * 0.22;
	g.y += hash21(vec2(floor(g.x), 7.0)) * 0.22;
	vec2 f = abs(fract(g) - 0.5);
	float seam = max(smoothstep(0.46, 0.5, f.x), smoothstep(0.46, 0.5, f.y));
	return seam;
}

// CRAQUELURE. Ridged noise makes a connected network of thin dark lines --
// close enough to the way a gesso ground cracks under leaf, and far cheaper
// than a Voronoi.
float cracks(vec2 q) {
	float n = fbm(q * 3.7);
	float ridged = 1.0 - abs(n * 2.0 - 1.0);
	float fine = 1.0 - abs(fbm(q * 9.1 + 2.7) * 2.0 - 1.0);
	return pow(clamp(ridged * 0.65 + fine * 0.45, 0.0, 1.0), 9.0);
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
	vec3 splash = lamp_splash;
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

	// THE BUILDING, SAMPLED FIRST. Triplanar because these are untextured
	// boxes with no UVs worth using -- the same axis choice the ornament uses,
	// so surface and filter stay in register.
	//
	// Projected from the RAW world position, NOT from p. This used to read
	// `q / (base_tile_m * pattern_scale) * 6.0`, and since q descends from
	// `p = v_world * pattern_scale` the term appeared in both numerator and
	// denominator and cancelled outright. What survived was `6.0 * v_world /
	// base_tile_m`: every 1024px sheet pinned to 19.2 cm of wall whatever
	// base_tile_m claimed, about 101 repeats along the 19.3 m hall. The
	// uniform's own comment promised "about a metre". A photograph repeating
	// five times a metre is not read as a photograph, it is read as tiling --
	// which is exactly the complaint this filter was built to answer.
	vec2 base_q = v_world.xy;
	if (w.y > w.x && w.y > w.z) {
		base_q = v_world.xz;
	} else if (w.x > w.z) {
		base_q = v_world.zy;
	}
	// The melt still drags the photograph with it, but converted back into
	// metres: drift and warp were accumulated in pattern units.
	base_q += (drift + (warp + vec2(living, living * 0.7)) * heat * 0.55)
			/ max(0.001, pattern_scale);
	vec2 bt = base_q / max(0.05, base_tile_m);
	vec3 surface = texture(base_albedo, bt).rgb;
	float surface_rough = texture(base_rough, bt).r;
	vec3 surface_n = texture(base_normal, bt).rgb * 2.0 - 1.0;

	vec3 albedo = ivory;
	float leaf = 0.0;
	float ink_mask = 0.0;
	vec3 accent = accent_teal;
	float accent_mask = 0.0;
	// Stones read as glass, not as metal: they take their own gleam and must
	// not be handed the leaf's molten treatment.
	float jewel_face = 0.0;
	// How far this fragment has been consumed. Set below, used at the bottom
	// to keep unconsumed plaster from behaving like metal.
	float metal_hint = 0.0;
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

	// ============================================ THE BUILDING UNDERNEATH ===
	// The motif above produced the GOLD. Here it meets the real surface, and
	// what decides between them is entropy: a slow field that says how far
	// this patch of the Orison has already been eaten.
	//
	// Entropy is high where the ornament is dense, so the gold is not painted
	// ON the building -- it is what the building turns INTO, and the tendrils
	// are the front line of it. Away from them the plaster is just plaster,
	// dark and cold and real.
	float rot = fbm(v_world.xz * 0.28 + vec2(TIME * 0.006, 0.0));
	// Preserve the unconsumed motif as the layout for R2 tesserae. `leaf` is
	// phase-gated below; sampling that diminished value again made the relief
	// disappear at Stage 1, while ignoring the motif entirely tiled the whole
	// wall as black graph paper. The spiral is the mosaic's drawing.
	float relief_motif = clamp(leaf, 0.0, 1.0);
	// How much gold this fragment COULD become. Entropy is high where the
	// ornament is dense, so the dream is latent in the building's own
	// pattern rather than painted over it.
	float latent = clamp(consumed * (0.35 + 1.3 * leaf) + rot * 0.45 - 0.2,
			0.0, 1.0);

	// ============================================ THE EXPOSURE FIELD ========
	// HOW MUCH OF HER HAS BEEN UNCOVERED HERE. See the uniform block above.
	//
	// A world-space read, which is the same decision the triplanar sampling
	// already made and for the same reason: the ornament has to run
	// CONTINUOUSLY from one module into the next, and the mass growing
	// through a wall and the mass growing across the floor it meets are one
	// organism. Nothing about this is per-object, so nothing about it has to
	// be unwrapped on geometry that is generated at runtime.
	//
	// X and Z wrap with the sampler. Y is clamped to the middle of the first
	// and last layers by hand: the field is a single storey and a ceiling
	// bleeding onto a floor through the repeat would be a coordinate bug
	// wearing the costume of an effect.
	float ex_y = clamp(v_world.y / max(0.001, exposure_height),
			0.0625, 0.9375);
	float field = texture(exposure_tex, vec3(v_world.x / exposure_extent,
			v_world.z / exposure_extent, ex_y)).r;
	float architecture_mask = dream_architecture_anchor(v_world, n,
			architecture_bounds, architecture_clear_ceiling,
			architecture_surface);
	float architecture_drive = architecture_mask * architecture_pull;

	// THE GROWTH FRONT. Domain-warped fbm, thresholded against how far the
	// conversion has advanced -- so the boundary is an iso-contour of noise
	// rather than the rim of a cone, and it BULGES AND RETREATS as it grows
	// because that is what a noise contour does when you raise its level.
	//
	// In metres, deliberately: `front_scale` multiplies v_world directly and
	// not `p`, so the organism keeps one size across surface classes that
	// each retune pattern_scale for their own ornament.
	// Every local here is front_-prefixed. `fp` and `ridge` are both already
	// taken further down fragment() by the melt's height-gradient sampling,
	// and GLSL redefinition in the same scope is a compile error -- which
	// Godot answers by silently falling back to a default material, so the
	// build still runs and the world renders untextured. That is the exact
	// trap the kickoff log records twice; the only reason it was caught here
	// is that the run was grepped rather than believed.
	vec2 front_q = v_world.xz * front_scale;
	vec2 front_wobble = vec2(fbm(front_q + vec2(3.1, 7.7)),
			fbm(front_q * 1.13 + vec2(-5.3, 1.9))) - 0.5;
	vec2 front_p = front_q + front_wobble * front_warp;
	float front_mass = fbm(front_p);
	// Ridged: valleys are thin and connected where the plain noise's are
	// round and isolated. Multiplying pulls those channels DOWN, and a lower
	// threshold converts sooner -- so the tendrils arrive first and the bulk
	// follows them, rather than the mass advancing as a blob with a rough
	// edge.
	float front_ridge = abs(fbm(front_p * 3.7) * 2.0 - 1.0);
	float front_gate = mix(front_mass, front_mass * front_ridge,
			filament_reach);
	// A hard gate, not a small multiplier. See exposure_gain's comment: a
	// scar has to be dead at EVERY light level, and smoothstep against noise
	// leaks in its darkest valleys.
	float responds = step(0.0001, exposure_gain);
	float advance = clamp(field * exposure_gain + architecture_drive,
			0.0, 1.0);
	vec4 phase_state = dream_phase_state(advance, phase_stage_thresholds,
			phase_gold_thresholds);
	float front = responds * smoothstep(-growth_soft, growth_soft,
			advance + growth_bias - front_gate);
	// THE DREAM WINS WHERE IT HAS ALREADY WON. Owner ruling 2026-08-18: "the
	// light should make the dream shader overcome the 'reality shader' making
	// the underlying weird gold matrix reveal itself." That ruling stands --
	// what changed is that winning is now a RECORD rather than a state.
	//
	// The line here used to be
	//
	//   latent * (unlit_reveal + (1 - unlit_reveal) * heat * lamp_reveal_gain)
	//
	// and `heat` is the live cone, so the gold arrived with the beam and left
	// with it. The whole surface redesign turns on that being wrong. `front`
	// is the same quantity taken against the accumulated field instead, so
	// the beam still causes the conversion and no longer owns it.
	//
	// `unlit_reveal` keeps its meaning exactly -- what shows where the field
	// has NOT reached -- and therefore keeps both behaviours it was carrying:
	// the eyes are near-invisible unlit so a hazard costs light to see, and a
	// scar at zero shows nothing ever.
	//
	// It still multiplies `latent` rather than adding, which still matters:
	// exposure cannot manufacture gold where the building has no ornament to
	// turn into, so a blank wall stays a blank wall however long it is held
	// in the beam.
	float eaten = clamp(latent * (unlit_reveal
			+ (1.0 - unlit_reveal) * front), 0.0, 1.0);
	// Stage bands share the same drive as the growth front. Architectural
	// seams can invite a stage earlier, but cannot create a second field or
	// bypass the dormant-scar lock.
	float relief_stage_one = responds * phase_state.x
			* smoothstep(0.015, 0.20, eaten);
	float relief_stage_two = responds * phase_state.y
			* smoothstep(0.16, 0.50, eaten);

	// Under the gold, the real wall -- darkened, because the dream is lit by
	// one lamp and plaster is not a light source.
	vec3 real_wall = surface * 0.55;
	albedo = mix(real_wall, albedo, eaten);
	// Every motif channel counts only where the surface has actually turned.
	// The old pass gated leaf but allowed glaze, ink, jewels and paint relief
	// to keep processing the real plaster underneath.  That made the promised
	// photographic base mathematically unreachable: even an uneaten wall was
	// recoloured and embossed like the frieze.  `eaten` is the single phase
	// boundary for all of them now.
	leaf *= eaten;
	ink_mask *= eaten;
	accent_mask *= eaten;
	jewel_face *= eaten;
	metal_hint = eaten;

	// ===================================================== THE PAINT ========
	// Applied AFTER the motif has chosen its colours and BEFORE the melt, so
	// the paint is what the ornament is made of rather than a film over it.
	float paint_gate = paint_amount * metal_hint;
	vec2 pq = q * 0.9;
	vec2 br = brush(pq, brush_scale * 0.05);
	float seam = leaf_seams(pq * 0.5, leaf_sheet_m * 12.0);
	float crack = cracks(pq * 0.7);

	// GLAZE. Three thin colours drifting across the panel at different rates,
	// so the gold wanders green, rose and bronze instead of sitting at one
	// hue. This is most of "vibrant with unreality".
	float g1 = fbm(v_world.xz * 0.55 + vec2(TIME * 0.004, 0.0));
	float g2 = fbm(v_world.xz * 0.38 + vec2(0.0, TIME * 0.003) + 9.3);
	vec3 glaze = mix(glaze_a, glaze_b, smoothstep(0.35, 0.65, g1));
	glaze = mix(glaze, glaze_c, smoothstep(0.45, 0.8, g2));
	// MIXED, not multiplied. A glaze that multiplies a gold albedo returns
	// gold, which is why the first pass stayed monochrome no matter how hard
	// it was pushed. Displacing the hue toward the glaze -- while keeping the
	// original's luminance so the ornament's drawing survives -- is what makes
	// a panel wander green-gold to rose to bronze across a few metres.
	float keep_lum = dot(albedo, vec3(0.299, 0.587, 0.114));
	vec3 tinted = glaze * (0.35 + 1.5 * keep_lum);
	albedo = mix(albedo, tinted, glaze_drift * paint_gate);

	// The stroke breaks the colour: paint is never one value across a mark,
	// it is loaded at the start of the stroke and starved at the end.
	albedo *= mix(1.0, 0.55 + 0.9 * br.x, paint_gate);
	// Raised paint catches the light and reads pale; the ridge is where the
	// bristle piled it up.
	albedo = mix(albedo, albedo + gold_pale * 0.45, br.y * paint_gate);
	// Seams and cracks are DARK, always: they are places the ground shows
	// through, and they are what stop the surface reading as a print.
	albedo = mix(albedo, albedo * 0.45, seam * leaf_seam_strength
			* paint_gate);
	albedo = mix(albedo, albedo * 0.30, crack * craquelure * paint_gate);

	// GHOSTS OF THE PAST. The residents surfacing through the panel, large and
	// slow and unrelated to the lamp -- so the world is being reshaped by them
	// rather than merely reflecting them. Deliberately never resolving: they
	// arrive as a tonal swell in the ornament and sink again.
	vec2 gq = v_world.xz * ghost_scale + vec2(TIME * 0.0035, TIME * 0.0021);
	vec3 ghost = texture(reflected_world, gq).rgb;
	float ghost_lum = dot(ghost, vec3(0.299, 0.587, 0.114));
	float surfacing = smoothstep(0.22, 0.72, ghost_lum)
			* (0.55 + 0.45 * sin(TIME * 0.11 + v_world.x * 0.2));
	albedo = mix(albedo, albedo * 0.6 + ghost * 1.1,
			surfacing * ghost_amount * metal_hint);

	// One breath across everything, well under a hertz, so the leaf is never
	// quite still and never flickers.
	float breath = 0.94 + 0.06 * sin(t * TAU + v_world.x * 0.15);

	albedo = mix(albedo, accent, accent_mask * accent_amount);
	albedo = mix(albedo, ink, ink_mask * ink_weight);
	// R2 SURFACE: the fine spiral field is divided into actual tessera faces,
	// with the gaps staying dark and nonmetallic. At the denser centre, large
	// concentric bosses rise through those tiles and their leaf cracks open.
	float tessera_face = dream_tessera_face(base_q);
	float tessera_grout = (1.0 - tessera_face) * relief_stage_one
			* relief_motif;
	float tessera_gold = tessera_face * relief_stage_one * relief_motif;
	float medallion_height = dream_medallion_height(base_q)
			* relief_stage_two;
	float medallion_edge = dream_medallion_edge(base_q)
			* relief_stage_two;
	float leaf_crack = dream_leaf_crack(base_q) * relief_stage_two
			* smoothstep(0.08, 0.45, medallion_height);
	albedo = mix(albedo, gold_mid, tessera_gold * 0.34);
	albedo = mix(albedo, bole * 0.16, tessera_grout * 0.92);
	albedo = mix(albedo, gold_pale, medallion_edge * eaten * 0.42);
	albedo = mix(albedo, albedo * 0.16, leaf_crack * eaten * 0.88);
	leaf = max(leaf, tessera_gold * 0.62);
	leaf = max(leaf, medallion_height * eaten * 0.88);
	float metal = leaf * (1.0 - ink_mask);
	metal *= 1.0 - tessera_grout;
	metal *= 1.0 - leaf_crack * 0.82;

	// THE MELT. Where the lamp is close and the surface is leaf, the gold stops
	// being a patterned solid and becomes liquid: the normal is perturbed by the
	// same flow that warped the pattern, roughness collapses toward a mirror,
	// and the fake environment is sampled through the result.
	// CAPPED, so a surface never fully liquefies. At full melt the normal is
	// smoothed, roughness collapses and the reflection swamps the albedo --
	// which erases the very ornament the melt is supposed to be happening TO.
	// Gold that has melted into a featureless pool is just a highlight.
	float molten = min(metal * heat, MOLTEN_CEILING);
	// How far out of the bowl this fragment is, 0 at the splash and 1 at the
	// rim. Declared here because both the normal's dish and the reflection's
	// extent are cut from it.
	float dish_r = clamp(rad / max(0.25, melt_radius), 0.0, 1.0);
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
	dish_r = clamp(rad / max(0.25, melt_radius), 0.0, 1.0);
	float lip = sin(dish_r * PI);
	vec3 dish = vec3(0.0);
	if (length(to_centre) > 0.0001) {
		dish = normalize(to_centre) * lip * dish_depth * molten;
	}
	// THE REFLECTION AS RELIEF. Owner: "like the melting gold is flowing and
	// rippling in the relief shape of the reflection."
	//
	// So the plate is not paint on the metal, it is EMBOSSED IN it. Three
	// luminance taps give the image's slope and the surface rises and falls
	// along it, which means a face in the reflected world arrives as a
	// face-shaped swell in the gold, moving as the pool moves.
	//
	// It is also why the image reads at all on a patch this small. As colour
	// it was competing with the ornament and losing; as topography it deforms
	// the ornament instead, and the eye reads deformation long before it reads
	// a tint.
	vec3 LUMA = vec3(0.299, 0.587, 0.114);
	float pl0 = dot(sample_reflected_world(q, living), LUMA);
	float plx = dot(sample_reflected_world(q + vec2(0.06, 0.0), living), LUMA);
	float ply = dot(sample_reflected_world(q + vec2(0.0, 0.06), living), LUMA);
	vec3 emboss = (tan_a * (plx - pl0) + tan_b * (ply - pl0)) * 16.0 * molten;
	// IMPASTO. The stroke ridges, the leaf seams and the cracks all stand off
	// the panel, so the surface has a texture the light rakes across even
	// where nothing is melting. This is the difference between a painted
	// surface and a printed one.
	vec2 bq = q * 0.9;
	float be = 0.05;
	vec2 b0 = brush(bq, brush_scale * 0.05);
	vec2 bx = brush(bq + vec2(be, 0.0), brush_scale * 0.05);
	vec2 by = brush(bq + vec2(0.0, be), brush_scale * 0.05);
	float s0 = leaf_seams(bq * 0.5, leaf_sheet_m * 12.0)
			+ cracks(bq * 0.7) * 1.6;
	float sx = leaf_seams((bq + vec2(be, 0.0)) * 0.5, leaf_sheet_m * 12.0)
			+ cracks((bq + vec2(be, 0.0)) * 0.7) * 1.6;
	float sy = leaf_seams((bq + vec2(0.0, be)) * 0.5, leaf_sheet_m * 12.0)
			+ cracks((bq + vec2(0.0, be)) * 0.7) * 1.6;
	vec3 paint_relief = (tan_a * ((bx.x - b0.x) + (sx - s0) * 0.5)
			+ tan_b * ((by.x - b0.x) + (sy - s0) * 0.5))
			* impasto * paint_gate * 6.0;

	// SINGLE-STEP PARALLAX PLUS NORMAL GRADIENT.  The apparent face shifts by
	// its meter-valued height at grazing angles, then four height samples tilt
	// the real shading normal. This remains one surface and cannot lie about a
	// traversable silhouette; it gives tesserae grout depth and the medallion
	// the raked edge the reference requires.
	vec3 world_view = normalize(INV_VIEW_MATRIX[3].xyz - v_world);
	float view_normal = max(0.18, abs(dot(world_view, n)));
	vec2 view_plane = vec2(dot(world_view, tan_a), dot(world_view, tan_b));
	float relief_preview = dream_architecture_height(base_q,
			relief_stage_one * relief_motif, relief_stage_two,
			tessera_relief_m, medallion_relief_m);
	vec2 relief_q = base_q - view_plane * relief_preview
			* relief_parallax / view_normal;
	float relief_step = 0.018;
	float architecture_h0 = dream_architecture_height(relief_q,
			relief_stage_one * relief_motif, relief_stage_two,
			tessera_relief_m, medallion_relief_m);
	float architecture_hx = dream_architecture_height(
			relief_q + vec2(relief_step, 0.0),
			relief_stage_one * relief_motif, relief_stage_two,
			tessera_relief_m, medallion_relief_m);
	float architecture_hy = dream_architecture_height(
			relief_q + vec2(0.0, relief_step),
			relief_stage_one * relief_motif, relief_stage_two,
			tessera_relief_m, medallion_relief_m);
	vec3 architecture_relief = -(tan_a * (architecture_hx - architecture_h0)
			+ tan_b * (architecture_hy - architecture_h0))
			/ relief_step;

	// The real surface's own relief, fading out as the gold takes over -- so a
	// wall stops being trowelled plaster and becomes beaten metal rather than
	// wearing both at once.
	vec3 surface_relief = (tan_a * surface_n.x + tan_b * surface_n.y)
			* (1.0 - metal_hint) * 0.42;
	vec3 bumped = normalize(n + surface_relief + architecture_relief
			+ relief + wave + dish + emboss + paint_relief
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
	// PHOTOGRAPHIC BLACK, NOT CRUSHED BLACK.  Only bounded real lights can
	// reveal this cold term, so raising it does not expose the far maze; it lets
	// the carried near-field source describe plaster, joinery and furniture
	// before the service beam wakes any gold.
	vec3 cold = albedo * 0.18;
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
	// The incandescence is now the ONLY thing lighting the world outside the
	// bowl, so it carries the whole frame rather than trimming an already-lit
	// one. 0.05/0.26 was set when the renderer's light was still doing the
	// work and left the corridor at the threshold of visible.
	float wake_glow = woken * (0.18 + 1.15 * heat);
	// COOLED GOLD. What the beam already converted, with no beam on it now.
	// Gated on (1 - woken) so it hands over to the waking rather than adding
	// to it -- lit gold is lit gold, and this is only ever the answer to
	// "what does the wall behind me look like now".
	float settled = eaten * (1.0 - woken) * settled_glow;
	METALLIC = mix(metal * gold_metallic * metal_hint, 0.95, molten);
	SPECULAR = mix(mix(0.25, 0.85, metal), 0.9, molten);
	// A mirror is smooth. The collapse toward zero roughness is most of why the
	// surface reads as liquid rather than as a shinier wall.
	// Real roughness where the wall is still a wall; the gold's own where it
	// has turned. Plaster that shines like leaf is the fastest way to lose the
	// building entirely.
	float base_r = mix(surface_rough, ground_roughness, 0.35);
	ROUGHNESS = mix(mix(base_r, gold_roughness, metal * metal_hint), 0.14,
			molten);
	ROUGHNESS = mix(ROUGHNESS, 0.08, jewel_face);
	SPECULAR = mix(SPECULAR, 1.0, jewel_face * 0.8);
	// Relief belongs to the solid converted wall, not only to the transient
	// molten bowl. Assign the complete normal at every stage; every non-base
	// term above is already explicitly gated by conversion or melt.
	NORMAL = bumped;
	// The reflection rides on EMISSION because Compatibility gives a shader no
	// other way to put an environment on a surface. It is gated by `molten`,
	// which is gated by heat, so it appears only where the lamp is -- the gold
	// still cannot glow on its own.
	// HOLD DETAIL AT THE CORE (owner ruling). The reflection used to run away
	// with the highlight and blow the middle of every molten pool to flat
	// white. Compressing it through its own reciprocal keeps the pool bright
	// while leaving the pattern legible right through the hottest part -- the
	// point being that molten gold has FIGURE in it, and a blown core has none.
	// THE BOWL, and nothing else, is reflective. Tight around the splash and
	// broken up, so it reads as a patch of disturbed liquid rather than as a
	// polished disc someone installed in the wall.
	float bowl = molten * pow(clamp(1.0 - dish_r, 0.0, 1.0), bowl_tightness);
	float patchy = mix(1.0, fbm(v_world.xz * 5.5 + vec2(ft * 0.4, -ft * 0.3)),
			bowl_breakup);
	bowl *= patchy;
	vec3 reflection = env * bowl * 1.35;

	// EVERYTHING ELSE GLOWS FROM WITHIN and fades to black. This is the gold
	// taking heat off the beam rather than catching its light: ember at the
	// cold edge of the cone, running up to pale gold where the metal is about
	// to give. It is emission, so it owes nothing to the renderer's lights,
	// and it falls off with the cone to pure darkness.
	vec3 incandescent = mix(ember_cold, ember_hot, smoothstep(0.0, 0.7, heat));
	incandescent = mix(incandescent, gold_pale, smoothstep(0.7, 1.0, heat));
	// The leaf carries the incandescence; the ground between it stays dark, so
	// the ornament is what glows and the bed it sits on is what fades.
	// Half ember, half the panel's OWN colour. A fixed ember ramp added over
	// everything was quietly averaging the world back to gold whatever the
	// glaze did underneath it -- the surface was varying and the light coming
	// off it was not.
	vec3 glow_colour = mix(incandescent, albedo * 2.2, 0.55);
	EMISSION = glow_colour * wake_glow * (0.35 + 0.65 * leaf)
			// THE PERSISTENCE, MADE VISIBLE. Weighted by `leaf` the same way
			// the waking is, so what stays behind is the ORNAMENT catching a
			// little light and not a uniform wash over the whole panel.
			+ albedo * settled * (0.35 + 0.65 * leaf)
			+ reflection
			+ star_colour * sky_glow * 0.55
			+ albedo * jewel_face * jewel_gleam * 0.16;
	// R6 CAMERA-LOCAL READABILITY. The view portal's shared-world camera is
	// the only camera which excludes presentation layer 20. That bit is a
	// render-pass identity, not a new material state: it lets the existing room
	// renderer expose photographed plaster and cooled ornament inside the tiny
	// secondary view without placing a helper light in the world the player can
	// later walk into. The main camera includes the layer and receives exactly
	// the pre-R6 output above.
	float portal_camera = (CAMERA_VISIBLE_LAYERS & uint(524288)) == uint(0)
			? 1.0 : 0.0;
	vec3 portal_read = albedo * (1.08 + leaf * 0.32)
			+ gold_mid * leaf * eaten * 0.24;
	ALBEDO = mix(ALBEDO, max(ALBEDO, portal_read), portal_camera);
	EMISSION += portal_read * portal_camera * 0.28;
	if (surface_debug_view == 1) {
		ALBEDO = vec3(architecture_mask);
		EMISSION = vec3(architecture_mask) * 1.20;
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
	} else if (surface_debug_view == 2) {
		float relief_debug = clamp(architecture_h0
				/ max(0.001, max(tessera_relief_m,
				medallion_relief_m)),
				0.0, 1.0);
		ALBEDO = vec3(relief_debug);
		EMISSION = vec3(relief_debug) * 1.50;
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
	} else if (surface_debug_view == 3) {
		ALBEDO = vec3(relief_stage_two, relief_stage_one, 0.0);
		EMISSION = ALBEDO * 1.20;
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
	}
}
