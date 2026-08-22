shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE DREAM TENTACLE — the limb's body (DREAM_TENTACLE_DIRECTION §3, §4, §6,
// §7). The mesh is a unit tube (UV.x around, UV.y along). DreamTentacleRig
// hands over sixteen spine points in world space, a parallel-transported
// side vector each, and the silhouette profile per point (radius
// multiplier, flatten, twist, rib). The vertex stage bends the tube along
// the spine, shapes the cross-section (an ellipse that flattens and rotates
// along the length), and adds the anatomy's relief: the three veins, the
// ribbed section, the collar grooves, the eye socket and its lids, the
// sensory club, breathing and the peristaltic wave. The skin is the shared
// Dream material stack (`dream_entity_surface.gdshaderinc`).
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

group_uniforms rig;
uniform vec3 spine[16];
uniform vec3 side[16];
uniform vec4 prof[16];
uniform int spine_n = 16;
uniform float grow : hint_range(0.0, 1.0) = 0.0;
uniform float length_m = 1.6;
uniform float base_radius = 0.078;
uniform float tip_radius = 0.017;
uniform float seed = 0.0;
group_uniforms;
group_uniforms anatomy;
uniform float breathing : hint_range(0.0, 1.0) = 1.0;
uniform float peristalsis : hint_range(0.0, 1.0) = 1.0;
uniform float vein_relief : hint_range(0.0, 2.0) = 1.0;
// The eye's socket (u around, v along, radius) and how open the lids are.
uniform float eye_u = 0.0;
uniform float eye_v = 0.80;
uniform float eye_radius_m = 0.040;
uniform float eye_open : hint_range(0.0, 1.0) = 0.0;
// Contact: where along the body the suckers hold (v), and how much.
uniform float contact_v = 1.0;
uniform float contact_amount : hint_range(0.0, 1.0) = 0.0;
// The ventral roll (DIRECTION 9D): the anatomy turns about the body on the
// distal third so the suckers face the surface, without the body twisting.
uniform float ventral_roll = 0.0;
// Phase offset slices (§3, §9B): a narrow band of v rendered from the
// previous pose the rig keeps; a negative v disables.
uniform vec3 spine_prev[16];
uniform float phase_slice_v = -1.0;
uniform float phase_slice_w = 0.06;
// The mineral roots (DIRECTION_2 §B2): where a gold plate comes through,
// the flesh rises into a compressed lip, scars, and pulls its veins around.
uniform float root_v[10];
uniform float root_u[10];
uniform float root_w[10];
uniform int root_n = 0;
// Mask debug (DIRECTION_2 §I, the acceptance tests): 1 gold, 2 mineral,
// 3 thickness, 4 wet, 5 vascular, 6 iridophore, 7 vein, 8 gold_root.
uniform int mask_view = 0;
uniform float lod_near_m = 1.2;
uniform float lod_far_m = 4.0;
group_uniforms;

varying vec2 v_uv;
varying vec3 v_world;
varying float v_relief;
varying float v_contact;
varying float v_seg;
varying float v_thickness;
varying float v_stretch;
varying float v_gold_root;

vec3 dt_cr(vec3 a, vec3 b, vec3 c, vec3 d, float s) {
	return 0.5 * ((2.0 * b) + (-a + c) * s + (2.0 * a - 5.0 * b + 4.0 * c - d) * s * s
			+ (-a + 3.0 * b - 3.0 * c + d) * s * s * s);
}

vec3 dt_spine_of(float t, bool prev) {
	float n = float(spine_n - 1);
	float x = clamp(t, 0.0, 1.0) * n;
	int i = int(floor(min(x, n - 0.001)));
	float s = x - float(i);
	int i0 = max(i - 1, 0);
	int i2 = min(i + 1, spine_n - 1);
	int i3 = min(i + 2, spine_n - 1);
	if (prev) {
		return dt_cr(spine_prev[i0], spine_prev[i], spine_prev[i2], spine_prev[i3], s);
	}
	return dt_cr(spine[i0], spine[i], spine[i2], spine[i3], s);
}

