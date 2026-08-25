shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE MODELLED HERO'S SKIN.
//
// `dream_tentacle.gdshader` cannot dress this creature. That shader BUILDS a
// limb in its vertex stage from a sixteen-point spine -- it is a generator,
// not a material -- so pointed at a modelled, skinned mesh it would throw the
// sculpt away and extrude a tube in its place.
//
// This is the other half: a SURFACE-ONLY material that takes the geometry
// exactly as Blender authored it and as the armature deforms it, and spends
// all its effort on the skin. It is the same shared material stack the
// procedural limb wore (`dream_entity_surface.gdshaderinc`), so the creature
// looks like itself either way.
//
// It reads the anatomy from the masks the model carries, rather than
// rediscovering it (§22):
//
//     COLOR.r  flesh_thickness     UV2.x  normalised rest X
//     COLOR.g  rest-Y correction   UV2.y  normalised rest Z
//     COLOR.b  gold_root
//     COLOR.a  sucker_region
//     anatomy_map.a  ocular_region
//
// Blender knows where the eye is. It should not have to be guessed from a
// noise field at forty metres per second.
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

group_uniforms hero;
// Which system this surface belongs to, so one shader dresses the whole
// creature: 0 flesh, 1 gold, 2 crystal, 3 membrane, 4 sucker, 5 cilium.
uniform int system_kind = 0;
uniform float hero_seed = 0.0;
uniform float emission_gain : hint_range(0.0, 4.0) = 1.0;
// Emergence, shared with the field: 0 fully withdrawn, 1 fully out.
uniform float grow : hint_range(0.0, 1.0) = 1.0;
// LC-6C — shared biological vocabulary, interpreted by this owner. This
// changes pressure, perfusion and mineral response only; the encounter's
// existing `grow` and cross-section laws retain all geometry authority.
uniform float lifecycle_stage : hint_range(0.0, 7.0) = 3.0;
// H1 — THE BAKED ANATOMY. Three facts about this body's geometry that no
// noise field can know, in one fetch:
//   R ambient occlusion (mostly the gold plates' own shadow on the flesh)
//   G curvature: convex crests vs concave creases
//   B thickness: how much meat is behind this point
uniform sampler2D anatomy_map : source_color, filter_linear_mipmap;
uniform float anatomy_strength : hint_range(0.0, 2.0) = 1.0;
// §12's last layer: the wet highlight stabilises AFTER the body stops. Fed
// from the creature, which raises it instantly and lets it decay.
uniform float body_motion : hint_range(0.0, 1.0) = 0.0;
// H6 — THE HERO'S HYPERDIMENSIONAL LAW: CROSS-SECTIONAL WITHDRAWAL.
//
// It does not retract. It does not shrink toward its root, and it does not
// fade. Its CROSS-SECTION closes — everywhere along its length at the same
// instant — while its length does not change at all. The limb stays exactly
// as long, and exactly where it is, and stops having a thickness.
//
// That is the field's own law (DREAM_FIELD_DIRECTION: r_visible =
// sqrt(r^2 - w^2)) applied to the hero's body: nothing is travelling, our
// slice is moving past it. A creature that leaves the way a 3-D animal leaves
// is a 3-D animal.
uniform float slice_close : hint_range(0.0, 1.0) = 0.0;
// WHERE THIS PIECE SITS ALONG THE BODY, 1 at the root and 0 at the tip.
//
// Only the cage has UVs. Every one of the ninety-four riders exports with
// POSITION, NORMAL, JOINTS and WEIGHTS and nothing else, so its UV arrives as
// (0,0) -- and the shared stack reads the vascular clock off uv.y. Which meant
// every gold plate, every crystal and every cilium on the creature pulsed at
// exactly the same instant, while the flesh they are seated in had a wave
// travelling along it. The metal was on a different heartbeat from the meat.
//
// The creature supplies each rider's seat instead. Negative means "this
// surface has real UVs, use them" -- the cage.
uniform float rider_v = -1.0;
// H4 — WHAT A RIDER DOES THAT SKINNING WILL NOT DO FOR IT.
//
// Every rider is bound to the cage's own weights, so it goes exactly where the
// flesh goes and does nothing of its own. But a cilium is a hair and should
// trail behind a whipping limb; a gold plate is a rigid mineral seated in
// something soft and should lift and settle as that thing bends; a sucker
// should press. None of that is skinning -- skinning is precisely the part
// that moves a rider AS IF it were the flesh.
//
// A rigid millimetre-scale offset in model space, sprung against the local
// velocity of the bone the piece is seated on. Small on purpose: this is
// mesostructure, and a gold plate that slides far enough to see is a gold
// plate that has come off the animal.
uniform vec3 rider_push = vec3(0.0);
// H4 — AND WHAT A RIGID PIECE DOES THAT SLIDING WILL NOT DO FOR IT.
//
// A translation moves a gold plate along the flesh. It does not TIP it, and
// tipping is most of what seating a hard thing in a soft one looks like: the
// flesh bends, the plate cannot, so it rocks and lifts at one edge. And a
// sucker does not trail when it presses -- it FLATTENS.
//
// Both need something a rigid offset cannot supply: a point to turn about.
// The creature sends each piece its own, tracked from the bone it is seated
// on, along with the piece's own radial axis for the flattening.
//
// `rider_tilt` is an axis times a small angle, applied as a cross product --
// exact enough below a few degrees, which is the entire range this uses.
uniform vec3 rider_pivot = vec3(0.0);
uniform vec3 rider_tilt = vec3(0.0);
uniform vec3 rider_axis = vec3(0.0, 1.0, 0.0);
uniform float rider_squash = 0.0;
// §10's contact list asks for five things -- compress, spread, deform, grip,
// release -- and `rider_squash` is only the first. A sucker meeting a surface
// does not merely get shorter: its RIM spreads out against the surface while
// its CUP pulls back behind it, and the hollow that leaves is the whole
// difference between a grip and a press. Letting go is a separate motion
// again, and a faster one.
//
// x how far the rim has spread, y how deep the cup has drawn back, z spare,
// w the piece's own radius -- zero on anything that is not a sucker, which is
// also what switches the whole thing off.
uniform vec4 rider_grip = vec4(0.0);
// WHERE THIS PIECE WOULD BE IF THE CREATURE WERE AT REST.
//
// The shared stack samples every one of its mesostructure fields -- the
// vascular clouds, the pores, the gold's ridged field, the crystal fracture --
// at the WORLD position of the fragment. Which means the pattern is fixed to
// the room and the creature moves THROUGH it: a gold plate's grain slides
// across the plate as the limb sweeps, a thing no surface does. It is a large
// part of what "the texture is not great" was pointing at, and it is invisible
// in a still frame, which is why it survived every photograph.
//
// A rider is rigid and bound to a single bone, so its rest position can be
// recovered exactly: undo the bone's current pose and reapply its rest one.
// One matrix does both. The flesh cannot be fixed this way -- it is weighted
// across twenty-eight bones and genuinely deforms -- and is left alone.
uniform mat4 rider_unpose = mat4(1.0);
// Proof-only old-behaviour comparator. Production leaves this true; the
// staged H1 capture can set false to show the world-space swimming it replaces.
uniform bool flesh_rest_space = true;
// Negative in production. The H1 paired capture pins it so A/A and A/B are
// rendered from one pose without live shader clocks becoming the treatment.
uniform float proof_time = -1.0;
group_uniforms;

