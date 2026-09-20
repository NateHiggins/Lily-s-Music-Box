// THE DREAM CRITTERS (ecology architecture §14–§17, §25).
//
// Eight animals, sixteen body plans, one mesh, one draw. Each critter owns a
// slice of the buffer: a body, up to eight limbs and up to twelve feelers.
// UV2.x is the critter index and UV2.y says which PART a vertex belongs to
// (0 body, 1 limb, 2 feeler, 3+ organs), so one vertex program builds sixteen
// anatomies, including a cat-sized tardigrade and twelve researched microbes.
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
#include "res://shaders/dream_cellular_surface.gdshaderinc"
#include "res://shaders/dream_critter_voxel_optics.gdshaderinc"
#include "res://shaders/dream_microorganism_forms.gdshaderinc"
#include "res://shaders/dream_critter_blender_deform.gdshaderinc"

const int MAX_CRITTERS = 12;

// xyz position, w authored plan id (0..15, matching DreamCritterSpecies.Kind)
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
// x ribbing, y pores/sutures, z internal density, w optical anisotropy.
uniform vec4 critter_anatomy[12];
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
#include "res://shaders/dream_critter_blender_fold.gdshaderinc"
// One world-owned RG8 DreamExposureField shared by the whole fauna draw.
// R is durable exposure; G is current reversible irradiance.
uniform sampler3D exposure_tex : filter_linear, repeat_enable, hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;
uniform float voxel_optics_enabled = 0.0;

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
varying float v_axial;
varying float v_plan;
varying vec4 v_anatomy;
varying vec3 v_local;

