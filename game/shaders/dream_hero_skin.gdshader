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
group_uniforms;

varying vec3 v_world;
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
	if (slice_close > 0.0001) {
		// RADIAL ONLY. Collapsing straight along the normal also pulls the
		// end caps inward, because a cap's normal points ALONG the limb --
		// measured, the silhouette's long axis lost 59% of its length, which
		// would make this an ordinary retraction wearing a costume. On this
		// mesh UV.y runs along the body, so BINORMAL is the axial direction;
		// removing that component leaves the true radial one, and the caps
		// barely move at all.
		vec3 axial = normalize(BINORMAL + vec3(0.0, 1e-5, 0.0));
		vec3 radial = NORMAL - axial * dot(NORMAL, axial);
		float rl = length(radial);
		radial = rl > 0.001 ? radial / rl : vec3(0.0);
		float here = mix(0.035, 0.115, clamp(COLOR.r, 0.0, 1.0));
		// sqrt(1 - w^2): the same cross-section curve the field uses, so the
		// limb thins slowly at first and then vanishes suddenly.
		float w = clamp(slice_close, 0.0, 1.0);
		float remaining = sqrt(max(0.0, 1.0 - w * w));
		VERTEX -= radial * here * (1.0 - remaining);
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	float distal = painted ? v_region.y : 0.3;
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

	DeMasks m = de_masks(v_world, v_uv, n, view_dir, TIME, hero_seed, ctx);
	DeOut o = de_shade(m, v_world, v_uv, n, view_dir, TIME, hero_seed, ctx);

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
	if (grow < 0.999 && painted) {
		float edge = smoothstep(grow, grow + 0.06, v_region.y);
		if (edge > 0.5) {
			discard;
		}
	}
}