vec3 dt_side(float t, vec3 tng) {
	float n = float(spine_n - 1);
	float x = clamp(t, 0.0, 1.0) * n;
	int i = int(floor(min(x, n - 0.001)));
	float s = x - float(i);
	vec3 sd = normalize(mix(side[i], side[min(i + 1, spine_n - 1)], s));
	sd = sd - tng * dot(sd, tng);
	return normalize(sd + vec3(1e-4, 0.0, 0.0));
}

vec4 dt_prof(float t) {
	float n = float(spine_n - 1);
	float x = clamp(t, 0.0, 1.0) * n;
	int i = int(floor(min(x, n - 0.001)));
	float s = x - float(i);
	return mix(prof[i], prof[min(i + 1, spine_n - 1)], s);
}

float dt_profile(float v) {
	float taper = mix(base_radius, tip_radius, pow(v, 0.8));
	float club = 1.0 + 0.45 * smoothstep(0.88, 0.985, v) * (1.0 - smoothstep(0.975, 1.0, v));
	return taper * sqrt(max(0.0, 1.0 - pow(v, 14.0))) * club;
}

// The anatomy's relief at (u, v): a radius multiplier, and the vein mask
// and eye-socket mask for the skin.
float dt_relief(vec2 uv, float time, out float vein, out float socket, out float lid, out float gold_root) {
	float u = uv.x;
	float v = uv.y;
	float ang = u * 6.2831853;
	vec4 pr = dt_prof(v);
	// Three veins, spiralling loosely, raised like cords; the pulse lifts
	// them as it passes.
	float vein_raw = pow(abs(sin(ang * 1.5 + v * 11.0 + sin(v * 5.0 + seed) * 0.6)), 14.0);
	float pulse = pow(0.5 + 0.5 * sin((v * 4.0 - pulse_phase * 6.2831853)), 4.0);
	vein = vein_raw * smoothstep(0.02, 0.1, v) * (1.0 - smoothstep(0.9, 0.98, v));
	// The ribbed section: annular ribs where the profile says so.
	float rib = pr.w * pow(0.5 + 0.5 * sin(v * 180.0), 2.0);
	// Collar grooves: concave transitions at each articulation (the gold
	// collars themselves are geometry, hovering over these).
	// The mineral sockets: the flesh rises into a lip around each plate and
	// is pressed down under its footprint (B2). This replaces the regular
	// collar grooves, which read as jewellery.
	float groove = 0.0;
	float root = 0.0;
	for (int k = 0; k < root_n; k++) {
		float du_r = abs(fract(u - root_u[k] + 0.5) - 0.5);
		float dv_r = abs(v - root_v[k]);
		// Tight: a plate's socket is a couple of centimetres of tissue, not
		// a quarter of the body. (The first pass normalised u by 0.25 of the
		// circumference, so eight plates turned the whole limb to metal.)
		float d = length(vec2(du_r / max(0.02, root_w[k] * 0.22), dv_r / 0.030));
		// A raised lip at the rim, a pressed hollow under the plate.
		float lip = smoothstep(1.35, 0.95, d) * smoothstep(0.5, 0.9, d);
		float press = 1.0 - smoothstep(0.0, 0.8, d);
		groove += press * 0.7;
		root = max(root, smoothstep(1.3, 0.45, d));
		vein *= 1.0 - press * 0.7;
		vein += lip * 0.35;
	}
	groove = clamp(groove, 0.0, 1.0);
	// An asymmetrical swelling on the dorsal side of the rounded segment.
	float swell = smoothstep(0.16, 0.26, v) * (1.0 - smoothstep(0.28, 0.40, v)) * max(0.0, cos(ang + 0.6));
	// THE ORBIT (DIRECTION_2 §C1, DIRECTION_3 §H). Not a dimple: a real
	// depression the globe sinks into, with a heavy overhanging brow on one
	// side, a cushioning fold below, lateral muscular folds and compression
	// wrinkles radiating out of it. The globe must never be inferable as a
	// whole sphere, so the rim has to CLOSE OVER it.
	float du = fract(u - eye_u + 0.5) - 0.5;
	float r_here = dt_profile(v) * pr.x;
	vec2 e = vec2(du * 6.2831853 * r_here, (v - eye_v) * length_m) / max(0.005, eye_radius_m);
	float er = length(e);
	float ang_e = atan(e.y, e.x);
	// The bowl: deep in the middle, rising to a rim that overhangs.
	float bowl = 1.0 - smoothstep(0.0, 1.35, er);
	// The brow: a heavy mass on one side, and a softer cushion opposite.
	float brow = smoothstep(0.35, 1.0, cos(ang_e - 0.55)) * (1.0 - smoothstep(0.85, 2.0, er));
	float cushion = smoothstep(0.45, 1.0, cos(ang_e + 2.4)) * (1.0 - smoothstep(0.95, 1.9, er));
	// Lateral folds and the compression wrinkles that radiate from a socket.
	float folds = pow(abs(sin(ang_e * 3.0 + 0.7)), 4.0) * smoothstep(1.0, 1.5, er)
			* (1.0 - smoothstep(1.6, 2.4, er));
	float wrinkles = pow(abs(sin(ang_e * 11.0)), 6.0)
			* smoothstep(1.15, 1.7, er) * (1.0 - smoothstep(1.9, 2.8, er));
	socket = bowl;
	float lid_cover = (1.0 - eye_open) * bowl;
	lid = lid_cover;
	float ring = smoothstep(0.95, 1.25, er) * (1.0 - smoothstep(1.45, 1.9, er));
	// The rim mass: what actually hides the globe from oblique angles.
	float rim_mass = brow * 0.75 + cushion * 0.45 + ring * 0.30 + folds * 0.22 + wrinkles * 0.10;
	// Breathing and the peristaltic wave, restrained.
	float breath = 1.0 + 0.03 * breathing * sin(time * 1.1 + seed);
	float wave = 1.0 + 0.05 * peristalsis * sin(v * 22.0 - time * 2.2 + seed);
	float mult = breath * wave
			* (1.0 + vein_relief * vein * (0.16 + 0.06 * pulse))
			* (1.0 + 0.08 * rib) * (1.0 - 0.13 * groove) * (1.0 + 0.16 * swell)
			* (1.0 - 0.62 * socket + 0.30 * lid + rim_mass * 0.34);
	gold_root = root;
	return mult;
}

