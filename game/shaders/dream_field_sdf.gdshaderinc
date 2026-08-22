// THE DREAM FIELD — the shared world-space signed field
// (DREAM_FIELD_DIRECTION §1, §16 `DreamFieldSDF`).
//
// The governing rule, from the top of the ruling:
//   THE DREAM FIELD IS NOT FOG SURROUNDING THE ANTAGONIST. IT IS THE
//   ANTAGONIST'S INFINITE BODY FAILING TO FIT INTO THREE DIMENSIONS.
//
// So this is not noise. It is a real anatomy — capsules, branching tubes,
// toroids, gyroid folds, flesh masses, vascular filaments and mineral
// inclusions, smooth-min'd together and domain-warped slowly — evaluated at
// a four-dimensional point. `dream_w` is the coordinate along the axis we
// cannot see, and the ONE technique that makes the whole thing read is that
// we ADVANCE dream_w rather than translating through XYZ:
//
//   r_visible = sqrt(max(0, r_total² - dream_w²))
//
// A lobe therefore materializes out of nothing, swells, splits, becomes a
// ring, collapses to islands and disappears — WITHOUT GOING ANYWHERE. That
// is what a 3-D creature cannot do, and it costs one square root.
//
// Every consumer — the fog volumes, the depth-aware lens, the incarnating
// surfaces, the residue, the withdrawal — samples THIS, so they read as one
// phenomenon rather than several effects. Host provides
// `dream_corruption_layers.gdshaderinc` first.

// Up to eight active lobes; the controller keeps the nearest few live
// (§17 spatial activation). xyz = world centre, w = total radius.
uniform vec4 df_lobe[8];
// x = kind (0 mass, 1 tube, 2 toroid, 3 fold), y = this lobe's own dream_w,
// z = intensity 0..1, w = seed.
uniform vec4 df_lobe_meta[8];
uniform int df_lobe_count = 0;
// The global slice coordinate and the shared clocks.
uniform float df_dream_w = 0.0;
uniform float df_time = 0.0;
uniform float df_pulse = 0.0;
uniform float df_seed = 0.0;
uniform float df_warp = 0.55;

// -- primitives --------------------------------------------------------

float df_smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float df_sphere(vec3 p, float r) {
	return length(p) - r;
}

float df_capsule(vec3 p, vec3 a, vec3 b, float r) {
	vec3 pa = p - a;
	vec3 ba = b - a;
	float h = clamp(dot(pa, ba) / max(1e-5, dot(ba, ba)), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float df_torus(vec3 p, float big, float small) {
	vec2 q = vec2(length(p.xz) - big, p.y);
	return length(q) - small;
}

// A gyroid: an infinite, connected, non-orientable-looking fold. Reads as
// anatomy we have no name for, which is the point.
float df_gyroid(vec3 p, float scale, float thick) {
	vec3 q = p * scale;
	return (abs(dot(sin(q), cos(q.zxy))) / scale) - thick;
}

// -- the four-dimensional slice ---------------------------------------

// The apparent 3-D radius of a higher-dimensional lobe at this slice. Zero
// (and beyond) means the lobe simply is not in our space right now.
float df_slice_radius(float r_total, float w_offset) {
	float d = df_dream_w - w_offset;
	return sqrt(max(0.0, r_total * r_total - d * d));
}

// -- the field ---------------------------------------------------------

// A slow domain warp, so nothing sits on an axis and the anatomy drifts.
vec3 df_warp_point(vec3 p, float seed) {
	vec3 w = vec3(
		dream_corruption_fbm3(p * 0.55 + seed),
		dream_corruption_fbm3(p * 0.55 + seed + 13.7),
		dream_corruption_fbm3(p * 0.55 + seed + 27.3)) - 0.5;
	return p + w * df_warp;
}

// One lobe's contribution. NEGATIVE inside the body, as an SDF should be.
float df_lobe_at(vec3 p, int i) {
	vec4 lobe = df_lobe[i];
	vec4 meta = df_lobe_meta[i];
	float r = df_slice_radius(lobe.w, meta.y);
	if (r <= 0.0001) {
		// Not intersecting our slice at all: the lobe is elsewhere in w.
		return 1e6;
	}
	int kind = int(meta.x + 0.5);
	float seed = meta.w;
	vec3 q = df_warp_point(p - lobe.xyz, seed);
	float d;
	if (kind == 1) {
		// A branching tube: two capsules that fork, the fork itself moving
		// with the slice so the branch appears and disappears in place.
		vec3 a = vec3(0.0, -r * 0.9, 0.0);
		vec3 mid = vec3(r * 0.15, 0.0, r * 0.1);
		float fork = df_slice_radius(lobe.w, meta.y + lobe.w * 0.45);
		vec3 b1 = mid + vec3(r * 0.6, r * 0.75, -r * 0.2);
		vec3 b2 = mid + vec3(-r * 0.5, r * 0.6, r * 0.55);
		d = df_capsule(q, a, mid, r * 0.30);
		d = df_smin(d, df_capsule(q, mid, b1, r * 0.20), r * 0.25);
		if (fork > 0.001) {
			d = df_smin(d, df_capsule(q, mid, b2, r * 0.16), r * 0.22);
		}
	} else if (kind == 2) {
		// A toroid: at the middle of its passage it is a ring; near the
		// edges of the slice it closes into a lump and then vanishes.
		float ring = r / max(0.05, lobe.w);
		d = df_torus(q, r * 0.62, r * (0.14 + 0.5 * (1.0 - ring)));
	} else if (kind == 3) {
		// A fold: a piece of gyroid clipped to the lobe's slice radius, so
		// a whole lattice of tissue can flicker into a room.
		d = max(df_gyroid(q, 5.5 / max(0.1, lobe.w), r * 0.10), df_sphere(q, r));
	} else {
		// An ellipsoidal flesh mass with vascular filaments through it.
		d = df_sphere(q * vec3(1.0, 1.15, 0.92), r);
		float fil = dream_corruption_vessels(q * (3.0 / max(0.1, lobe.w)) + seed, 0.85, 0.92);
		d -= smoothstep(0.55, 0.95, fil) * r * 0.12;
	}
	// The pulse travels outward through the whole body, so field anatomy
	// beats with the tentacle (§14).
	d -= sin(df_pulse * 6.2831853 - length(q) * (6.0 / max(0.1, lobe.w))) * r * 0.03;
	return d / max(0.05, meta.z);
}

// The field at a world point: the smooth union of every live lobe.
// Negative inside the organism, positive outside, ~metres either way.
float df_field(vec3 p) {
	float d = 1e6;
	for (int i = 0; i < df_lobe_count; i++) {
		d = df_smin(d, df_lobe_at(p, i), 0.28);
	}
	return d;
}

// How strongly this point is inside the organism: 0 outside, 1 well inside.
float df_influence(vec3 p, float skin) {
	return 1.0 - smoothstep(-skin, skin, df_field(p));
}

// The field's gradient — the direction "out of the body", for lighting,
// displacement and the direction anatomy grows.
vec3 df_normal(vec3 p) {
	vec2 e = vec2(0.02, 0.0);
	return normalize(vec3(
		df_field(p + e.xyy) - df_field(p - e.xyy),
		df_field(p + e.yxy) - df_field(p - e.yxy),
		df_field(p + e.yyx) - df_field(p - e.yyx)));
}
