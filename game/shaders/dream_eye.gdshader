shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
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

uniform vec3 sclera_color : source_color = vec3(0.93, 0.87, 0.76);
uniform vec3 gold : source_color = vec3(0.859, 0.659, 0.298);
uniform vec3 gold_hot : source_color = vec3(1.0, 0.620, 0.180);
uniform vec3 iris_deep : source_color = vec3(0.28, 0.12, 0.05);
uniform vec3 interior_violet : source_color = vec3(0.30, 0.08, 0.36);
// Pupil radius (0..1 of the iris), and the interior's depth (0 closed).
uniform float pupil : hint_range(0.05, 0.9) = 0.32;
uniform float iris_radius : hint_range(0.2, 0.9) = 0.62;
uniform float interior : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform bool debug_gray = false;
uniform bool dbg_interior = true;

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
	// The iris instrument: radial rays of two frequencies, graduations at
	// two radii, facets, panes — gold over a deep ground.
	float rays = pow(0.5 + 0.5 * sin(ang * 36.0 + seed), 3.0);
	float rays2 = pow(0.5 + 0.5 * sin(ang * 12.0 - TIME * 0.05), 9.0);
	float grad = (1.0 - smoothstep(0.0, 0.02, abs(rr - 0.74))) * smoothstep(0.3, 0.9, 0.5 + 0.5 * sin(ang * 72.0));
	float grad2 = (1.0 - smoothstep(0.0, 0.015, abs(rr - 0.52)));
	float facets = dream_corruption_cells(vec3(p.xy * 9.0, seed), 0.0, 0.5);
	float panes = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(ang * 8.0) * sin(rr * 18.0));
	vec3 iris = mix(iris_deep, gold * 0.9, rays * 0.7 + rays2 * 0.5);
	iris = mix(iris, gold_hot, grad * 0.8 + grad2 * 0.5);
	iris = mix(iris, gold * 0.5, facets * 0.3);
	iris = mix(iris, iris * 1.2, panes * 0.4);
	// A limbal ring, dark, at the iris edge.
	float limbus = smoothstep(0.86, 1.0, rr) * in_iris;
	iris = mix(iris, iris_deep * 0.6, limbus);
	// The sclera: ivory-gold with fine vessels.
	float vessels = dream_corruption_vessels(vec3(p * 6.0 + seed), 0.8, 0.9);
	vec3 sclera = mix(sclera_color, sclera_color * vec3(0.9, 0.65, 0.6), smoothstep(0.6, 0.95, vessels) * 0.6);
	vec3 albedo = mix(sclera, iris, in_iris);
	vec3 emission = gold_hot * (grad * 0.8 + grad2 * 0.4 + rays2 * 0.25) * in_iris * (1.0 - in_pupil);
	// The pupil: deep; with the interior open, the view ray past it.
	vec3 pupil_col = vec3(0.0);
	if (interior > 0.001 && dbg_interior) {
		vec3 rd = normalize(v_view_local);
		vec3 ro = vec3(p.xy * 0.05, 0.0);
		pupil_col = eye_interior(ro, rd, TIME) * interior;
	}
	albedo = mix(albedo, vec3(0.0), in_pupil);
	emission = mix(emission, pupil_col, in_pupil);
	ALBEDO = albedo;
	METALLIC = in_iris * (1.0 - in_pupil) * 0.55;
	// A wet cornea over all of it.
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	EMISSION = emission;
	if (debug_gray) {
		ALBEDO = vec3(0.7);
		EMISSION = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 0.3;
	}
}
