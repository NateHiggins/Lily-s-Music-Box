shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE DREAM CRITTERS (ecology architecture §14–§17, §25).
//
// Eight animals, three body plans, one mesh, one draw. Each critter owns a
// slice of the buffer: a body, up to eight limbs and up to twelve feelers.
// UV2.x is the critter index and UV2.y says which PART a vertex belongs to
// (0 body, 1 limb, 2 feeler), so one vertex program builds three anatomies.
//
// The plans are deliberately not variations of one shape (§3): a flattened
// crawler, a radial sensor and a multi-limbed walker have different masses in
// different places, and that is decided here from the individual's own
// proportions rather than by scaling a common blob.
//
// They wear the same shared material stack as the hero and the margin,
// because they are the same biology at a third resolution.
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

const int MAX_CRITTERS = 12;

// xyz position, w plan (0 crawler, 1 radial, 2 walker)
uniform vec4 critter_pos[12];
// The critter's frame: forward and up, packed.
uniform vec4 critter_fwd[12];
uniform vec4 critter_up[12];
// x length, y wide, z tall, w seed
uniform vec4 critter_size[12];
// x gold, y crystal, z cilia, w gait phase
uniform vec4 critter_matter[12];
// x limbs, y feelers, z asymmetry, w alive
uniform vec4 critter_counts[12];
// §24, per individual: x the resonator's own angle, y which leg is currently
// shorter than the gap it spans, z how far.
uniform vec4 critter_law[12];
// §26 — this individual's material balance, inside the Dream colour language
// rather than a free hue: x aubergine..magenta, y crimson perfusion,
// z wetness, w structural iridescence.
uniform vec4 critter_look[12];
// MBIO-1: x receptor contrast, y photoshock, z scan phase, w beam side.
uniform vec4 critter_photo[12];
// MBIO-3: x response, y carrier/3, z seconds since reception, w direction.
uniform vec4 critter_mechanical[12];
// E3: CPU-planted fold-crab anatomy in the critter's local support frame.
// w on foot is stance. Eight rows per critter keep the draw bounded.
uniform vec4 crab_socket[96];
uniform vec4 crab_knee[96];
uniform vec4 crab_foot[96];
uniform int critter_count = 0;

varying vec2 v_uv;
varying vec3 v_world;
varying float v_seed;
varying float v_part;
varying vec4 v_matter;
varying float v_thickness;
varying vec4 v_law;
varying vec4 v_look;
varying vec4 v_photo;
varying vec4 v_mechanical;