void vertex() {
	float u = UV.x;
	float v = UV.y;
	// Emergence: the part not yet through collapses onto the point where it
	// leaves the surface, so it extrudes from the membrane.
	float t = min(v, grow);
	float alive = smoothstep(0.0, 0.04, grow - v);
	// Phase slice (§9B): a narrow band of the body belongs to the previous
	// pose for a moment.
	float slice = 0.0;
	if (phase_slice_v >= 0.0) {
		slice = 1.0 - smoothstep(phase_slice_w * 0.6, phase_slice_w, abs(v - phase_slice_v));
	}
	vec3 p = mix(dt_spine_of(t, false), dt_spine_of(t, true), slice);
	vec3 tng = normalize(dt_spine_of(min(t + 0.01, 1.0), false) - dt_spine_of(max(t - 0.01, 0.0), false) + vec3(0.0, 1e-5, 0.0));
	vec3 sd = dt_side(t, tng);
	vec3 bn = normalize(cross(tng, sd));
	vec4 pr = dt_prof(v);
	float vein;
	float socket;
	float lid;
	float gold_root;
	float mult = dt_relief(vec2(u, v), TIME, vein, socket, lid, gold_root);
	float r = dt_profile(v) * pr.x * mult * alive;
	// The cross-section: an ellipse that flattens and rotates along the
	// length (the ribbon span, the torsion), readable from afar.
	float ang = u * 6.2831853 + pr.z + ventral_roll * smoothstep(0.45, 0.8, v);
	vec3 radial = sd * cos(ang) * (1.0 + pr.y) + bn * sin(ang) * (1.0 - pr.y);
	vec3 nrm = normalize(sd * cos(ang) * (1.0 - pr.y) + bn * sin(ang) * (1.0 + pr.y));
	vec3 world = p + radial * r;
	VERTEX = world;
	NORMAL = nrm;
	TANGENT = tng;
	BINORMAL = cross(nrm, tng);
	v_uv = vec2(u, v);
	v_world = world;
	v_relief = vein;
	v_contact = contact_amount * (1.0 - smoothstep(0.0, 0.25, abs(v - contact_v)));
	v_seg = socket;
	// THICKNESS (DIRECTION_3 §B): the muscular root is thick; the distal
	// limb, the club's rim, the socket's lids and the skin stretched over a
	// vein or a mineral root are membranes. Light behaves differently on
	// each, and the flashlight is what reveals it.
	float along = 1.0 - smoothstep(0.15, 0.92, v);
	float girth = smoothstep(0.006, 0.055, dt_profile(v) * pr.x);
	v_thickness = clamp(along * 0.55 + girth * 0.6
			- socket * 0.55 - vein * 0.25 - lid * 0.3
			- smoothstep(0.93, 1.0, v) * 0.5, 0.0, 1.0);
	v_stretch = clamp(vein * 0.6 + socket * 0.5 + abs(pr.y) * 0.5 + gold_root * 0.6, 0.0, 1.0);
	v_gold_root = gold_root;
}