vec2 critter_exposure_at(vec3 world_p) {
	// Same x,z,y order and bounded Y texel centres as dream_klimt and the
	// accepted DREAM-VOXEL-V1A compositor.
	return textureLod(exposure_tex, vec3(world_p.x / exposure_extent,
			world_p.z / exposure_extent,
			clamp(world_p.y / exposure_height, .0625, .9375)), 0.0).rg;
}

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
	int section = int(UV2.x + 0.5);
	int c = blender_provider_enabled ? int(round(blender_slot_map[section])) : section;
	bool slot_valid = c >= 0 && c < critter_count;
	c = clamp(c, 0, 11);
	bool authored = blender_provider_enabled && UV2.y > 999.0;
	float part = UV2.y;
	vec4 pos = critter_pos[c];
	vec4 size = critter_size[c];
	vec4 counts = critter_counts[c];
	vec4 matter = critter_matter[c];
	vec4 law = critter_law[c];
	vec4 look = critter_look[c];
	vec4 photo = critter_photo[c];
	vec4 mechanical = critter_mechanical[c];
	vec4 anatomy = critter_anatomy[c];
	vec3 fwd = normalize(critter_fwd[c].xyz + vec3(1e-5, 0.0, 0.0));
	vec3 up = normalize(critter_up[c].xyz + vec3(0.0, 1e-5, 0.0));
	vec3 side = normalize(cross(up, fwd));
	float seed = size.w;
	float alive = slot_valid ? counts.w : 0.0;

	// VERTEX arrives as a unit primitive; which one depends on the part.
	vec3 local = VERTEX;
	vec3 nrm = NORMAL;
	float index = UV.x;          // which limb / which feeler
	float along = UV.y;          // 0 root .. 1 tip, for limbs and feelers

	v_blender = authored ? 1.0 : 0.0;
	v_region = COLOR;
	float region_id = floor(COLOR.b * 255.0 + 0.5);
	v_region.b = (region_id < 1.5 || abs(region_id - 5.0) < 0.5) ? 1.0 : 0.0;
	v_region.a = abs(region_id - 6.0) < 0.5 ? 2.0 : (abs(region_id - 2.0) < 0.5 ? 1.0 : 0.0);
	if (authored) {
		int kind = int(round(pos.w));
		int leg = int(round(CUSTOM0.y));
		float amount = clamp(law.z, 0.0, 1.0);
		float movement_phase = kind > 3 ? law.x : matter.w;
		float phase_envelope = 1.0 - amount;
		// Every atlas parameter is bound to its declared source motion profile.
		if (kind == 0) { amount = clamp(law.w, 0.0, 1.0); phase_envelope = 1.0 - amount * 0.75; }
		if (kind == 1) { amount = fract(law.x / 6.2831853); phase_envelope = 1.0; }
		if (kind == 2) {
			int cpu_leg = leg >= 0 ? fold_cpu_leg(leg, int(round(counts.x))) : -1;
			amount = cpu_leg >= 0 && abs(law.y - float(cpu_leg)) < 0.5 ? amount : 0.0;
			phase_envelope = 1.0;
		}
		if (kind == 7) { amount = mod(floor(law.x), 4.0) / 4.0; phase_envelope = 0.0; }
		if (kind == 9) {
			int ray = -2 - leg;
			amount = ray == int(round(law.y * 11.0)) ? amount : 0.0;
		}
		if (kind == 10) { amount = fract(law.x * (leg == -2 ? 1.0 : 1.7) / 6.2831853); phase_envelope = 0.0; }
		if (kind == 11 || kind == 12 || kind == 14 || kind == 15) { phase_envelope = 1.0; }
		if (kind == 12) { amount = 0.0; } // law.z is a flash, never body collapse.
		if (kind == 13) { amount = fract(law.x / 6.2831853); phase_envelope = 0.0; }
		if (kind == 15) { amount = fract(law.x * 0.22 / 6.2831853); }
		vec2 phase = vec2(max(sin(movement_phase), 0.0), max(-sin(movement_phase), 0.0));
		phase *= 0.35 * phase_envelope;
		int vertex_id = int(CUSTOM0.x + 0.5);
		vec3 dimensions = max(vec3(size.y, size.z, size.x), vec3(0.001));
		local = blender_animated_pose(vertex_id, amount, phase, 0) * dimensions;
		nrm = normalize(blender_animated_pose(vertex_id, amount, phase, 1) / dimensions);
		if (kind == 10 && leg == -2 && blender_cilia_base[section] >= 0.0) {
			int root_id = int(round(blender_cilia_base[section]));
			float body_amount = fract(law.x * 1.7 / 6.2831853);
			vec3 root_delta = (blender_law_pose(root_id, body_amount, 0) - blender_law_pose(root_id, amount, 0)) * dimensions;
			local += root_delta * step(0.0001, CUSTOM0.z);
		}
		if (kind == 2 && leg >= 0 && leg < 8 && blender_joint_base[section] >= 0.0) {
			nrm = fold_leg_normal(nrm,section,c,leg,int(round(counts.x)),CUSTOM0.z,dimensions,law,counts.w-1.0);
			local = fold_leg_point(local,section,c,leg,int(round(counts.x)),CUSTOM0.z,dimensions,law,counts.w-1.0);
		} else if (kind == 3 && leg >= 0 && leg < 8 && blender_foot_base[section] >= 0.0) {
			vec3 posed_foot = blender_animated_pose(int(round(blender_foot_base[section])) + leg,
					amount, phase, 0) * dimensions;
			// Foot records are already in the support frame. Cancel body bob at
			// the tip so a stance foot remains exactly planted during a tun.
			vec3 target = crab_foot[c * 8 + leg].xyz;
			target.y -= counts.w - 1.0;
			local += (target - posed_foot) * clamp(CUSTOM0.z, 0.0, 1.0);
		} else if (leg <= -2 && leg >= -37 && !(kind == 2 && leg <= -20) && blender_cilia_base[section] >= 0.0) {
			int cilium = -2 - leg;
			if (float(cilium / (kind == 8 ? 3 : 1)) >= counts.y) {
				vec3 root = blender_animated_pose(int(round(blender_cilia_base[section])) + cilium,
						amount, phase, 0) * dimensions;
				// Root-ring vertices stay welded into the oral rim; all branch
				// vertices collapse to its declared root, leaving a closed patch.
				// This preserves the existing ten-to-twelve-bundle variation.
				local = mix(local, root, step(0.0001, CUSTOM0.z));
			}
		}
		if (kind == 2 && (leg == -20 || leg == -21) && blender_manipulator_base[section] >= 0.0) {
			int jaw = -20-leg;
			nrm = fold_jaw_normal(nrm,section,jaw,CUSTOM0.z,dimensions,photo.x,TIME);
			local = fold_jaw_point(local,section,jaw,CUSTOM0.z,dimensions,photo.x,TIME);
		}
		if (kind == 1 && leg >= 0 && leg < 5 && blender_prop_base[section] >= 0.0 && float(leg) >= counts.x) {
			vec3 root = blender_animated_pose(int(round(blender_prop_base[section])) + leg, amount, phase, 0) * dimensions;
			local = mix(local, root, step(0.0001, CUSTOM0.z));
		}
		// The existing contact response unfolds the listener/crab sensory tips.
		// Anchor-relative deformation preserves the shared zero-weight insertion.
		if ((kind == 1 || kind == 2) && leg <= -2 && leg >= -13 && blender_cilia_base[section] >= 0.0) {
			int branch = -2 - leg;
			if (float(branch) < counts.y) {
				vec3 root = blender_animated_pose(int(round(blender_cilia_base[section])) + branch, amount, phase, 0) * dimensions;
				float out_at = clamp(law.w, 0.0, 1.0) * clamp(CUSTOM0.z, 0.0, 1.0);
				vec3 offset = local - root;
				local = root + offset * (1.0 + out_at * 0.55) + vec3(0.0, length(offset) * out_at * 0.35, 0.0);
			}
		}
		if (pos.w > 4.5 && pos.w < 5.5 && leg <= -2) {
			// One curve transports cortex, feeding lumen and head together.
			nrm = blender_lacrymaria_normal(local, nrm, dimensions, law);
			local = blender_lacrymaria_search(local, dimensions, law);
		} else if (pos.w > 10.5 && pos.w < 11.5) {
			// Presentation extension: rigid parent-colony rotation, driven by
			// its existing micro_phase. No new controller or ecological clock.
			vec3 rotation_axis = normalize(vec3(0.23, 1.0, 0.35));
			local = blender_rodrigues(local, rotation_axis, law.x);
			nrm = blender_rodrigues(nrm, rotation_axis, law.x);
		}
		if (kind == 10) {
			local = blender_rodrigues(local, vec3(0.0,0.0,1.0), law.x);
			nrm = blender_rodrigues(nrm, vec3(0.0,0.0,1.0), law.x);
		}
		v_thickness = mix(0.8, 0.12, COLOR.g);
	} else if (part < 0.5) {
		// ---- BODY -------------------------------------------------------
		// A flattened crawler is long and low; a radial sensor is a squat
		// dome; a walker is a compact box on legs. Same primitive, three
		// masses, taken from the individual's own proportions.
		vec3 s = vec3(size.y * 0.5, size.z * 0.5, size.x * 0.5);
		if (pos.w > 3.5) {
			vec4 form = microorganism_body(pos.w, local, size.xyz, seed, law);
			local = form.xyz;
			v_thickness = form.w;
		} else if (pos.w > 2.5) {
			// Cat-sized tardigrade: four plump trunk annuli, an asymmetric head
			// cone and flexible intersegmental saddles.  A tun compacts the body
			// without replacing it or flattening its optical anatomy.
			float tun = smoothstep(.05, .92, law.z);
			s = vec3(size.y * .50, size.z * .50, size.x * .50);
			s.xy *= mix(1.0, 1.18, tun);
			s.z *= mix(1.0, .70, tun);
			float annulus = sin((local.z + 1.0) * 4.0 * 3.14159265
					+ sin(local.x * 2.7 + seed) * .32);
			float saddle = .74 + .26 * smoothstep(-.78, .34, annulus);
			local.xy *= saddle;
			float head = smoothstep(.28, .98, local.z);
			local.x *= mix(1.0, .82 + .08 * sin(seed), head);
			local.y += head * .055 + counts.z * sin(local.z * 5.1 + seed) * .05;
			local.z += .035 * sin(local.x * 4.0 + local.y * 3.0 + seed);
		} else if (pos.w > 1.5) {
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
			float radial_rib = sin(atan(local.x, local.z) * 12.0 + seed);
			local *= 1.0 + .035 * radial_rib * radial_rib;
		} else {
			// Crawler: a lens, thinnest at its rim.
			s.y *= mix(1.0, 0.35, clamp(length(local.xz), 0.0, 1.0));
			local.y += .055 * sin(local.x * 13.0 + sin(local.z * 7.0 + seed))
					* (1.0 - smoothstep(.52, 1.0, length(local.xz)));
		}
		// §17's asymmetrical defects: real animals are not mirrored.
		s.x *= 1.0 + counts.z * sin(local.z * 3.1 + seed);
		if (pos.w < 3.5) {
			local *= s;
			v_thickness = 0.85;
		}
	} else if (part < 1.5) {
		// ---- LIMB -------------------------------------------------------
		float n = max(1.0, counts.x);
		if (index >= counts.x) {
			local = vec3(0.0);   // this individual has fewer limbs
			alive = 0.0;
		}
		if (pos.w > 3.5) {
			vec4 form = microorganism_limb(pos.w, index, along, nrm,
					size.xyz, seed, law);
			if (form.w < 0.0) { local = vec3(0.0); alive = 0.0; }
			else { local = form.xyz; v_thickness = form.w; }
		} else if (pos.w < 1.5) {
			// The listener's few limbs are short compliant props around the dome,
			// not zero-length fold-crab joints hidden at its centre.
			float prop_angle = (index + .5) / n * 6.2831853 + seed;
			vec3 root = vec3(cos(prop_angle) * size.y * .28,
					-size.z * .18, sin(prop_angle) * size.x * .28);
			vec3 tip = vec3(cos(prop_angle) * size.y * .72,
					-size.z * .48, sin(prop_angle) * size.x * .72);
			vec3 p = mix(root, tip, along);
			p.y += sin(along * 3.14159265) * size.z * .13;
			local = p + ring_offset(tip - root, nrm,
					size.y * mix(.070, .045, along));
			v_thickness = .45;
		} else {
		int joint_i = c * 8 + int(index + 0.5);
		vec3 root = crab_socket[joint_i].xyz;
		vec3 knee = crab_knee[joint_i].xyz;
		vec3 foot = crab_foot[joint_i].xyz;
		float flank = sign(root.x);
		// The hyperdimensional fold changes the bend plane while both ends stay
		// anatomically connected; geometry never disappears or opens a gap.
		float folded = (pos.w < 2.5 && abs(law.y - index) < 0.5) ? law.z : 0.0;
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
		if (pos.w > 2.5 && pos.w < 3.5) {
			// Hydrostatic lobopod: blunt, compliant and continuous from body to
			// foot, with transverse muscular folds instead of crab articulation.
			float segment_fold = .86 + .14 * cos(along * 5.0 * 3.14159265);
			p = mix(p, mix(root, foot, smoothstep(0.0, 1.0, along)), .28);
			p.y += sin(along * 3.14159265) * size.z * .08;
			thick = size.y * mix(.145, .092, along) * segment_fold
					* mix(1.0, .76, smoothstep(.05, .92, law.z));
		}
		local = p + ring_offset(seg, nrm, thick);
		v_thickness = 0.5;
		}
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
		// Local body frame: x flank, y surface normal, z forward.  Feeding world
		// axes into `local` and transforming them a second time detached roots on
		// rotated animals and photographed as loose rods.
		vec3 dir = pos.w > 0.5
				? normalize(vec3(spread, 1.4, .30))
				: normalize(vec3(spread * .48, -.14, 1.20));
		dir = normalize(mix(dir, normalize(vec3(spread * 1.25, 1.5, .25)), out_at));
		vec3 base = pos.w > .5 ? vec3(0.0, size.z * .08, 0.0)
				: vec3(spread * size.y * .20, -size.z * .18, size.x * .40);
		if (pos.w > 3.5) {
			vec4 form = microorganism_feeler(pos.w, index, along, nrm,
					size.xyz, seed, law);
			if (form.w < 0.0) { local = vec3(0.0); alive = 0.0; }
			else { local = form.xyz; v_thickness = form.w; }
		} else if (pos.w > 2.5) {
			// Six circumoral lamellae (rare individuals add lateral papillae),
			// rooted around the terminal mouth cone rather than used as antennae.
			float mouth_angle = t * 6.2831853 + counts.z * .8;
			dir = normalize(vec3(cos(mouth_angle), sin(mouth_angle), .72));
			base = vec3(cos(mouth_angle), sin(mouth_angle), 0.0)
					* vec3(size.y * .12, size.z * .12, 0.0)
					+ vec3(0.0, size.z * .03, size.x * .47);
			len = size.y * (.20 + matter.z * .12) * (1.0 + out_at * .22);
		}
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
		if (pos.w < 3.5) {
			vec3 p = base + dir * (len * along) + vec3(1.0, 0.0, 0.0) * wave * len;
			float thick = size.y * (pos.w > 2.5 ? .027 : .014) * (1.0 - 0.7 * along);
			local = p + ring_offset(dir, nrm, thick);
			v_thickness = 0.12;
		}
	} else {
		if (pos.w > 3.5) {
			vec4 form = microorganism_detail(pos.w, part, index, along, local,
					nrm, size.xyz, seed, law);
			if (form.w < 0.0) { local = vec3(0.0); alive = 0.0; }
			else { local = form.xyz; v_thickness = form.w; }
		} else if (pos.w > 2.5) {
			// ---- TARDIGRADE EMBEDDED ANATOMY -------------------------------
			// These forms remain inside the intact cuticle. Their species shader
			// turns their refractive boundaries into phase-like silhouettes under
			// local voxel illumination; they are not loose props in a glass shell.
			if (part < 3.5) {
				// Muscular sucking pharynx behind the terminal mouth.
				local *= vec3(size.y * .24, size.z * .25, size.x * .17);
				local.x *= 1.0 + .11 * sin(local.y * 42.0 + seed);
				local += vec3(0.0, size.z * .035, size.x * .29);
				v_thickness = .82;
			} else if (part < 4.5) {
				// Storage-rich midgut, continuous along the trunk axis.
				local *= vec3(size.y * .27, size.z * .25, size.x * .48);
				local.xy *= .91 + .09 * cos(local.z * 47.0 + seed);
				local += vec3(0.0, -size.z * .02, -size.x * .05);
				v_thickness = .94;
			} else if (part < 5.5) {
				// Narrow hindgut joined to the posterior trunk.
				local *= vec3(size.y * .14, size.z * .13, size.x * .24);
				local += vec3(0.0, -size.z * .055, -size.x * .34);
				v_thickness = .74;
			} else if (part < 6.5) {
				// Bilobed brain wrapped around the buccal tube.
				local *= vec3(size.y * .28, size.z * .17, size.x * .12);
				local.x *= .82 + .18 * abs(local.y);
				local += vec3(0.0, size.z * .18, size.x * .33);
				v_thickness = .58;
			} else if (part < 8.5) {
				// Paired salivary/storage lobes, tethered alongside the pharynx.
				float flank = part < 7.5 ? -1.0 : 1.0;
				local *= vec3(size.y * .14, size.z * .13, size.x * .22);
				local.xy *= .88 + .12 * sin(local.z * 39.0 + flank * seed);
				local += vec3(flank * size.y * .20, size.z * .015, size.x * .16);
				v_thickness = .70;
			} else if (part < 9.5) {
				// A fused cloud of storage cells around the gut, not loose beads.
				local *= vec3(size.y * .33, size.z * .22, size.x * .29);
				local *= .90 + .10 * sin(local.x * 37.0 + local.z * 29.0 + seed);
				local += vec3(size.y * .04, size.z * .055, -size.x * .10);
				v_thickness = .88;
			} else if (part < 10.5) {
				// Paired stylets enter the receptor mouth and converge on the bulb.
				float flank = index < .5 ? -1.0 : 1.0;
				vec3 root = vec3(flank * size.y * .10, size.z * .025, size.x * .48);
				vec3 tip = vec3(flank * size.y * .035, size.z * .035, size.x * .23);
				vec3 p = mix(root, tip, along);
				p.x += flank * sin(along * 3.14159265) * size.y * .035;
				local = p + ring_offset(tip - root, nrm,
						size.y * mix(.021, .010, along));
				v_thickness = .30;
			} else if (part < 12.5) {
				// Lateral sensory fields sit under, not on top of, the head cuticle.
				float flank = part < 11.5 ? -1.0 : 1.0;
				local *= vec3(size.y * .060, size.z * .055, size.x * .055);
				local += vec3(flank * size.y * .39, size.z * .15, size.x * .32);
				v_thickness = .26;
			} else if (part < 13.5) {
				// Eight longitudinal/oblique muscle fields anchor to the cortex and
				// bow around the connected gut rather than intersecting it.
				float flank = index < 4.0 ? -1.0 : 1.0;
				float row = mod(index, 4.0) / 3.0;
				vec3 root = vec3(flank * size.y * .39,
						mix(-.20, .21, row) * size.z, size.x * .38);
				vec3 tip = vec3(flank * size.y * .34,
						mix(.19, -.18, row) * size.z, -size.x * .42);
				vec3 p = mix(root, tip, along);
				p.x += flank * sin(along * 3.14159265) * size.y * .09;
				local = p + ring_offset(tip - root, nrm, size.y * .010);
				v_thickness = .20;
			} else {
				// Two hooked, high-index claw branches per lobopod.
				float leg_index = floor(index * .5);
				float branch = mod(index, 2.0) < .5 ? -1.0 : 1.0;
				if (leg_index >= counts.x) { local = vec3(0.0); alive = 0.0; }
				int joint_i = c * 8 + int(leg_index + .5);
				vec3 foot = crab_foot[joint_i].xyz;
				float flank = sign(foot.x);
				vec3 root = foot + vec3(branch * size.y * .018, size.z * .018, 0.0);
				vec3 tangent = normalize(vec3(flank * .44 + branch * .22, -.12,
						branch * .36));
				vec3 p = root + tangent * along * size.y * .20;
				p.y += sin(along * 3.14159265) * size.z * .06
						- smoothstep(.64, 1.0, along) * size.z * .09;
				local = p + ring_offset(tangent, nrm,
						size.y * mix(.018, .006, along));
				v_thickness = .16;
			}
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
		} else if (part < 7.5) {
			// Front sensory core nested between the plate pair.
			local *= vec3(size.y * 0.15, size.z * 0.16, size.x * 0.11);
			local += vec3(0.0, size.z * 0.10, size.x * 0.43);
			v_thickness = 0.18;
		} else if (part < 8.5) {
			// Rear information-transfer rosette meets the moss on return.
			local *= vec3(size.y * 0.24, size.z * 0.13, size.x * 0.13);
			local += vec3(0.0, -size.z * 0.08, -size.x * 0.49);
			local.x *= 1.0 + 0.16 * sin(v_uv.x * 31.0 + TIME * 1.4);
			v_thickness = 0.78;
		} else if (part < 9.5) {
			// A continuous muscular girdle bridges the embedded leg sockets.
			local *= vec3(size.y * 0.58, size.z * 0.10, size.x * 0.38);
			local += vec3(0.0, -size.z * 0.13, -size.x * 0.02);
			v_thickness = 0.55;
		} else if (part < 10.5) {
			// Two short mouth-adjacent manipulators fold beneath the crown while
			// travelling and deploy only during an existing examination state.
			float flank = index < 0.5 ? -1.0 : 1.0;
			float deploy = photo.x;
			vec3 root = vec3(flank * size.y * 0.13, -size.z * 0.10, size.x * 0.39);
			vec3 elbow = root + vec3(flank * size.y * 0.10,
					-size.z * (0.07 + 0.08 * deploy), size.x * 0.12 * deploy);
			vec3 tip = elbow + vec3(-flank * size.y * 0.04,
					-size.z * 0.03, size.x * (0.05 + 0.30 * deploy));
			vec3 a = along < 0.52 ? root : elbow;
			vec3 b = along < 0.52 ? elbow : tip;
			float section = along < 0.52 ? along / 0.52 : (along - 0.52) / 0.48;
			vec3 p = mix(a, b, section);
			p.x += sin(TIME * 3.1 + flank * 1.7) * deploy * size.y * 0.018 * along;
			float thick = size.y * mix(0.045, 0.018, along);
			local = p + ring_offset(b - a, nrm, thick);
			v_thickness = 0.64;
		} else if (part < 12.5) {
			// Paired tactile bulbs make the manipulators legible without adding
			// per-organ draw calls. They retract under the sensory crown.
			float flank = part < 11.5 ? -1.0 : 1.0;
			float deploy = photo.x;
			local *= vec3(size.y * 0.075, size.z * 0.065, size.y * 0.085);
			local += vec3(flank * size.y * (0.19 + 0.06 * deploy),
					-size.z * (0.18 - 0.04 * deploy),
					size.x * (0.44 + 0.52 * deploy));
			v_thickness = 0.86;
		} else {
			float n = max(1.0, counts.x);
			if (index >= n) { local = vec3(0.0); alive = 0.0; }
			int joint_i = c * 8 + int(index + 0.5);
			vec3 socket = crab_socket[joint_i].xyz;
			float flank = sign(socket.x);
			vec3 inner = vec3(socket.x * .34, -size.z * .15, socket.z * .78);
			vec3 outer = socket + vec3(flank * size.y * .19, size.z * .03, 0.0);
			vec3 p = mix(inner, outer, along);
			float web = sin(along * 3.14159265);
			p.y -= web * size.z * .09;
			local = p + ring_offset(outer - inner, nrm,
					size.y * (.024 + web * .135));
			v_thickness = .96;
		}
		}
	}

	// counts.w is 1 plus this individual's walking bob, so a moving animal
	// rises and falls on its legs and a still one does not (§20).
	float bob = counts.w - 1.0;
	vec3 world = pos.xyz + side * local.x + up * (local.y + bob) + fwd * local.z;
	world = mix(pos.xyz, world, authored ? (alive > 0.0 ? 1.0 : 0.0) : (clamp(counts.w, 0.0, 1.0) > 0.0 ? alive : 0.0));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	vec3 world_normal = normalize(side * nrm.x + up * nrm.y + fwd * nrm.z);
	NORMAL = authored ? normalize(transpose(mat3(MODEL_MATRIX)) * world_normal) : world_normal;
	v_uv = authored ? UV : vec2(index, along);
	v_world = world;
	v_seed = seed;
	v_part = part;
	v_matter = matter;
	v_law = law;
	v_look = look;
	v_photo = photo;
	v_mechanical = mechanical;
	vec3 eye_offset = INV_VIEW_MATRIX[3].xyz - pos.xyz;
	v_axial = authored ? dot(local, vec3(dot(eye_offset,side), dot(eye_offset,up), dot(eye_offset,fwd)))
			: local.z / max(size.x, .001);
	v_plan = pos.w;
	v_anatomy = anatomy;
	v_local = local / max(vec3(size.y, size.z, size.x), vec3(.001));
}

