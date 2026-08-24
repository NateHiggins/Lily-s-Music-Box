shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE DREAM MARGIN'S APPENDAGES (ecology architecture §5, §6, §7).
//
// One mesh, one draw, forty independently shaped organs. Each palp is a run
// of rings in the same buffer; UV2.x is its index, UV.y its place along it,
// and the vertex stage bends it onto that palp's spine AND gives it that
// palp's own cross-section progression.
//
// §7 is the reason this shader exists rather than reusing the tendril one.
// A tube with a different radius curve is still a tube; what reads as
// biological variety is the SECTION CHANGING ALONG THE LENGTH. Every palp
// carries four authored sections — root, shaft, sensory region, tip — and
// this interpolates between them, so a Flat Ribbon and a Gold Finger are
// different organs rather than differently-scaled noodles.
//
//   section = (flatten, lobes, lobe_depth, asymmetry)
//
// They wear the same shared material stack as the hero, because they are the
// same organism at a different resolution.
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

const int MAX_PALPS = 40;
const int JOINTS = 6;

uniform vec3 palp_spine[240];        // MAX_PALPS * JOINTS
uniform vec4 palp_section[160];      // MAX_PALPS * 4 stations
// x grow, y base_radius, z tip_ratio, w seed
uniform vec4 palp_params[40];
// x gold, y crystal, z suckers, w cilia
uniform vec4 palp_matter[40];
// §12 STEPS 2-4, THE PREMONITION. x how far along the swelling has got,
// y where along the organ it is happening, z spare, w spare.
//
// Steps 5 and 6 -- folded anatomy separates, secondary appendages unfold --
// were built first, and they arrived out of nowhere: an organ was simple and
// then it was branched. The canonical sequence puts three things before that,
// and all three are surface: the tissue congests with blood at the point, the
// gold structures slide aside to make room, and a crease forms. They are the
// tell. With them the wall shows you where it is about to open.
uniform vec4 palp_branch[40];
uniform int palp_count = 0;

varying vec2 v_uv;
varying vec3 v_world;
varying float v_thickness;
varying float v_seed;
varying vec4 v_matter;
varying vec2 v_branch;

vec3 spine_at(int p, float s) {
	float x = clamp(s, 0.0, 1.0) * float(JOINTS - 1);
	int i = int(floor(min(x, float(JOINTS - 1) - 0.001)));
	float f = x - float(i);
	int base = p * JOINTS;
	return mix(palp_spine[base + i], palp_spine[base + min(i + 1, JOINTS - 1)], f);
}

// The cross-section at v, interpolated across the four authored stations.
vec4 section_at(int p, float v) {
	float x = clamp(v, 0.0, 1.0) * 3.0;
	int i = int(floor(min(x, 2.999)));
	float f = x - float(i);
	int base = p * 4;
	return mix(palp_section[base + i], palp_section[base + i + 1], f);
}

