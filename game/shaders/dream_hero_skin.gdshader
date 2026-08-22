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
	ctx.thickness = painted ? clamp(v_mask.r, 0.0, 1.0) : 0.5;
	ctx.gold_root = painted ? clamp(v_mask.b, 0.0, 1.0) : 0.0;
	ctx.contact = painted ? clamp(v_mask.a, 0.0, 1.0) : 0.0;
	ctx.socket = painted ? clamp(v_region.x, 0.0, 1.0) : 0.0;
	// Skin is under most tension where it is thin and where it is stretched
	// over the distal third reaching for something.
	float distal = painted ? v_region.y : 0.3;
	ctx.stretch = clamp(0.25 + 0.5 * distal + 0.4 * (1.0 - ctx.thickness), 0.0, 1.0);
	ctx.vein = clamp(0.35 + 0.5 * ctx.thickness, 0.0, 1.0);
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
	ROUGHNESS = o.roughness;
	SPECULAR = o.specular;
	EMISSION = o.emission * emission_gain;
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
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.6 + BINORMAL * nm.y * 0.6);
	// Withdrawal dissolves the far end first, so the creature leaves along
	// its own length instead of vanishing all at once.
	if (grow < 0.999 && painted) {
		float edge = smoothstep(grow, grow + 0.06, v_region.y);
		if (edge > 0.5) {
			discard;
		}
	}
}