// A tube's cross-section must be perpendicular to the tube. Offsetting along
// a fixed-plane normal -- which is what the ring normal is, before it is
// oriented -- gives every limb a cross-section in the SAME plane, and
// photographed the crab's legs came out as flat ribbons. This builds the
// frame from the segment's own direction.
vec3 ring_offset(vec3 tangent, vec3 ring_n, float thick) {
	vec3 t = normalize(tangent + vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(t.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 sd = normalize(cross(any, t));
	vec3 bn = cross(t, sd);
	float a = atan(ring_n.y, ring_n.x);
	return (sd * cos(a) + bn * sin(a)) * thick;
}

void vertex() {
	int c = int(UV2.x + 0.5);
	float part = UV2.y;
	vec4 pos = critter_pos[c];
	vec4 size = critter_size[c];
	vec4 counts = critter_counts[c];
	vec4 matter = critter_matter[c];
	vec4 law = critter_law[c];
	vec4 look = critter_look[c];
	vec4 photo = critter_photo[c];
	vec4 mechanical = critter_mechanical[c];
	vec3 fwd = normalize(critter_fwd[c].xyz + vec3(1e-5, 0.0, 0.0));
	vec3 up = normalize(critter_up[c].xyz + vec3(0.0, 1e-5, 0.0));
	vec3 side = normalize(cross(up, fwd));
	float seed = size.w;
	float alive = counts.w;

	// VERTEX arrives as a unit primitive; which one depends on the part.
	vec3 local = VERTEX;
	vec3 nrm = NORMAL;
	float index = UV.x;          // which limb / which feeler
	float along = UV.y;          // 0 root .. 1 tip, for limbs and feelers

	if (part < 0.5) {
		// ---- BODY -------------------------------------------------------
		// A flattened crawler is long and low; a radial sensor is a squat
		// dome; a walker is a compact box on legs. Same primitive, three
		// masses, taken from the individual's own proportions.
		vec3 s = vec3(size.y * 0.5, size.z * 0.5, size.x * 0.5);
		if (pos.w > 1.5) {
			// Fold crab: low cephalothorax with a flat load-bearing underside,
			// tapered rear and overlapping dorsal plate lobes. It must read as
			// an animal before gold or dimensional effects are visible.
			s = vec3(size.y * 0.58, size.z * 0.34, size.x * 0.54);
			local.y = max(local.y, -0.58);
			local.x *= mix(0.78, 1.12, smoothstep(-0.8, 0.35, local.z));
			local.y += 0.10 * cos(local.z * 6.0 + seed)
					+ 0.07 * sign(local.x) * sin(local.z * 4.0 + seed);
			local.z -= 0.10;
		} else if (pos.w > 0.5) {
			// Radial: a dome, widest at its base.
			s.z = s.x;
			local.y = local.y * 0.75 + 0.2;
		} else {
			// Crawler: a lens, thinnest at its rim.
			s.y *= mix(1.0, 0.35, clamp(length(local.xz), 0.0, 1.0));
		}
		// §17's asymmetrical defects: real animals are not mirrored.
		s.x *= 1.0 + counts.z * sin(local.z * 3.1 + seed);
		local *= s;
		v_thickness = 0.85;
	} else if (part < 1.5) {
		// ---- LIMB -------------------------------------------------------
		float n = max(1.0, counts.x);
		if (index >= n) {
			local = vec3(0.0);   // this individual has fewer limbs
			alive = 0.0;
		}
		int joint_i = c * 8 + int(index + 0.5);
		vec3 root = crab_socket[joint_i].xyz;
		vec3 knee = crab_knee[joint_i].xyz;
		vec3 foot = crab_foot[joint_i].xyz;
		float flank = sign(root.x);
		// The hyperdimensional fold changes the bend plane while both ends stay
		// anatomically connected; geometry never disappears or opens a gap.
		float folded = (abs(law.y - index) < 0.5) ? law.z : 0.0;
		vec3 coxa = root + vec3(flank * size.y * 0.18, size.z * 0.08, 0.0);
		knee += vec3(-flank * folded * size.y * 0.22,
				folded * size.z * 0.20, folded * size.x * 0.12);
		vec3 ankle = mix(knee, foot, 0.70) + vec3(0.0, size.z * 0.08, 0.0);
		vec3 a; vec3 b; float section;
		if (along < 0.18) {
			section = along / 0.18; a = root; b = coxa;
		} else if (along < 0.52) {
			section = (along - 0.18) / 0.34; a = coxa; b = knee;
		} else if (along < 0.84) {
			section = (along - 0.52) / 0.32; a = knee; b = ankle;
		} else {
			section = (along - 0.84) / 0.16; a = ankle; b = foot;
		}
		vec3 p = mix(a, b, section);
		vec3 seg = b - a;
		float collar = 1.0 + 1.7 * (1.0 - smoothstep(0.0, 0.16, along));
		float joint = 1.0 + 0.55 * (1.0 - smoothstep(0.0, 0.07,
				min(abs(along - 0.18), min(abs(along - 0.52), abs(along - 0.84)))));
		float pad = 1.0 + 1.2 * smoothstep(0.88, 1.0, along);
		float thick = size.y * 0.050 * (1.0 - 0.34 * along) * collar * joint * pad;
		local = p + ring_offset(seg, nrm, thick);
		v_thickness = 0.5;
	} else if (part < 2.5) {
		// ---- FEELER -----------------------------------------------------
		float n = max(1.0, counts.y);
		if (index >= n) {
			local = vec3(0.0);
			alive = 0.0;
		}
		float t = (index + 0.5) / n;
		float spread = (t - 0.5) * 2.4;
		// §22 — UNFOLDING AT THE HERO. law.w is how far this individual has
		// put its sensory structures out toward the thing that just touched
		// it. This is the critter's half of the conversation and the only
		// part of it a player can see, so it is a real change of anatomy --
		// the feelers lengthen by half again and rise off the surface -- and
		// not a colour flash or a wobble.
		float out_at = law.w;
		float len = size.x * (pos.w > 0.5 ? 1.15 : 0.55) * (0.5 + 0.5 * matter.z)
				* (1.0 + out_at * 0.55);
		// A listener's cilia stand up and outward; a crawler's comb lies
		// forward along the surface it is tasting. Unfolded, BOTH come up and
		// fan wider -- a comb that stays flat on the wall has not answered.
		vec3 dir = pos.w > 0.5
				? normalize(up * 1.4 + side * spread + fwd * 0.3)
				: normalize(fwd * 1.2 + side * spread * 0.8 - up * 0.15);
		dir = normalize(mix(dir, normalize(up * 1.5 + side * spread * 1.5
				+ fwd * 0.25), out_at));
		vec3 base = fwd * size.x * (pos.w > 0.5 ? 0.0 : 0.42) + side * spread * size.y * 0.3;
		// They wave, slowly, and each on its own phase.
		// And they go still while they are out. A structure held out to taste
		// something does not wave about.
		float carrier = floor(mechanical.y * 3.0 + 0.5);
		float hum = (1.0 - step(0.45, abs(carrier - 3.0))) * mechanical.x;
		float reverse = (1.0 - step(0.45, abs(carrier - 1.0))) * mechanical.x;
		float wave = sin(TIME * mix(1.6 + matter.z * 2.0, 0.7, hum)
				* mix(1.0, -1.0, reverse) + t * 9.0 + seed)
				* 0.16 * along * (1.0 - out_at * 0.75)
				* (1.0 - hum * 0.72);
		vec3 p = base + dir * (len * along) + side * wave * len;
		float thick = size.y * 0.014 * (1.0 - 0.7 * along);
		local = p + ring_offset(dir, nrm, thick);
		v_thickness = 0.12;
	} else {
		// ---- FOLD-CRAB ASSEMBLY -----------------------------------------
		if (pos.w < 1.5) {
			local = vec3(0.0); alive = 0.0;
		} else if (part < 5.5) {
			float plate = part - 3.0;
			float flank = plate < 0.5 ? -1.0 : (plate < 1.5 ? 1.0 : 0.0);
			float rear = plate > 1.5 ? -0.23 : 0.17;
			vec3 plate_scale = plate > 1.5
					? vec3(size.y * 0.42, size.z * 0.105, size.x * 0.28)
					: vec3(size.y * 0.31, size.z * 0.12, size.x * 0.34);
			local *= plate_scale;
			local += vec3(flank * size.y * 0.19, size.z * 0.22,
					rear * size.x);
			// Attention separates paired plates just enough to expose a deeper
			// parallax seam without losing their anatomical overlap.
			local.x += flank * law.w * size.y * 0.035;
			v_thickness = 0.34;
		} else if (part < 6.5) {
			// Ventral breathing body: protected, soft, and visibly distinct from
			// the dorsal armor.
			local *= vec3(size.y * 0.38, size.z * 0.16, size.x * 0.34);
			local += vec3(0.0, -size.z * 0.24, -size.x * 0.02);
			v_thickness = 0.92;
		} else {
			// Front sensory core nested between the plate pair.
			local *= vec3(size.y * 0.15, size.z * 0.16, size.x * 0.11);
			local += vec3(0.0, size.z * 0.10, size.x * 0.43);
			v_thickness = 0.18;
		}
	}

	// counts.w is 1 plus this individual's walking bob, so a moving animal
	// rises and falls on its legs and a still one does not (§20).
	float bob = counts.w - 1.0;
	vec3 world = pos.xyz + side * local.x + up * (local.y + bob) + fwd * local.z;
	world = mix(pos.xyz, world, clamp(counts.w, 0.0, 1.0) > 0.0 ? alive : 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = normalize(side * nrm.x + up * nrm.y + fwd * nrm.z);
	v_uv = vec2(index, along);
	v_world = world;
	v_seed = seed;
	v_part = part;
	v_matter = matter;
	v_law = law;
	v_look = look;
	v_photo = photo;
	v_mechanical = mechanical;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	DeCtx ctx;
	ctx.thickness = v_thickness;
	ctx.vein = 0.45;
	// §25 — the same three tissues, rebalanced per species. A fold crab is
	// mostly mineral at its joints; a listener is mostly crystal; a grazer is
	// nearly all flesh.
	ctx.gold_root = v_matter.x * (v_part > 0.5 && v_part < 1.5 ? 1.35
			: (v_part >= 3.0 && v_part < 5.5 ? 0.72 : 0.24));
	ctx.socket = v_matter.y * ((v_part > 1.5 && v_part < 2.5) || v_part >= 6.5 ? 1.2 : 0.5);
	ctx.contact = (v_part > 1.5 && v_part < 2.5) || v_part >= 6.5 ? 0.8 : 0.2;
	// §26 — the individual's own balance, applied to the shared stack.
	ctx.stretch = 0.2 + 0.5 * v_look.w;
	ctx.vein = 0.2 + 0.7 * v_look.y;
	float relay_front = v_mechanical.z * 0.72;
	float relay = (1.0 - smoothstep(0.03, 0.20,
			abs(v_uv.y - relay_front))) * v_mechanical.x;
	ctx.vein = clamp(ctx.vein + relay * 0.72, 0.0, 1.0);
	ctx.lod = 1.0 - smoothstep(1.2, 5.0, length(VERTEX));
	// §24 — THE RESONATOR TURNS INSIDE A SHELL THAT DOES NOT.
	//
	// The body's orientation never changes; the crystal's shading frame does.
	// So the outside of the animal is demonstrably still while the mineral
	// inside it rotates, which is not a thing a solid object can do.
	vec3 shading_pos = v_world;
	if (v_part < 0.5 && v_matter.y > 0.5) {
		// The resonator scans within a stationary shell. Directional contrast
		// makes that internal refraction asymmetric; photoshock tightens it.
		float a = v_law.x + v_photo.w * v_photo.x * 0.38
				+ sin(v_photo.z * 6.2831853) * v_photo.x * 0.16;
		float ca = cos(a);
		float sa = sin(a);
		shading_pos = vec3(v_world.x * ca - v_world.z * sa, v_world.y,
				v_world.x * sa + v_world.z * ca);
	}
	DeMasks m = de_masks(shading_pos, v_uv, n, view_dir, TIME, v_seed, ctx);
	DeOut o = de_shade(m, shading_pos, v_uv, n, view_dir, TIME, v_seed, ctx);
	// Aubergine toward magenta: a rebalance within the palette, never a hue
	// spun off it. At 0 the red channel is held back and the blue kept; at 1
	// the red is let through.
	vec3 tint = mix(vec3(0.82, 0.95, 1.12), vec3(1.18, 0.92, 0.95), v_look.x);
	ALBEDO = o.albedo * tint;
	METALLIC = o.metallic;
	ROUGHNESS = clamp(o.roughness - 0.22 * v_look.z, 0.04, 1.0);
	SPECULAR = o.specular;
	EMISSION = o.emission * (0.5 + 1.1 * v_matter.x);
	// Not a flash: photoshock bruises/perfuses the same tissue stack while
	// the legible event remains the resonator reversal and feeler arrest.
	ALBEDO *= mix(vec3(1.0), vec3(0.78, 0.72, 1.06), v_photo.y * 0.34);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.14, 0.72, 1.24), relay * 0.42);
	BACKLIGHT = o.backlight;
	AO = o.ao;
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.5 + BINORMAL * nm.y * 0.5);
}