varying vec3 v_world;
varying vec3 v_stable;
varying vec4 v_mask;
varying vec2 v_uv;

// Blender builds the cage along +Y. glTF converts that to Godot's -Z, and
// flips the second component of every UV set. X/Z fit inside this asserted
// envelope; primary strip V carries coarse Y and COLOR.g its small residual.
const float FLESH_REST_XZ_EXTENT = 0.16;
const float FLESH_REST_Y_CORRECTION_EXTENT = 0.012;

void vertex() {
	// Pass-through. The sculpt and the armature have already decided the
	// shape; a material that moves vertices here would be arguing with them.
	v_uv = UV;
	v_mask = COLOR;
	// The collapse is radial, so it rides the surface normal — on a limb the
	// normal IS the radial direction. Thick anatomy has further to go than
	// thin, which is why it takes the baked thickness with it: the muscular
	// root closes through more radius than an eyelid does, and they finish
	// together.
	// The radial direction on a limb: the surface normal with the along-body
	// component removed. On this mesh UV.y runs along the body, so BINORMAL is
	// the axial direction.
	vec3 axial_d = normalize(BINORMAL + vec3(0.0, 1e-5, 0.0));
	vec3 radial_d = NORMAL - axial_d * dot(NORMAL, axial_d);
	float rlen = length(radial_d);
	radial_d = rlen > 0.001 ? radial_d / rlen : vec3(0.0);
	// §12 — THE BOLUS MOVES THE FLESH, not only its colour. A pressure wave
	// that tints the skin and leaves the silhouette untouched is a texture
	// effect; one that swells the body as it passes is circulation. Thick
	// flesh swells more than a membrane does, and it travels root to tip.
	if (rider_v < 0.0) {
		float beat_v = clamp(1.0 - UV.y, 0.0, 1.0);
		float beat = pow(0.5 + 0.5 * cos((beat_v - pulse_phase) * 6.2831853), 9.0);
		VERTEX += radial_d * beat * (0.002 + 0.006 * clamp(COLOR.r, 0.0, 1.0));
	}
	if (slice_close > 0.0001) {
		// RADIAL ONLY. Collapsing straight along the normal also pulls the
		// end caps inward, because a cap's normal points ALONG the limb --
		// measured, the silhouette's long axis lost 59% of its length, which
		// would make this an ordinary retraction wearing a costume. On this
		// mesh UV.y runs along the body, so BINORMAL is the axial direction;
		// removing that component leaves the true radial one, and the caps
		// barely move at all.
		vec3 radial = radial_d;
		float here = mix(0.035, 0.115, clamp(COLOR.r, 0.0, 1.0));
		// sqrt(1 - w^2): the same cross-section curve the field uses, so the
		// limb thins slowly at first and then vanishes suddenly.
		float w = clamp(slice_close, 0.0, 1.0);
		float remaining = sqrt(max(0.0, 1.0 - w * w));
		VERTEX -= radial * here * (1.0 - remaining);
	}
	if (rider_v >= 0.0) {
		vec3 rel = VERTEX - rider_pivot;
		// Rock about the seat.
		rel += cross(rider_tilt, rel);
		// And press: a sucker loses height along its own axis and keeps its
		// width, which is what pressing something soft against a wall does.
		rel -= rider_axis * dot(rel, rider_axis) * rider_squash;
		// §10 — SPREAD AND GRIP. Split the piece into rim and cup by how far
		// out from its own axis a vertex lies: the outside flares against the
		// surface, the inside withdraws from it.
		if (rider_grip.w > 0.0001) {
			float ax = dot(rel, rider_axis);
			vec3 lat = rel - rider_axis * ax;
			float rr = length(lat) / rider_grip.w;
			lat *= 1.0 + rider_grip.x * 0.40 * smoothstep(0.35, 1.0, rr);
			ax -= rider_grip.y * 0.55 * (1.0 - smoothstep(0.0, 0.75, rr))
					* rider_grip.w;
			rel = lat + rider_axis * ax;
		}
		VERTEX = rider_pivot + rel;
	}
	VERTEX += rider_push;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The surface is sampled HERE rather than at v_world, so it belongs to the
	// body instead of to the room.
	if (rider_v >= 0.0) {
		v_stable = (rider_unpose * vec4(VERTEX, 1.0)).xyz;
	} else if (!flesh_rest_space) {
		v_stable = v_world;
	} else {
		// Exact undeformed cage coordinates, not the rejected canonical
		// cylinder. The sculpt's asymmetric bundles, orbit bowl, gold sockets,
		// folds and flattening are already present in these authored values.
		float rest_x = (UV2.x - 0.5) * (2.0 * FLESH_REST_XZ_EXTENT);
		float rest_z_blender = (0.5 - UV2.y) * (2.0 * FLESH_REST_XZ_EXTENT);
		float rest_y_norm = clamp(1.0 - UV.y, 0.0, 1.0)
				+ (COLOR.g - 0.5) * (2.0 * FLESH_REST_Y_CORRECTION_EXTENT);
		float rest_y_blender = clamp(rest_y_norm, 0.0, 1.0) * 1.60;
		v_stable = vec3(rest_x, rest_z_blender, -rest_y_blender);
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);

	DeCtx ctx;
	// ONLY THE FLESH CARRIES MASKS. The cage is the mesh Blender paints; every
	// rider is a single-material piece with no colour attribute, so its COLOR
	// arrives as white — and read as masks that means thickness 1, gold_root 1,
	// sucker 1 on every one of them. The first frame in a real
	// room showed exactly that: the membrane came out as a sheet of molten
	// gold, because white means "maximum metal" to this stack.
	bool painted = (system_kind == 0);
	// Only the flesh has UVs and therefore a bake.
	vec4 baked = painted ? texture(anatomy_map, v_uv) : vec4(1.0, 0.75, 0.5, 0.0);
	// The vertex mask is a coarse per-vertex guess at thickness; the bake
	// measured it per texel by sampling occlusion INSIDE the mesh. Trust the
	// measurement, and keep the mask as the low-frequency term.
	ctx.thickness = painted
			? clamp(mix(v_mask.r, baked.b, 0.7 * anatomy_strength), 0.0, 1.0)
			: 0.5;
	ctx.gold_root = painted ? clamp(v_mask.b, 0.0, 1.0) : 0.0;
	ctx.contact = painted ? clamp(v_mask.a, 0.0, 1.0) : 0.0;
	ctx.socket = painted ? clamp(baked.a, 0.0, 1.0) : 0.0;
	// Skin is under most tension where it is thin and where it is stretched
	// over the distal third reaching for something.
	// Distal is a pure function of the authored longitudinal strip, so the old
	// duplicate UV2 channel was unnecessary. `along` below is the same 0..1
	// root-to-tip coordinate; spell it here because context is built first.
	float distal = painted
			? clamp((clamp(1.0 - v_uv.y, 0.0, 1.0) - 0.62) / 0.38, 0.0, 1.0)
			: 0.3;
	ctx.stretch = clamp(0.25 + 0.5 * distal + 0.4 * (1.0 - ctx.thickness), 0.0, 1.0);
	ctx.vein = clamp(0.35 + 0.5 * ctx.thickness, 0.0, 1.0);
	// Curvature drives where a body is worn and where it stays wet: crests
	// are polished by contact, creases hold fluid.
	float crest = clamp((baked.g - 0.5) * 2.0, -1.0, 1.0);
	ctx.stretch = clamp(ctx.stretch + 0.35 * max(0.0, crest) * anatomy_strength,
			0.0, 1.0);
	ctx.lod = 1.0 - smoothstep(1.2, 6.0, length(VERTEX));

	// The mineral systems are the same tissue seen where it has hardened, so
	// they take the same stack with the masks pushed to their ends rather
	// than a second material with its own opinion about the light.
	if (system_kind == 1) {          // gold
		ctx.gold_root = 1.0;
		ctx.thickness = 1.0;
	} else if (system_kind == 2) {   // crystal
		ctx.gold_root = 0.15;
		ctx.thickness = 0.10;
		ctx.socket = 0.5;
	} else if (system_kind == 3) {   // membrane: a flesh sheet, not metal
		ctx.thickness = 0.35;
		ctx.gold_root = 0.0;
		ctx.stretch = 1.0;
	} else if (system_kind == 4) {   // sucker
		ctx.contact = 1.0;
		ctx.socket = 0.8;
	} else if (system_kind == 5) {   // cilium
		ctx.thickness = 0.06;
		ctx.stretch = 1.0;
	}

	// The shading UV: the cage's own, or the seat we were given.
	vec2 suv = rider_v >= 0.0 ? vec2(v_uv.x, rider_v) : v_uv;
	// HOW FAR DOWN THE BODY WE ARE: 0 at the root, 1 at the tip.
	//
	// glTF FLIPS V. Blender writes v = 0 at the root and 1 at the tip; the
	// exported file carries 1 at the root. Measured on this model: the cage's
	// uv.y is 1.000 at z = 0 (the root) and 0.027 at z = -1.55 (the tip). So
	// every read of uv.y as "how distal am I" was answering backwards, and
	// `rider_v` is authored to match the file rather than Blender.
	float along = clamp(1.0 - suv.y, 0.0, 1.0);
	// The vascular clock rides `along`, so the pressure wave travels ROOT TO
	// TIP -- outward, the way a body pushes blood into a limb -- rather than
	// from the tip back into the wall.
	vec2 cuv = vec2(suv.x, along);
	float de_time = proof_time >= 0.0 ? proof_time : TIME;
	DeMasks m = de_masks(v_stable, cuv, n, view_dir, de_time, hero_seed, ctx);
	DeOut o = de_shade(m, v_stable, cuv, n, view_dir, de_time, hero_seed, ctx);

	ALBEDO = o.albedo;
	METALLIC = o.metallic;
	// Creases stay wet; crests dry and polish.
	// Moving flesh throws its fluid film about; settled flesh lets it pool
	// and the highlight sharpens.
	ROUGHNESS = clamp(o.roughness + 0.13 * body_motion
			- 0.16 * max(0.0, crest) * anatomy_strength
			+ 0.10 * max(0.0, -crest) * anatomy_strength, 0.03, 1.0);
	SPECULAR = o.specular;
	EMISSION = o.emission * emission_gain;
	BACKLIGHT = o.backlight;
	// The bake knows what the shader cannot: a gold plate seated in flesh
	// blacks out what is under it. Multiplied in rather than replacing, so
	// the procedural cavity term still contributes.
	AO = o.ao * mix(1.0, baked.r, 0.85 * anatomy_strength);
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;

	// ---- LC-6C: ONE LARGE ORGAN'S READABLE LIFE -------------------------
	float ls = clamp(lifecycle_stage, 0.0, 7.0);
	float folded = 1.0 - step(0.5, abs(ls - 0.0));
	float bud = 1.0 - step(0.5, abs(ls - 1.0));
	float juvenile = 1.0 - step(0.5, abs(ls - 2.0));
	float exchange = 1.0 - step(0.5, abs(ls - 4.0));
	float senescent = 1.0 - step(0.5, abs(ls - 5.0));
	float shed = 1.0 - step(0.5, abs(ls - 6.0));
	float life_time = proof_time >= 0.0 ? proof_time : TIME;
	float uneven = 0.5 + 0.5 * sin(v_stable.y * 19.0 + hero_seed * 2.7);
	float seeking_band = pow(0.5 + 0.5 * sin(along * 25.0
			- life_time * 4.1 + hero_seed), 5.0);
	vec3 reserve_wine = vec3(0.035, 0.008, 0.055);
	vec3 perfused_wine = vec3(0.62, 0.025, 0.16);
	vec3 cold_exchange = vec3(0.20, 0.42, 0.52);
	vec3 old_bruise = vec3(0.105, 0.055, 0.18);
	ALBEDO = mix(ALBEDO, reserve_wine + ALBEDO * 0.18, folded * 0.95);
	ALBEDO = mix(ALBEDO, ALBEDO * 0.62 + perfused_wine * (0.46 + uneven * 0.28),
			bud * 0.90);
	// Juvenile tissue has not learned the adult's even pressure yet: broad
	// alternating carmine/lilac territories make that calibration legible at
	// room scale without changing one vertex or pretending growth is scale.
	vec3 juvenile_low = vec3(0.26, 0.012, 0.22);
	vec3 juvenile_high = vec3(0.62, 0.20, 0.72);
	vec3 juvenile_tissue = mix(juvenile_low, juvenile_high, uneven)
			+ ALBEDO * (0.16 + uneven * 0.16);
	ALBEDO = mix(ALBEDO, juvenile_tissue, juvenile * 0.94);
	ALBEDO += cold_exchange * exchange * (0.18 + seeking_band * 0.62);
	ALBEDO = mix(ALBEDO, old_bruise + ALBEDO * (0.48 + uneven * 0.16),
			senescent * 0.88);
	ALBEDO = mix(ALBEDO, vec3(0.16, 0.12, 0.20) + ALBEDO * 0.10,
			shed * 0.94);
	ROUGHNESS = clamp(ROUGHNESS + folded * 0.16 - bud * 0.13 - juvenile * 0.10
			- exchange * seeking_band * 0.18 + senescent * 0.20 + shed * 0.30,
			0.03, 1.0);
	// The existing mineral network is the organ's fastest readable tissue, so
	// its chemistry changes with the same stage byte. This adds no emissive
	// owner or light: it only recolours energy the approved skin already spent.
	float mineral_energy = max(max(EMISSION.r, EMISSION.g), EMISSION.b);
	EMISSION = mix(EMISSION, vec3(0.20, 0.015, 0.10) * mineral_energy,
			folded * 0.92);
	EMISSION = mix(EMISSION, vec3(1.00, 0.075, 0.18) * mineral_energy * 1.25,
			bud * 0.90);
	EMISSION = mix(EMISSION, mix(vec3(0.86, 0.10, 0.48),
			vec3(0.42, 0.22, 1.00), uneven) * mineral_energy * 1.15,
			juvenile * 0.92);
	EMISSION = mix(EMISSION, vec3(0.14, 0.78, 1.00) * mineral_energy
			* (0.72 + seeking_band * 0.72), exchange * 0.90);
	EMISSION = mix(EMISSION, vec3(0.22, 0.09, 0.34) * mineral_energy,
			senescent * 0.82);
	EMISSION = mix(EMISSION, vec3(0.08, 0.055, 0.095) * mineral_energy,
			shed * 0.94);
	float mineral_system = system_kind == 1 ? 1.0 : 0.0;
	METALLIC = clamp(METALLIC + senescent * mineral_system * 0.16
			+ shed * mineral_system * 0.24, 0.0, 1.0);
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.6 + BINORMAL * nm.y * 0.6);
	// Withdrawal dissolves the far end first, so the creature leaves along
	// its own length instead of vanishing all at once.
	// Fully closed: no cross-section left to draw.
	if (slice_close > 0.985) {
		discard;
	}
	// EMERGENCE, AND WHAT IT IS MEASURED ALONG.
	//
	// This read `v_region.y` -- the distal mask -- and read it inverted, which
	// was wrong twice over. Inverted, the limb filled in from the TIP and its
	// root was the last thing to arrive, so for two and a half seconds a
	// creature was in the room without being attached to the wall it came
	// through. And the distal mask is flat over the proximal 62% of the body
	// in any case, so it could only ever have animated the last third; the
	// rest would have popped in whole.
	//
	// `along` is linear over the entire length, so the limb extrudes.
	//
	// AND THE RIDERS GO WITH IT. This was gated on `painted`, and no rider is
	// painted, so all ninety-four ignored `grow` completely: the gold plates,
	// the crystals and the cilia hung in the air in full along the length of a
	// limb that was not there yet. A rider is small enough to leave whole or
	// take whole, so it goes when the flesh it is seated in has arrived.
	if (grow < 0.999 && along > grow) {
		discard;
	}
}
