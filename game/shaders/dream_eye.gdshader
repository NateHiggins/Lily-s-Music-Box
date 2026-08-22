shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, blend_mix;
// THE ANGEL'S EYE (DREAM_TENTACLE_DIRECTION §2, §8, §10): a sphere seated in
// the limb's socket. Local +z is the gaze. The sclera is ivory-gold; the
// iris is a three-dimensional radial instrument — Byzantine halo rays,
// astronomical graduations, a sunburst reliquary, insect-optic facets,
// stained-glass radial panes — lying under a wet cornea; the pupil is
// deep, and when it dilates past a threshold the INTERIOR shows through it:
// a violet-gold space with distant rotating rings and luminous vascular
// architecture that cannot fit inside the limb (interior mapping on a view
// ray in the eye's own space — a reusable impossible-interior technique).
#include "res://shaders/dream_corruption_layers.gdshaderinc"

// Not a human sclera: wet ivory-gold organic tissue, dark enough to sit in
// a socket rather than glare out of one.
uniform vec3 sclera_color : source_color = vec3(0.55, 0.48, 0.38);
uniform vec3 gold : source_color = vec3(0.859, 0.659, 0.298);
uniform vec3 gold_hot : source_color = vec3(1.0, 0.620, 0.180);
uniform vec3 iris_deep : source_color = vec3(0.28, 0.12, 0.05);
uniform vec3 interior_violet : source_color = vec3(0.30, 0.08, 0.36);
// Pupil radius (0..1 of the iris), and the interior's depth (0 closed).
uniform float pupil : hint_range(0.05, 0.9) = 0.32;
uniform float iris_radius : hint_range(0.2, 0.9) = 0.72;
uniform float interior : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform bool debug_gray = false;
uniform bool dbg_interior = true;
// The cornea is the same shader on a separate convex cap: it draws only the
// tear film and the Fresnel, and lets the iris beneath show through.
uniform bool is_cornea = false;

varying vec3 v_local;
varying vec3 v_view_local;

void vertex() {
	v_local = VERTEX;
	// The view direction in the eye's local space, for the interior.
	vec3 cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	v_view_local = VERTEX - cam_local;
}

// The interior: rings at depths along the gaze axis, a vascular lattice,
// distant lights — evaluated on the local view ray past the pupil.
vec3 eye_interior(vec3 ro, vec3 rd, float time) {
	vec3 col = interior_violet * 0.25;
	// Rings: concentric, each at its own depth, rotating at its own rate.
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		float depth = 0.6 + fk * 0.9;
		float t = (depth - ro.z) / max(0.05, rd.z);
		if (t > 0.0) {
			vec2 hit = ro.xy + rd.xy * t;
			float ang = atan(hit.y, hit.x) + time * (0.12 + 0.07 * fk) * (mod(fk, 2.0) < 1.0 ? 1.0 : -1.0);
			float rr = length(hit);
			float ring = 1.0 - smoothstep(0.02, 0.05, abs(rr - (0.35 + fk * 0.28)));
			float beads = smoothstep(0.55, 0.95, 0.5 + 0.5 * sin(ang * (14.0 + fk * 6.0)));
			col += gold_hot * ring * (0.35 + 0.65 * beads) * (1.4 / (1.0 + fk * 0.6));
		}
	}
	// Vascular architecture: luminous lines on a far plane.
	float tf = (5.5 - ro.z) / max(0.05, rd.z);
	vec2 far = ro.xy + rd.xy * tf;
	float vessels = dream_corruption_vessels(vec3(far * 0.9, seed + time * 0.03), 0.9, 0.95);
	col += mix(interior_violet, gold, 0.5) * smoothstep(0.5, 0.9, vessels) * 0.7;
	// Distant lights.
	float stars = dream_corruption_noise3(vec3(far * 6.0, seed));
	col += gold_hot * smoothstep(0.88, 0.97, stars) * 1.2;
	return col;
}