void fragment() {
	vec3 pw = v_world;
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float dist = length(VERTEX);
	float lod = 1.0 - smoothstep(lod_near_m, lod_far_m, dist);
	DeCtx ctx;
	ctx.thickness = v_thickness;
	ctx.vein = v_relief;
	ctx.contact = v_contact;
	ctx.gold_root = v_gold_root;
	ctx.socket = v_seg;
	ctx.stretch = v_stretch;
	ctx.lod = lod;
	DeMasks m = de_masks(pw, v_uv, n, view_dir, TIME, seed, ctx);
	// No gold on the lids; the socket's margins are always wet.
	m.gold *= 1.0 - v_seg * 0.9;
	m.wet = max(m.wet, v_seg * 0.85 * wetness);
	DeOut o = de_shade(m, pw, v_uv, n, view_dir, TIME, seed, ctx);
	ALBEDO = o.albedo;
	METALLIC = o.metallic;
	ROUGHNESS = o.roughness;
	SPECULAR = o.specular;
	EMISSION = o.emission;
	BACKLIGHT = o.backlight;
	AO = o.ao;
	AO_LIGHT_AFFECT = 0.35;
	// Real subsurface transport (DIRECTION_3 §A): thickness decides.
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	// The film, as its own lobe (§C).
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	// The mesh carries no tangents of its own; the vertex stage set TANGENT
	// and BINORMAL. The flesh's normal, then the film's on top of it — they
	// do not move together, which is what separates wet-on-flesh from flesh.
	vec3 nm = o.normal_map;
	vec3 film_n = de_film_normal(pw, TIME, seed, m.wet);
	vec2 slope = nm.xy + film_n.xy * m.wet * 0.35;
	NORMAL = normalize(NORMAL + TANGENT * slope.x * 0.8 + BINORMAL * slope.y * 0.8);
	if (mask_view > 0) {
		float g = 0.0;
		if (mask_view == 1) { g = m.gold; }
		else if (mask_view == 2) { g = m.mineral; }
		else if (mask_view == 3) { g = v_thickness; }
		else if (mask_view == 4) { g = m.wet; }
		else if (mask_view == 5) { g = m.vascular; }
		else if (mask_view == 6) { g = m.irid; }
		else if (mask_view == 7) { g = m.vein; }
		else { g = v_gold_root; }
		ALBEDO = vec3(g);
		EMISSION = vec3(g);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		SSS_STRENGTH = 0.0;
		CLEARCOAT = 0.0;
		BACKLIGHT = vec3(0.0);
		AO = 1.0;
	}
}
