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
//     COLOR.r  flesh_thickness     UV2.x  ocular_region
//     COLOR.g  wetness             UV2.y  distal_region
//     COLOR.b  gold_root
//     COLOR.a  sucker_region
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
group_uniforms;

varying vec3 v_world;
varying vec3 v_stable;
varying vec4 v_mask;
varying vec2 v_region;
varying vec2 v_uv;

void vertex() {
	// Pass-through. The sculpt and the armature have already decided the
	// shape; a material that moves vertices here would be arguing with them.
	v_uv = UV;
	v_mask = COLOR;
	v_region = UV2;
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
	v_stable = rider_v >= 0.0
			? (rider_unpose * vec4(VERTEX, 1.0)).xyz
			: v_world;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);

	DeCtx ctx;
	// ONLY THE FLESH CARRIES MASKS. The cage is the mesh Blender paints; every
	// rider is a single-material piece with no colour attribute, so its COLOR
	// arrives as white — and read as masks that means thickness 1, wetness 1,
	// gold_root 1, sucker 1 on every one of them. The first frame in a real
	// room showed exactly that: the membrane came out as a sheet of molten
	// gold, because white means "maximum metal" to this stack.
	bool painted = (system_kind == 0);
	// Only the flesh has UVs and therefore a bake.
	vec3 baked = painted ? texture(anatomy_map, v_uv).rgb : vec3(1.0, 0.75, 0.5);
	// The vertex mask is a coarse per-vertex guess at thickness; the bake
	// measured it per texel by sampling occlusion INSIDE the mesh. Trust the
	// measurement, and keep the mask as the low-frequency term.
	ctx.thickness = painted
			? clamp(mix(v_mask.r, baked.b, 0.7 * anatomy_strength), 0.0, 1.0)
			: 0.5;
	ctx.gold_root = painted ? clamp(v_mask.b, 0.0, 1.0) : 0.0;
	ctx.contact = painted ? clamp(v_mask.a, 0.0, 1.0) : 0.0;
	ctx.socket = painted ? clamp(v_region.x, 0.0, 1.0) : 0.0;
	// Skin is under most tension where it is thin and where it is stretched
	// over the distal third reaching for something.
	// Same flip: UV2.y holds Blender's distal mask, which is 0 over the
	// proximal 62% and ramps to 1 at the tip -- and arrives inverted. Read as
	// it was, the skin was most stretched at the ROOT and slackest on the
	// third of the body that is actually doing the reaching.
	float distal = painted ? clamp(1.0 - v_region.y, 0.0, 1.0) : 0.3;
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
	DeMasks m = de_masks(v_stable, cuv, n, view_dir, TIME, hero_seed, ctx);
	DeOut o = de_shade(m, v_stable, cuv, n, view_dir, TIME, hero_seed, ctx);

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
