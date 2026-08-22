shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
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
uniform float lod_near_m = 1.2;
uniform float lod_far_m = 4.0;
group_uniforms;

varying vec2 v_uv;
varying vec3 v_world;
varying float v_relief;
varying float v_contact;
varying float v_seg;

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
float dt_relief(vec2 uv, float time, out float vein, out float socket, out float lid) {
	float u = uv.x;
	float v = uv.y;
	float ang = u * 6.2831853;
	vec4 pr = dt_prof(v);
	// Three veins, spiralling loosely, raised like cords; the pulse lifts
	// them as it passes.
	float vein_raw = pow(abs(sin(ang * 1.5 + v * 11.0 + sin(v * 5.0 + seed) * 0.6)), 14.0);
	float pulse = pow(0.5 + 0.5 * sin((v * 6.0 - time / max(0.2, pulse_period_s)) * 6.2831853), 6.0);
	vein = vein_raw * smoothstep(0.02, 0.1, v) * (1.0 - smoothstep(0.9, 0.98, v));
	// The ribbed section: annular ribs where the profile says so.
	float rib = pr.w * pow(0.5 + 0.5 * sin(v * 180.0), 2.0);
	// Collar grooves: concave transitions at each articulation (the gold
	// collars themselves are geometry, hovering over these).
	float seg = fract(v * 12.0);
	float groove = smoothstep(0.0, 0.05, seg) * (1.0 - smoothstep(0.07, 0.12, seg)) * smoothstep(0.05, 0.12, v);
	// An asymmetrical swelling on the dorsal side of the rounded segment.
	float swell = smoothstep(0.16, 0.26, v) * (1.0 - smoothstep(0.28, 0.40, v)) * max(0.0, cos(ang + 0.6));
	// The eye: a socket the eyeball sits in, and lids that rise over it
	// when it closes (the flesh covers the sphere).
	float du = fract(u - eye_u + 0.5) - 0.5;
	float r_here = dt_profile(v) * pr.x;
	vec2 e = vec2(du * 6.2831853 * r_here, (v - eye_v) * length_m) / max(0.005, eye_radius_m);
	float er = length(e);
	socket = 1.0 - smoothstep(0.9, 1.25, er);
	float lid_cover = (1.0 - eye_open) * (1.0 - smoothstep(0.0, 1.0, abs(e.y)));
	lid = socket * lid_cover;
	float ring = smoothstep(0.85, 1.05, er) * (1.0 - smoothstep(1.2, 1.5, er));
	// Breathing and the peristaltic wave, restrained.
	float breath = 1.0 + 0.03 * breathing * sin(time * 1.1 + seed);
	float wave = 1.0 + 0.05 * peristalsis * sin(v * 22.0 - time * 2.2 + seed);
	float mult = breath * wave
			* (1.0 + vein_relief * vein * (0.16 + 0.06 * pulse))
			* (1.0 + 0.08 * rib) * (1.0 - 0.11 * groove) * (1.0 + 0.16 * swell)
			* (1.0 - 0.35 * socket + 0.32 * lid + 0.08 * ring);
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
	float mult = dt_relief(vec2(u, v), TIME, vein, socket, lid);
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
}

void fragment() {
	vec3 pw = v_world;
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float dist = length(VERTEX);
	float lod = 1.0 - smoothstep(lod_near_m, lod_far_m, dist);
	DeMasks m = de_masks(pw, v_uv, n, view_dir, TIME, seed, v_relief, v_contact, lod);
	// The socket's rim is flesh, wet; no gold on the lids.
	m.gold *= 1.0 - v_seg * 0.9;
	m.wet = max(m.wet, v_seg * 0.8 * wetness);
	DeOut o = de_shade(m, pw, v_uv, n, view_dir, TIME, seed, lod);
	ALBEDO = o.albedo;
	METALLIC = o.metallic;
	ROUGHNESS = o.roughness;
	SPECULAR = o.specular;
	EMISSION = o.emission;
	BACKLIGHT = o.backlight;
	// The microstructure on the normal, explicitly (the mesh carries no
	// tangents of its own; the vertex stage set TANGENT and BINORMAL).
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.8 + BINORMAL * nm.y * 0.8);
}