void fragment() {
	vec3 p = normalize(v_local);
	// Polar coordinates about the gaze axis.
	float axial = clamp(p.z, -1.0, 1.0);
	float rr = length(p.xy) / max(0.05, iris_radius);
	float ang = atan(p.y, p.x);
	float in_iris = 1.0 - smoothstep(0.98, 1.03, rr);
	in_iris *= step(0.0, axial);
	float in_pupil = 1.0 - smoothstep(pupil - 0.03, pupil + 0.02, rr);
	// The iris is RECESSED: the view ray reaches it after crossing the
	// corneal space, so it parallaxes against the pupil's rim. This is what
	// stops the eye reading as a painted disc.
	vec3 vl = normalize(v_view_local);
	vec2 par = vl.xy * 0.085 / max(0.25, abs(vl.z));
	float rr_iris = length(p.xy + par) / max(0.05, iris_radius);
	float ang_iris = atan(p.y + par.y, p.x + par.x);
	// The iris instrument: radial rays of two frequencies, graduations at
	// two radii, facets, panes — gold over a deep ground.
	float rays = pow(0.5 + 0.5 * sin(ang_iris * 36.0 + seed), 3.0);
	float rays2 = pow(0.5 + 0.5 * sin(ang_iris * 12.0 - TIME * 0.05), 9.0);
	float grad = (1.0 - smoothstep(0.0, 0.02, abs(rr_iris - 0.74))) * smoothstep(0.3, 0.9, 0.5 + 0.5 * sin(ang_iris * 72.0));
	float grad2 = (1.0 - smoothstep(0.0, 0.015, abs(rr_iris - 0.52)));
	float facets = dream_corruption_cells(vec3((p.xy + par) * 9.0, seed), 0.0, 0.5);
	float panes = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(ang_iris * 8.0) * sin(rr_iris * 18.0));
	// Hero radial ridges: real relief in the iris, not just pattern.
	float ridges = pow(abs(sin(ang_iris * 18.0)), 12.0) * smoothstep(0.66, 0.30, rr_iris);
	vec3 iris = mix(iris_deep, gold * 0.9, rays * 0.7 + rays2 * 0.5);
	iris = mix(iris, gold_hot, grad * 0.8 + grad2 * 0.5);
	iris = mix(iris, gold * 0.5, facets * 0.3);
	iris = mix(iris, iris * 1.2, panes * 0.4);
	// A limbal ring, dark, at the iris edge.
	iris = mix(iris, gold_hot * 1.1, ridges * 0.5);
	float limbus = smoothstep(0.86, 1.0, rr_iris) * in_iris;
	iris = mix(iris, iris_deep * 0.6, limbus);
	// The sclera: ivory-gold with fine vessels.
	float vessels = dream_corruption_vessels(vec3(p * 6.0 + seed), 0.8, 0.9);
	vec3 sclera = mix(sclera_color, sclera_color * vec3(0.9, 0.65, 0.6), smoothstep(0.6, 0.95, vessels) * 0.6);
	vec3 albedo = mix(sclera, iris, in_iris);
	vec3 emission = gold_hot * (grad * 0.8 + grad2 * 0.4 + rays2 * 0.25) * in_iris * (1.0 - in_pupil);
	// The pupil: a real opening, deeper than the globe can hold. Its wall
	// is dark and its floor further than the sphere's own back.
	float pupil_wall = smoothstep(pupil * 0.55, pupil, rr) * in_pupil;
	// The pupil: deep; with the interior open, the view ray past it.
	vec3 pupil_col = vec3(0.0);
	if (interior > 0.001 && dbg_interior) {
		vec3 rd = normalize(v_view_local);
		vec3 ro = vec3(p.xy * 0.05, 0.0);
		pupil_col = eye_interior(ro, rd, TIME) * interior;
	}
	albedo = mix(albedo, vec3(0.0), in_pupil);
	albedo *= 1.0 - pupil_wall * 0.4;
	emission = mix(emission, pupil_col, in_pupil);
	ALBEDO = albedo;
	METALLIC = in_iris * (1.0 - in_pupil) * 0.55;
	// The globe itself is wet tissue; the SEPARATE corneal cap carries the
	// mirror-bright film.
	ROUGHNESS = mix(0.16, 0.05, in_iris);
	SPECULAR = 0.8;
	AO = 1.0 - in_pupil * 0.7;
	AO_LIGHT_AFFECT = 0.5;
	EMISSION = emission;
	if (debug_gray) {
		ALBEDO = vec3(0.7);
		EMISSION = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 0.3;
	}
	if (is_cornea) {
		// The tear film: a thin, almost colourless convex cap in FRONT of
		// the iris. It contributes reflection and a wet edge and nothing
		// else — the iris is physically behind it, which is what gives the
		// organ its depth. (GLSL forbids an early return in fragment().)
		float ndv_c = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float rim_c = pow(1.0 - ndv_c, 3.0);
		ALBEDO = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 0.02;
		SPECULAR = 1.0;
		EMISSION = vec3(0.0);
		AO = 1.0;
		ALPHA = clamp(0.05 + rim_c * 0.5, 0.0, 1.0);
	}
}