void fragment() {
#ifdef DREAM_CRITTER_MEMBRANE
	// Only authored thin-window triangles enter this shared transparent pass.
	// Their actual enclosed organs and all solid tissue already own opaque depth.
	ALPHA = 1.0;
#endif
	vec3 n = normalize(NORMAL);
	if (v_blender > 0.5) {
		if (!FRONT_FACING) { n = -n; NORMAL = n; }
#ifdef DREAM_CRITTER_MEMBRANE
		// Intact tissue shows its front surface. A diagnostic cutaway keeps
		// the far half of the same cortex, including its membrane triangles.
		if (blender_review_mode == 0 && !FRONT_FACING && v_region.b > 0.5) { discard; }
#endif
		// Anatomy masks come from the model. Noise varies substance only; it
		// cannot invent gold stripes, organs or stimulus routes.
		float authored_wire = pow(clamp(v_region.r, 0.0, 1.0), 1.6);
		if (v_plan > 0.5 && v_plan < 1.5 && v_region.b > 0.5) {
			// The receiver's existing mineral ridge is a narrow seam. Preserve
			// its anatomical location without filling its interpolation skirt.
			authored_wire = pow(clamp(v_region.r / 0.55, 0.0, 1.0), 6.0) * 0.8;
		}
		float wire = clamp(authored_wire * (0.6 + 0.8 * v_matter.x), 0.0, 1.0);
		float window = clamp(v_region.g, 0.0, 1.0);
		if (blender_review_mode == 2 && v_region.b > 0.5 && v_axial > 0.0) {
			discard;
		}
		vec2 rg = voxel_optics_enabled > 0.5 ? critter_exposure_at(v_world) : vec2(0.0);
		float beam = smoothstep(0.035, 0.72, rg.g);
		float sustained = smoothstep(0.2, 0.9, rg.r) * beam;
		float pore_scale = (54.0 + mod(v_plan * 17.0, 53.0)) * (0.8 + 0.4 * v_anatomy.y);
		float grain = critter_fbm(v_local * pore_scale + v_seed);
		float tissue_cloud = critter_fbm(v_local * (6.0 + mod(v_plan * 3.0, 8.0)) + v_seed * 1.73);
		float cuticle = 1.0 - step(3.5, v_plan);
		float perfusion = clamp(0.28 + 0.45 * v_look.y + 0.12 * grain, 0.0, 1.0);
		vec3 black_wine = vec3(0.027, 0.006, 0.032);
		vec3 wine_low = vec3(0.12, 0.012, 0.042);
		vec3 wine_high = vec3(0.32, 0.032, 0.070);
		// Species-specific absorption remains within the shared wine enamel
		// palette. It does not recolor tissue from photographs or stain labels.
		if (v_plan > 3.5 && v_plan < 4.5) {
			wine_low = vec3(0.066, 0.011, 0.068);
			wine_high = vec3(0.20, 0.023, 0.115);
		} else if (v_plan > 4.5 && v_plan < 5.5) {
			wine_low = vec3(0.115, 0.010, 0.031);
			wine_high = vec3(0.35, 0.036, 0.043);
		} else if (v_plan > 5.5 && v_plan < 6.5) {
			wine_low = vec3(0.085, 0.008, 0.065);
			wine_high = vec3(0.25, 0.026, 0.106);
		} else if (v_plan > 10.5 && v_plan < 11.5) {
			wine_low = vec3(0.075, 0.008, 0.035);
			wine_high = vec3(0.255, 0.028, 0.052);
		}
		// Distinct absorption/roughness balances, never decorative banding.
		if (v_plan < 0.5) { wine_low=vec3(.066,.009,.051); wine_high=vec3(.22,.032,.091); }
		else if (v_plan < 1.5) { wine_low=vec3(.048,.010,.065); wine_high=vec3(.16,.036,.13); }
		else if (v_plan < 2.5) { wine_low=vec3(.095,.015,.021); wine_high=vec3(.29,.053,.052); }
		else if (v_plan > 6.5 && v_plan < 7.5) { wine_low=vec3(.062,.013,.052); wine_high=vec3(.21,.040,.09); }
		else if (v_plan > 7.5 && v_plan < 8.5) { wine_low=vec3(.11,.010,.058); wine_high=vec3(.31,.024,.115); }
		else if (v_plan > 8.5 && v_plan < 9.5) { wine_low=vec3(.071,.014,.040); wine_high=vec3(.20,.051,.075); }
		else if (v_plan > 9.5 && v_plan < 10.5) { wine_low=vec3(.049,.014,.061); wine_high=vec3(.18,.043,.12); }
		else if (v_plan > 11.5 && v_plan < 12.5) { wine_low=vec3(.085,.012,.072); wine_high=vec3(.29,.040,.14); }
		else if (v_plan > 12.5 && v_plan < 13.5) { wine_low=vec3(.069,.017,.028); wine_high=vec3(.25,.068,.064); }
		else if (v_plan > 13.5 && v_plan < 14.5) { wine_low=vec3(.074,.011,.058); wine_high=vec3(.21,.028,.11); }
		else if (v_plan > 14.5) { wine_low=vec3(.115,.009,.041); wine_high=vec3(.34,.030,.081); }
		vec3 wine = mix(wine_low, wine_high, perfusion);
		wine *= vec3(0.94 + 0.12*v_look.x, 1.0, 1.06 - 0.12*v_look.x);
		// Dense tissue and vacuoles differ in absorption within the same wine
		// family. Region numbers are anatomical ids, never categorical hues.
		float interior = clamp(v_region.a, 0.0, 1.0);
		wine *= mix(1.0, 0.65 + 0.25 * tissue_cloud, interior);
		wine *= mix(0.82, 1.10, tissue_cloud);
		wine *= 1.0 - clamp(v_photo.y,0.0,1.0) * 0.18;
		float dark_mass = smoothstep(0.20, 0.79, tissue_cloud);
		ALBEDO = mix(black_wine, wine, 0.30 + dark_mass * 0.40 + 0.20 * beam);
		ALBEDO = mix(ALBEDO, gold, clamp(wire * (1.0 + sustained * 0.40), 0.0, 1.0));
		METALLIC = 0.72 * wire + 0.06 * sustained;
		ROUGHNESS = mix(0.31, 0.56, cuticle) + mod(v_plan * 0.037, 0.11) - window * 0.09
				+ (tissue_cloud - 0.5) * 0.14 + (grain - 0.5) * 0.08 + (0.5-v_look.z)*0.12;
		if (blender_review_mode != 1) {
			// Original procedural substance relief. Differential bump is in view
			// space and does not move silhouettes or invent anatomical stripes.
			float height = (grain - 0.5) * mix(0.000055, 0.00019, cuticle);
			height *= (1.0 - wire * 0.85) * (1.0 - window * 0.55);
			vec3 dpdx = dFdx(VERTEX);
			vec3 dpdy = dFdy(VERTEX);
			vec3 r1 = cross(dpdy, n);
			vec3 r2 = cross(n, dpdx);
			float determinant = dot(dpdx, r1);
			vec3 gradient = sign(determinant) * (dFdx(height)*r1 + dFdy(height)*r2)
					/ max(abs(determinant), 0.00000001);
			NORMAL = normalize(n - gradient);
		}
		SPECULAR = 0.42;
		CLEARCOAT = mix(0.16, 0.06, cuticle) + 0.06 * beam + 0.08*v_look.z;
		CLEARCOAT_ROUGHNESS = 0.22;
		SSS_STRENGTH = 0.18 + window * 0.3;
		SSS_TRANSMITTANCE_COLOR = vec4(wine, 1.0);
		SSS_TRANSMITTANCE_DEPTH = 0.18;
		BACKLIGHT = wine * window * beam * 0.6;
		EMISSION = gold * wire * (0.13 + 0.12 * rg.r + beam * 0.22)
				+ wine * interior * window * beam * 0.08;
		// Existing receptor state modulates authored tissue, with no new signal route.
		EMISSION += gold * wire * clamp(v_mechanical.x,0.0,1.0) * 0.10;
		float silhouette = pow(1.0-clamp(dot(n,normalize(VIEW)),0.0,1.0),4.0);
		EMISSION += (wine*0.22+gold*wire*0.04)*silhouette*(1.0-beam);
		float scintillon = step(1.5,v_region.a);
		EMISSION += vec3(0.180,0.404,0.360) * scintillon * clamp(v_law.z,0.0,1.0) * 2.4;
		if (blender_review_mode == 1) {
			ALBEDO = vec3(0.43);
			METALLIC = 0.0;
			ROUGHNESS = 0.66;
			CLEARCOAT = 0.0;
			EMISSION = vec3(0.0);
			SSS_STRENGTH = 0.0;
			BACKLIGHT = vec3(0.0);
		} else if (blender_review_mode == 0 && window > 0.01) {
#ifdef DREAM_CRITTER_MEMBRANE
			// A bounded front membrane transmits the real depth-tested interior.
			// Gold remains opaque; this is tissue transmission, not glass refraction.
			if (!FRONT_FACING && v_region.b > 0.5) { discard; }
			ALPHA = 1.0 - window * (0.54 + 0.30 * beam) * (1.0 - wire);
#endif
		}
	} else {
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
	// Information is acquired at the crown and visibly travels toward the rear
	// transfer rosette; fatigue desaturates soft tissue without hiding anatomy.
	float info_path = (1.0 - smoothstep(0.06, 0.22,
			abs(fract(v_uv.y + TIME * 0.34) - v_photo.y))) * v_photo.y;
	ctx.vein = clamp(ctx.vein + info_path * 0.8, 0.0, 1.0);
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
	vec4 cell_a = vec4(1.0 - v_photo.z, v_photo.y, v_photo.w, v_photo.x);
	vec4 cell_b = v_mechanical;
	vec4 cell_c = vec4(v_photo.z, step(.98, v_photo.z), 0.0, 0.0);
	vec4 phenotype = mix(vec4(.82,.42,.58,.32), vec4(.74,.18,.64,.70), step(.5,v_matter.y));
	vec4 cellular = cell_membrane(v_world * 7.0, n, view_dir, v_seed,
			phenotype, cell_a, cell_b, cell_c, TIME);
	vec3 cargo = cell_transport(v_world * 5.0, v_seed, cell_a, cell_b, cell_c, TIME);
	vec2 voxel_rg = voxel_optics_enabled > .5
			? critter_exposure_at(v_world) : vec2(0.0);
	CritterVoxelOptics voxel = critter_voxel_optics(v_plan, v_local, n,
			voxel_rg, v_anatomy, v_part, v_law, v_photo, TIME + v_matter.w);
	// Unstained tissue baseline. Orientation and microstructure create the
	// phenotype read; hue no longer names the species.
	vec3 tissue = mix(vec3(.46,.45,.38), vec3(.61,.58,.46), cellular.y);
	vec3 shell = mix(vec3(.115,.12,.105), vec3(.27,.26,.22), cellular.x);
	ALBEDO = mix(o.albedo * tissue, shell, step(.5, 1.0 - abs(v_part - 2.0) / 2.0));
	METALLIC = o.metallic;
	if (v_part < 0.5 || (v_part >= 3.0 && v_part < 5.5)) {
		ALBEDO *= vec3(.48,.50,.46);
		METALLIC = o.metallic * 0.38;
	} else if (v_part >= 5.5 && v_part < 6.5) {
		ALBEDO *= vec3(.68,.66,.56);
	} else if (v_part >= 8.5 && v_part < 9.5) {
		ALBEDO *= vec3(.84,.82,.70);
	} else if (v_part >= 10.5) {
		ALBEDO = mix(ALBEDO, vec3(.34,.37,.34), .72);
	}
	if (v_plan > 2.5 && v_plan < 3.5) {
		// Value/absorption separation, not categorical organ colours.  The
		// intact cortex remains dominant while dense organs, low-density storage
		// spaces, fibers, stylets and claws answer light differently.
		if (v_part < .5) {
			ALBEDO = mix(ALBEDO, vec3(.31, .30, .255), .58);
			METALLIC = 0.0;
		} else if (v_part < 3.0) {
			ALBEDO = mix(ALBEDO, vec3(.39, .36, .285), .50);
		} else if (v_part < 4.0) {
			ALBEDO = mix(ALBEDO, vec3(.25, .225, .19), .72);
		} else if (v_part < 6.0) {
			ALBEDO = mix(ALBEDO, vec3(.29, .245, .17), .68);
		} else if (v_part < 7.0) {
			ALBEDO = mix(ALBEDO, vec3(.20, .205, .19), .76);
		} else if (v_part < 10.0) {
			ALBEDO = mix(ALBEDO, vec3(.47, .43, .335), .62);
		} else if (v_part < 10.5 || v_part >= 13.5) {
			ALBEDO = mix(ALBEDO, vec3(.48, .52, .49), .78);
			METALLIC = .05;
		} else {
			ALBEDO = mix(ALBEDO, vec3(.28, .315, .29), .66);
		}
	}
	float orient = .5 + .5 * dot(n, normalize(vec3(.61,.18,.77)));
	if (v_plan > .5 && v_plan < 1.5
			&& (v_part < .5 || (v_part > 1.5 && v_part < 2.5) || v_part >= 6.5)) {
		float ordered_band=pow(.5+.5*sin(v_law.x*2.0+dot(n,vec3(5.2,2.1,3.7))),10.0);
		ALBEDO=mix(vec3(.16,.18,.17),vec3(.28,.34,.33),ordered_band*.72);
		ALBEDO+=vec3(.035,.055,.065)*orient;
	}
	ALBEDO *= mix(vec3(1.0), vec3(.72,.76,.68), v_photo.z * .55);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(.74,.77,.66), cellular.x * .30);
	ALBEDO += vec3(.12,.105,.07) * cellular.w + vec3(.035,.05,.045) * orient * v_matter.y;
	// The field changes local optical behaviour, never the whole animal's tint.
	ALBEDO = mix(ALBEDO, voxel.absorption, .61 + .18 * v_anatomy.z);
	// Phase ridges and cuticular pillars remain readable in neutral light;
	// the RG8 field illuminates them but is not required to invent anatomy.
	ALBEDO *= mix(.58, 1.18, clamp(voxel.relief * 1.55, 0.0, 1.0));
	ALBEDO += voxel.current_light * .24 + voxel.durable_memory * .28;
	ROUGHNESS = clamp(o.roughness + .10 - 0.10 * v_look.z
			+ voxel.roughness_shift, 0.30, 1.0);
	SPECULAR = o.specular;
	EMISSION = o.emission * (.18 + .32 * v_matter.x);
	if (v_part >= 10.5) EMISSION += vec3(.025,.045,.04) * v_photo.x;
	EMISSION += vec3(.018,.032,.028) * cellular.z + vec3(.06,.085,.07) * cargo.x
			+ vec3(.10,.065,.025) * cargo.y;
	EMISSION += vec3(.08,.095,.075) * exp(-pow((v_axial - mix(-.48,.46,v_photo.y)) / .075, 2.0)) * v_photo.y;
	float tardigrade_route = exp(-pow((v_axial
			- mix(.36, -.40, fract(TIME * .075 + v_seed))) / .065, 2.0))
			* step(2.5, v_plan) * (1.0 - step(3.5, v_plan))
			* smoothstep(.006, .20, voxel_rg.g);
	EMISSION += voxel.current_light * .16 + voxel.durable_memory * .085
			+ vec3(.29, .31, .15) * tardigrade_route * .20;
	// Not a flash: photoshock bruises/perfuses the same tissue stack while
	// the legible event remains the resonator reversal and feeler arrest.
	ALBEDO *= mix(vec3(1.0), vec3(.80,.78,.68), v_photo.y * .34);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(.92,.88,.72), relay * .42);
	if (v_plan > .5 && v_plan < 1.5) {
		float mineral_gray=dot(ALBEDO,vec3(.299,.587,.114));
		float polar_flash=pow(.5+.5*sin(v_law.x*2.0+dot(n,vec3(7.1,3.3,5.8))),18.0);
		ALBEDO=mix(vec3(mineral_gray)*vec3(.82,.86,.82),vec3(.20,.29,.31),polar_flash*.58);
	}
	BACKLIGHT = o.backlight + voxel.current_light * .52 + voxel.durable_memory * .16;
	AO = o.ao;
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = clamp(max(o.sss, voxel.scatter), 0.0, 1.0);
	SSS_TRANSMITTANCE_COLOR = mix(o.sss_transmit,
			vec4(voxel.absorption + voxel.current_light * .18, 1.0), .36);
	SSS_TRANSMITTANCE_DEPTH = mix(o.sss_depth, .16 + v_thickness * .72,
			.34 + v_anatomy.z * .18);
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * (nm.x * .5 + dFdx(voxel.relief) * .20)
			+ BINORMAL * (nm.y * .5 + dFdy(voxel.relief) * .20));
	}
}