void vertex() {
	int p = int(UV2.x + 0.5);
	float v = UV.y;
	float u = UV.x;
	vec4 par = palp_params[p];
	float grow = par.x;
	float s = min(v, grow);
	float alive = smoothstep(0.0, 0.06, grow - v * 0.9);

	vec3 pos = spine_at(p, s);
	vec3 tng = normalize(spine_at(p, min(s + 0.08, 1.0)) - spine_at(p, max(s - 0.08, 0.0))
			+ vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(tng.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 sd = normalize(cross(any, tng));
	vec3 bn = cross(tng, sd);

	vec4 sec = section_at(p, v);
	float a = u * 6.2831853 + par.w;
	// The section: an ellipse that flattens, carrying longitudinal lobes and
	// pushed off its own axis so nothing is symmetrical.
	float ca = cos(a);
	float sa = sin(a);
	float ex = ca * (1.0 + sec.x);
	float ez = sa * (1.0 - sec.x);
	float norm = max(0.0001, length(vec2(ex, ez)));
	ex /= norm;
	ez /= norm;
	float lobe = 1.0 + sec.z * cos(sec.y * a + par.w * 2.0);
	float asym = 1.0 + sec.w * cos(a + par.w);

	float taper = mix(par.y, par.y * par.z, pow(v, 1.15));
	float flare = 1.0 + 0.55 * exp(-v * 7.0);
	float breathe = 1.0 + 0.04 * sin(TIME * 1.9 + par.w * 3.0);
	float r = taper * flare * lobe * asym * breathe * alive;

	vec3 radial = sd * ex + bn * ez;
	VERTEX = pos + radial * r;
	NORMAL = normalize(radial);
	TANGENT = tng;
	BINORMAL = cross(radial, tng);
	v_uv = vec2(u, v);
	v_world = VERTEX;
	v_thickness = clamp(0.85 - 0.7 * v, 0.0, 1.0);
	v_seed = par.w;
	v_matter = palp_matter[p];
	// How strongly this vertex is inside the swelling, and how close it is to
	// the crease itself.
	vec4 br = palp_branch[p];
	float from_line = abs(v - br.y);
	float near_crease = 1.0 - smoothstep(0.0, 0.20, from_line);
	v_branch = vec2(br.x, near_crease);
	// STEP 2, in the geometry as well as the colour: congested tissue is
	// SWOLLEN. And STEP 4: the crease itself is a furrow, so the middle of
	// the swelling goes back in further than the shoulders come out.
	float furrow = 1.0 - smoothstep(0.0, 0.075, from_line);
	VERTEX += normalize(radial) * br.x
			* (near_crease * 0.024 - furrow * 0.040);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	DeCtx ctx;
	ctx.thickness = v_thickness;
	ctx.vein = 0.4;
	// §12 STEP 2 — LOCAL VASCULAR CONGESTION. Blood arrives before anatomy
	// does, so the tissue about to open runs dark and full.
	float swell = v_branch.x;
	float at_crease = v_branch.y;
	ctx.vein = clamp(ctx.vein + swell * at_crease * 0.85, 0.0, 1.0);
	ctx.thickness = clamp(ctx.thickness + swell * at_crease * 0.30, 0.0, 1.0);
	// §6: gold percentage is per-individual anatomy, not decoration.
	// §12 STEP 3 — GOLD STRUCTURES REPOSITION. The mineral cannot open, so it
	// gets out of the way: CLEARED from the line and crowded into the
	// shoulders either side, which is what makes the crease read as something
	// the body is doing rather than as a stripe painted on it.
	//
	// The first version added metal at the centre as well as the shoulders,
	// because the term meant to remove it was multiplied by the individual's
	// own gold fraction and lost to the term adding it. Photographed, that is
	// a gold RING -- an ornament, which is the one thing this must not be.
	float centre = smoothstep(0.45, 0.92, at_crease);
	float shoulder = at_crease * (1.0 - centre);
	ctx.gold_root = clamp(v_matter.x
			+ swell * (shoulder * 0.70 - centre * (v_matter.x + 0.35) * 1.6),
			0.0, 1.0);
	ctx.contact = v_matter.z * smoothstep(0.55, 1.0, v_uv.y);
	ctx.socket = v_matter.y * smoothstep(0.7, 1.0, v_uv.y);
	ctx.stretch = 0.3;
	ctx.lod = 1.0 - smoothstep(1.5, 6.0, length(VERTEX));
	DeMasks m = de_masks(v_world, v_uv, n, view_dir, TIME, v_seed, ctx);
	DeOut o = de_shade(m, v_world, v_uv, n, view_dir, TIME, v_seed, ctx);
	// §12 STEP 4 — THE CREASE. A line that is darker, wetter and deeply
	// occluded: the inside of a fold, seen edge on.
	//
	// WIDE ENOUGH TO SURVIVE THE DISTANCE IT IS SEEN FROM. The first version
	// was a hairline over five per cent of the organ's length, which on a
	// three-centimetre appendage across a room is less than a pixel -- the
	// swelling was doing everything and the crease itself contributed
	// nothing. It runs over about a seventh of the length now.
	float line = smoothstep(0.55, 0.95, at_crease) * swell;
	ALBEDO = mix(o.albedo, o.albedo * 0.14, line);
	METALLIC = o.metallic * (1.0 - line * 0.9);
	ROUGHNESS = clamp(o.roughness - line * 0.30, 0.03, 1.0);
	SPECULAR = o.specular;
	// 2.2 was tuned when these were 5 cm tendrils that had to be seen at all.
	// At primary scale it blows every archetype out to the same molten gold,
	// which is exactly the failure §37 names: they must differ WITHOUT
	// relying on colour, and they cannot differ at all if they are all
	// saturated. The gold fraction is per-individual anatomy (§6), so let it
	// decide how much light a given organ actually carries.
	EMISSION = o.emission * (0.55 + 1.25 * v_matter.x);
	BACKLIGHT = o.backlight;
	AO = o.ao * (1.0 - line * 0.85);
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.6 + BINORMAL * nm.y * 0.6);
}
