shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/dream_fauna_style.gdshaderinc"
#include "res://shaders/dream_irradiance.gdshaderinc"
#include "res://shaders/dream_incarnation.gdshaderinc"

// These are already authored linear tokens. `source_color` would convert them
// a second time and crush the bounded dark-live wine below display black.
uniform vec3 base_color = vec3(0.20, 0.025, 0.075);
uniform vec3 gold_color = vec3(0.72, 0.40, 0.09);
uniform float gold_gain : hint_range(0.0, 1.0) = 1.0;
uniform vec3 jewel_color = vec3(0.18, 0.404, 0.36);
uniform vec3 sclera_color = vec3(0.52, 0.31, 0.10);
uniform float gait_amount = 0.12;
uniform float gait_hz = 0.50;
uniform float family_motif = 0.0;
uniform float fauna_dark_glow : hint_range(0.018, 0.10) = 0.10;
// Production always animates from TIME. Shot harnesses may pin this clock and
// zero the gain to price the rest of the live Dream's animation noise.
uniform float ether_breath_gain : hint_range(0.0, 1.0) = 1.0;
uniform float ether_time_override = -1.0;
uniform float fauna_time_override = -1.0;
// Production is 1.0. The MBIO-4 proof may pin 0.0 on the same material to
// price the exact wrinkle contribution against two unchanged controls.
uniform float wrinkle_gain = 1.0;
// Existing FA2 primitives have no authored fauna COLOR/CUSTOM0 channels. The
// ruled part kit flips this to one; until then the procedural cell field keeps
// Slice A observable without pretending those meshes were already authored.
uniform float vertex_channels_ready : hint_range(0.0, 1.0) = 0.0;
// CT-1: the family's skin atlas, composed from the cases' plates
// (art/tools/build_fauna_skins.py) in the mesh's own CUSTOM0 (body_t,
// angle) space. skin_ready gates it; the atlas's mask agrees with the
// procedural wire so the gold is one thing, not two.
uniform sampler2D skin_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D skin_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float skin_ready : hint_range(0.0, 1.0) = 0.0;
uniform float skin_amount : hint_range(0.0, 1.0) = 0.78;
uniform float skin_normal_depth : hint_range(0.0, 2.0) = 0.9;
uniform vec2 skin_repeat = vec2(1.0, 1.0);

uniform vec3 lamp_origin = vec3(0.0);
uniform vec3 lamp_splash = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform float lamp_reach = 8.5;
uniform float lamp_cos_outer = 0.766;
uniform float lamp_energy = 0.0;
uniform sampler3D exposure_tex : filter_linear, repeat_enable,
		hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;

varying vec3 fauna_world;
varying vec3 fauna_local;
varying vec3 fauna_normal;
varying highp vec4 fauna_data;
varying vec4 fauna_vertex_region;
varying vec2 fauna_skin_uv;
// LC-3B. x the decoded stage 0..7, y its progress-free turgor, z secretion
// sheen, w the withdrawal that senescence and shedding share.
varying vec4 fauna_stage;

// LC-3B — THE STAGE, OUT OF THE ONLY BITS THAT SURVIVE THE TRIP.
//
// FA-V4 measured that Compatibility stores INSTANCE_CUSTOM as half-floats and
// truncates the mantissa, so the low byte of every pair is unreliable. The
// flag byte is a high byte and survives exactly, and bits 6-7 of it carry a
// sub-index within the group BIRTHING/REABSORBING already select. Eight
// stages therefore arrive intact without a new channel or a second batch.
float fauna_stage_of(highp float flags) {
	float birthing = fauna_flag(flags, 16.0);
	float reabsorbing = fauna_flag(flags, 32.0);
	float sub = fauna_flag(flags, 64.0) + fauna_flag(flags, 128.0) * 2.0;
	// neither flag: 0 folded, 1 mature, 2 exchange, 3 senescent
	float settled = step(0.5, sub) * (sub + 2.0);
	return reabsorbing * (6.0 + min(sub, 1.0))
			+ birthing * (1.0 - reabsorbing) * (1.0 + min(sub, 1.0))
			+ (1.0 - birthing) * (1.0 - reabsorbing) * settled;
}

void vertex() {
	fauna_data = INSTANCE_CUSTOM;
	float flags = fauna_high_byte(INSTANCE_CUSTOM.b);
	float activity = fauna_unit(fauna_low_byte(INSTANCE_CUSTOM.b));
	float fauna_time = fauna_time_override >= 0.0 ? fauna_time_override : TIME;
	float hush = fauna_flag(flags, 1.0);
	float phase = fract(INSTANCE_CUSTOM.r) * 6.28318530718;
	float gait = sin(fauna_time * 6.28318530718 * gait_hz + phase);
	float live_activity = activity * (1.0 - hush);
	float region = floor(clamp(COLOR.r, 0.0, 1.0) * 7.0 + 0.5);
	float tracker = fauna_flag(flags, 8.0);
	float tracked_organ = max(1.0 - step(0.45, abs(region - 5.0)),
			1.0 - step(0.45, abs(region - 6.0)));
	vec3 eye_center = vec3(0.0, 0.36, 0.403);
	vec3 eye_world = (MODEL_MATRIX * vec4(eye_center, 1.0)).xyz;
	vec3 camera_ray = CAMERA_POSITION_WORLD - eye_world;
	vec2 camera_plane = vec2(dot(camera_ray, normalize(MODEL_MATRIX[0].xyz)),
			dot(camera_ray, normalize(MODEL_MATRIX[1].xyz)));
	vec2 gaze = clamp(camera_plane * 0.05,
			vec2(-0.023), vec2(0.023));
	VERTEX.xy += gaze * tracker * tracked_organ * vertex_channels_ready;

	// ---- LC-3B POSTURE -------------------------------------------------
	// Every multiplier below is bounded inside [0.82, 1.18] and every one of
	// them is applied to COMPLETE anatomy. Nothing here scales a creature
	// from or toward zero; age is carried by how the tissue is held, which is
	// what the ruling asks for and what the folded-anatomy doctrine already
	// requires of the margin one resolution up.
	float stage = fauna_stage_of(flags);
	float is_folded = 1.0 - step(0.5, abs(stage - 0.0));
	float is_bud = 1.0 - step(0.5, abs(stage - 1.0));
	float is_juvenile = 1.0 - step(0.5, abs(stage - 2.0));
	float is_mature = 1.0 - step(0.5, abs(stage - 3.0));
	float is_exchange = 1.0 - step(0.5, abs(stage - 4.0));
	float is_senescent = 1.0 - step(0.5, abs(stage - 5.0));
	float is_shed = 1.0 - step(0.5, abs(stage - 6.0));
	float is_stain = 1.0 - step(0.5, abs(stage - 7.0));
	// MBIO-4: the Button bed and its dead impressions use their existing mesh
	// as biofilm architecture. Growth stress raises branching wrinkles; a new
	// stain begins flat and organizes over its room's slow fixed tick.
	float vertex_matter = fauna_unit(fauna_high_byte(INSTANCE_CUSTOM.g));
	float is_biofilm = 1.0 - step(0.45, abs(family_motif));
	float wrinkle_order = is_stain > 0.5 ? vertex_matter
			: clamp(vertex_matter * 0.72, 0.0, 1.0);
	float wrinkle_branch = pow(clamp(0.5 + 0.5 * sin(
			VERTEX.x * 31.0 + sin(VERTEX.z * 19.0 + phase) * 2.4),
			0.0, 1.0), 7.0);
	VERTEX += NORMAL * wrinkle_branch * wrinkle_order * is_biofilm
			* wrinkle_gain * 0.034;

	float slow = sin(fauna_time * 0.9 + phase);

	// Contracted and sealed, but entire: the folded organ grips itself tightly.
	float draw_in = 1.0 - 0.16 * is_folded;
	// Taut internal pressure. The bud is the widest the body ever is.
	float turgor = 1.0 + (0.14 + 0.025 * slow) * is_bud;
	// Over-responsive tissue: the same gait, answered too hard.
	float responsiveness = 1.0 + 1.15 * is_juvenile - 0.25 * is_senescent
			- 0.55 * is_shed;
	// Uneven pressure. One axis lags the other, so the silhouette stops
	// agreeing with itself without any part of it leaving.
	float uneven = 0.11 * is_senescent * slow;
	// Collapsing attachment: the body leans off its own footing and settles,
	// which is a shear and a droop rather than a disappearance.
	float slump = 0.16 * is_shed;

	VERTEX.y += gait * gait_amount * live_activity * responsiveness;
	VERTEX.xz *= (1.0 + gait * 0.06 * live_activity) * draw_in * turgor;
	VERTEX.x *= 1.0 + uneven;
	VERTEX.z *= 1.0 - uneven;
	// Juvenile tissue has all its parts but does not yet hold equal pressure.
	VERTEX.x *= 1.0 + 0.16 * is_juvenile;
	VERTEX.z *= 1.0 - 0.14 * is_juvenile;
	// Exchange tissue narrows and lengthens into a receptive cleft.
	VERTEX.x *= 1.0 - 0.12 * is_exchange;
	VERTEX.z *= 1.0 + 0.18 * is_exchange;
	VERTEX.y *= 1.0 - 0.18 * is_shed;
	// Reaching: the exchange stage leans toward what it is trying to touch.
	VERTEX.z += 0.14 * is_exchange * (0.55 + 0.45 * slow) * VERTEX.y;
	VERTEX.xz += VERTEX.y * slump * vec2(0.85, -0.55);
	// A stain is already lying on the floor; it does not breathe.
	VERTEX.y = mix(VERTEX.y, VERTEX.y * 0.86, is_stain);

	fauna_stage = vec4(stage,
			clamp(turgor - 1.0 + 0.5 * is_mature, 0.0, 1.0),
			clamp(0.75 * is_exchange + 0.45 * is_juvenile
					+ 0.60 * is_shed + 0.85 * is_stain, 0.0, 1.0),
			clamp(0.55 * is_senescent + 0.85 * is_shed + 1.0 * is_stain,
					0.0, 1.0));
	fauna_local = VERTEX;
	fauna_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fauna_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	fauna_vertex_region = vec4(COLOR.rgb, CUSTOM0.x);
	fauna_skin_uv = vec2(CUSTOM0.x, CUSTOM0.y) * skin_repeat;
}

void fragment() {
	float nutrient = fauna_unit(fauna_high_byte(fauna_data.g));
	// LC-5: every living family receives the room's one conserved ether value
	// in the old presentation-only emergence byte. The high byte remains
	// family-specific matter: ethermoss for Buttons, death stain for Wine
	// Anemones, and the existing allocation/activity measure for other tissue.
	float ether_amount = fauna_unit(fauna_low_byte(fauna_data.g));
	float hue_jitter = fauna_unit(fauna_high_byte(fauna_data.a));
	float pattern_jitter = fauna_unit(fauna_low_byte(fauna_data.a));
	float ex_y = clamp(fauna_world.y / max(0.001, exposure_height),
			0.0625, 0.9375);
	vec2 irradiance_field = texture(exposure_tex, vec3(
			fauna_world.x / exposure_extent, fauna_world.z / exposure_extent,
			ex_y)).rg;
	vec4 irradiance = dream_irradiance(fauna_world, fauna_normal,
			irradiance_field, lamp_origin);
	float awake = irradiance.w;
	int incarnation_slot = int(floor(incarnation_fauna.z + 0.5));
	vec4 incarnation_skin = dream_incarnation_surface(fauna_world,
			fauna_local.xz, irradiance_field.r, awake, awake, 0.0,
			incarnation_slot, vec4(base_color, 0.8));

	float retained = irradiance_field.r;

	// ---- LC-3B SURFACE ---------------------------------------------------
	float stage = fauna_stage.x;
	float fauna_time = fauna_time_override >= 0.0 ? fauna_time_override : TIME;
	float turgor = fauna_stage.y;
	float sheen = fauna_stage.z;
	float withdrawal = fauna_stage.w;
	float is_folded = 1.0 - step(0.5, abs(stage - 0.0));
	float is_bud = 1.0 - step(0.5, abs(stage - 1.0));
	float is_juvenile = 1.0 - step(0.5, abs(stage - 2.0));
	float is_mature = 1.0 - step(0.5, abs(stage - 3.0));
	float is_exchange = 1.0 - step(0.5, abs(stage - 4.0));
	float is_senescent = 1.0 - step(0.5, abs(stage - 5.0));
	float is_shed = 1.0 - step(0.5, abs(stage - 6.0));
	float is_stain = 1.0 - step(0.5, abs(stage - 7.0));

	// PERFUSION. How much of the body's own circulation reaches this surface.
	// Mature is the strongest coherent case; the bud is concentrated rather
	// than strong; senescence and shedding withdraw it toward the root.
	float perfusion = 0.42
			+ 0.30 * is_bud
			+ 0.42 * is_juvenile
			+ 0.58 * is_mature
			+ 0.50 * is_exchange
			+ 0.10 * is_senescent
			+ 0.04 * is_shed;
	perfusion *= 1.0 - 0.55 * withdrawal;
	// SEALED. The folded body reads as a closed surface: less internal line,
	// more of a single tight skin.
	float sealed_surface = is_folded;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - fauna_world);
	// SURFACE TENSION AS AN EXPONENT. A taut bud and a glossy juvenile carry
	// a tighter, later-breaking rim; slack senescent tissue carries a broad
	// soft one. Clamped so the exponent can never reach zero or blow up.
	float tension = clamp(2.2 - 0.85 * turgor - 0.55 * is_juvenile
			+ 0.75 * is_senescent + 0.55 * is_shed, 0.85, 4.2);
	float fresnel = pow(1.0 - clamp(abs(dot(normalize(fauna_normal), view_dir)),
			0.0, 1.0), tension);
	// WETNESS. Secretion is a sheen that sits on top of the rim, strongest
	// where the body is trying to make or has just broken a contact.
	float wetness = clamp(sheen * (0.35 + fresnel * 0.85), 0.0, 1.0);
	float cone_edge = smoothstep(0.015, 0.20, awake)
			* (1.0 - smoothstep(0.34, 0.78, awake));

	float procedural_wire = fauna_cloisonne_wire(fauna_local, pattern_jitter,
			family_motif);
	// CT-1: the atlas. Its wire mask joins the procedural wire; its jewels
	// join the authored jewels; its albedo takes the place of the flat wine
	// under the same irradiance.
	vec4 skin_mask_px = texture(skin_mask, fauna_skin_uv);
	vec3 skin_px = texture(skin_albedo, fauna_skin_uv).rgb;
	procedural_wire = max(procedural_wire, skin_mask_px.r * skin_ready);
	// Authored COLOR.r stores the logical 0..7 region as region/7 because the
	// GPU color stream is UNORM. Region 2 is gold wire/selvage; region 3 jewel.
	float region = floor(clamp(fauna_vertex_region.r, 0.0, 1.0) * 7.0 + 0.5);
	float authored_gold = 1.0 - step(0.45, abs(region - 2.0));
	float authored_jewel = max(1.0 - step(0.45, abs(region - 3.0)),
			1.0 - step(0.45, abs(region - 5.0)));
	float authored_sclera = 1.0 - step(0.45, abs(region - 4.0));
	float authored_lid = 1.0 - step(0.45, abs(region - 6.0));
	procedural_wire *= 1.0 - authored_jewel * vertex_channels_ready;
	// Authored regions add named plates/organs; the shared procedural wire still
	// crosses wine cells, so attributed meshes do not collapse into one flat
	// region color while waiting for later family-specific pattern controls.
	float gold_mask = max(procedural_wire,
			authored_gold * vertex_channels_ready);
	float jewel_mask = max(authored_jewel * vertex_channels_ready,
			skin_mask_px.g * skin_ready);

	vec3 wine = dream_irradiance_hue(mix(incarnation_skin.rgb,
			base_color * vec3(1.10, 0.86, 1.08), hue_jitter * 0.18));
	// A life can be read before it is named: concentrated hot bud, electrically
	// over-responsive juvenile, and cool wet exchange tissue. These remain
	// albedo responses inside the same lamp contract, never self-light.
	wine *= mix(vec3(1.0), vec3(1.20, 0.76, 1.04), is_bud * 0.45);
	wine *= mix(vec3(1.0), vec3(1.02, 0.66, 1.34), is_juvenile * 0.42);
	wine *= mix(vec3(1.0), vec3(0.68, 0.88, 1.38), is_exchange * 0.52);
	// The atlas wears the wine: the wine keeps its level and hue, the plate
	// supplies structure (a modulation around its own mean) and a little of
	// its colour. Never a recolour — the direction is wine with gold.
	float skin_lum = dot(skin_px, vec3(0.299, 0.587, 0.114));
	vec3 skin_mod = vec3(0.55 + 0.9 * skin_lum) + (skin_px - vec3(skin_lum)) * 0.35;
	wine = mix(wine, wine * skin_mod, skin_ready * skin_amount);
	// BRUISED TRANSLUCENCY. Senescence and shedding do not grey out: the
	// wine goes blue-violet and uneven, the way tissue does when its
	// circulation is leaving rather than when it is dirty.
	vec3 bruise = vec3(0.62, 0.42, 1.05);
	float mottle = 0.5 + 0.5 * sin(fauna_local.x * 21.0 + fauna_local.z * 17.0
			+ pattern_jitter * 6.28318530718);
	wine = mix(wine, wine * bruise * (0.72 + 0.42 * mottle),
			clamp(withdrawal * 0.85, 0.0, 1.0));
	float life = clamp(0.72 + nutrient * 0.16 + ether_amount * 0.12, 0.0, 1.0)
			* (0.55 + 0.45 * perfusion);
	// Darkness contains wine matter only. Gold and jewel response are exactly
	// multiplied by awake, so neither can self-light outside the service cone.
	// The ordered 0.10 control is converted into display-linear material
	// response here. ACES crushes a literal 0.10 unshaded value into black on
	// the production Compatibility path, so the bounded 2.2 response restores
	// a silhouette while its 0.22 peak remains far below hazard 0.55.
	vec3 wine_chroma = wine / max(max(wine.r, wine.g), max(wine.b, 0.001));
	float anatomy_line = clamp(max(procedural_wire,
			vertex_channels_ready * (0.32 + fauna_vertex_region.g * 0.68)),
			0.0, 1.0);
	vec3 neon_colour = mix(wine_chroma, jewel_color,
			0.12 + hue_jitter * 0.28);
	vec3 dark_body = wine * 0.012 * (1.0 - anatomy_line)
			+ neon_colour * fauna_dark_glow * 2.2 * life * anatomy_line
			* irradiance.x;
	// The folded body shows almost no internal line; the mature one shows the
	// most coherent. This is the same anatomy either way -- what changes is
	// how much of its circulation has reached the surface.
	anatomy_line = clamp(anatomy_line * (0.45 + 1.10 * perfusion)
			* (1.0 - 0.55 * sealed_surface), 0.0, 1.0);
	float vein = pow(anatomy_line, mix(1.8, 0.72,
			clamp(irradiance_vein_branch * 0.65, 0.0, 1.0)));
	// CONTACT-SEEKING BANDS. During exchange an electrochemical band travels
	// the body toward whatever it is reaching for. It is a band on existing
	// tissue, never a beam, a particle or a glyph.
	float band = pow(clamp(0.5 + 0.5 * sin(fauna_local.y * 15.0
			- fauna_time * 4.1 + fauna_data.r * 6.28318530718), 0.0, 1.0), 3.4);
	vein = clamp(vein + band * is_exchange * 0.85, 0.0, 1.0);
	vec3 oblique_body = wine * (0.22 + retained * 0.10)
			+ neon_colour * vein * 0.48
			+ jewel_color * fresnel * 0.16;
	vec3 lit_wine = mix(wine * awake * (0.74 + retained * 0.18),
			oblique_body, irradiance.y * 0.82);
	vec3 ruled_gold = gold_color * gold_gain;
	vec3 gilt = ruled_gold * awake * gold_mask
			* (0.74 + fresnel * (0.18 + cone_edge * 1.10));
	vec3 gilt_rim = ruled_gold * awake * fresnel * cone_edge * 0.82;
	vec3 jewel = jewel_color * awake * jewel_mask * (0.72 + fresnel * 0.42);
	vec3 sclera = sclera_color * awake * authored_sclera
			* (0.70 + fresnel * 0.18);
	vec3 lid = base_color * 0.24 * awake * authored_lid;
	vec3 full_body = mix(lit_wine, gilt, gold_mask) + gilt_rim + jewel
			+ sclera + lid;
	// Secretion reads as a wet film over whatever the body already is, not as
	// a new colour laid on top of it.
	full_body += (wine_chroma * 0.30 + jewel_color * 0.42) * wetness * awake
			* (0.35 + retained * 0.30);
	ALBEDO = dark_body + mix(lit_wine, full_body,
			max(irradiance.y * 0.58, irradiance.z));
	// The seeking band has to read through the live architecture noise floor.
	// It is still reflected lamp colour in ALBEDO, never emission.
	ALBEDO += jewel_color * is_exchange * awake * (0.18 + band * 0.34);
	ALBEDO += mix(base_color, jewel_color, 0.62) * is_juvenile * awake * 0.30;

	// ---- LC-5 THE CLOSED BREATH -----------------------------------------
	// One material describes three directions of the same transport medium.
	// It never emits light or draws a free-floating volume: the apparent cold
	// plasma is a moving reflected film attached to anatomy already submitted
	// by the five bounded batches.
	float is_moss = 1.0 - step(0.45, abs(family_motif - 0.0));
	float is_reclaimer = 1.0 - step(0.45, abs(family_motif - 2.0));
	float is_breather = (1.0 - is_moss) * (1.0 - is_reclaimer);
	float breath_phase = fauna_data.r * 6.28318530718;
	float ether_time = ether_time_override >= 0.0 ? ether_time_override : TIME;
	float radial_breath = pow(clamp(0.5 + 0.5 * sin(
			length(fauna_local.xz) * 18.0 - ether_time * 2.15 + breath_phase),
			0.0, 1.0), 5.0);
	float inward_breath = pow(clamp(0.5 + 0.5 * sin(
			length(fauna_local) * 15.0 + ether_time * 2.55 + breath_phase),
			0.0, 1.0), 6.0);
	float return_breath = pow(clamp(0.5 + 0.5 * sin(
			fauna_local.y * 22.0 + ether_time * 1.85 + breath_phase),
			0.0, 1.0), 5.0);
	float hyphae = fauna_cloisonne_wire(fauna_local * 2.35,
			pattern_jitter, family_motif + 1.0);
	// Raised ridges and the darker channels below them are one transport
	// network, not decorative slime. For stains `nutrient` is slow organization;
	// for living Buttons it is the moss mass already carried in this byte.
	float wrinkle_a = fauna_cloisonne_wire(fauna_local * 1.28,
			pattern_jitter, 5.0);
	float wrinkle_b = fauna_cloisonne_wire(fauna_local * 2.65 + vec3(0.17),
			pattern_jitter, 8.0);
	float wrinkle_network = clamp(wrinkle_a * 0.78 + wrinkle_b * 0.52,
			0.0, 1.0) * nutrient;
	float wrinkle_owner = max(is_moss, is_stain) * wrinkle_gain;
	vec3 cold_ether = mix(vec3(0.18, 0.34, 0.72), jewel_color,
			0.34 + hue_jitter * 0.26);
	// The bed has gold conducting hyphae and jewel vesicles. Darkness keeps
	// only a sub-dark-glow trace; the unreliable lamp reveals the circulation.
	// A faint continuous film establishes the medium; the narrow travelling
	// crest establishes direction. Without the film a still frame showed only
	// a few unrelated blue pixels and did not read as breath at gameplay range.
	float moss_exhale = is_moss * ether_amount * (0.18 + radial_breath * 0.82);
	float tissue_inhale = is_breather * ether_amount * (0.10 + inward_breath * 0.90);
	float stain_return = is_reclaimer * nutrient * (0.12 + return_breath * 0.88);
	float ether_film = clamp(ether_breath_gain * (moss_exhale * 2.80
			+ tissue_inhale * 1.10 + stain_return * 1.50), 0.0, 0.82);
	// A hue replacement reads as cold transport crossing warm tissue; merely
	// adding blue to the already bright lamp response washed back to white.
	// The target still follows awake, so this is reflected colour rather than
	// a new light source. Lamp-off keeps only the faint 0.06 plasma trace.
	ALBEDO = mix(ALBEDO, cold_ether * (0.06 + awake * 0.94), ether_film);
	ALBEDO += ether_breath_gain * ruled_gold * is_moss * hyphae
			* nutrient * awake * 0.52;
	// Apply transport anatomy after the cold ether film so the channel cannot
	// be washed back into it. Dark below, narrow mineral ridge above.
	ALBEDO *= 1.0 - wrinkle_owner * wrinkle_network * 0.48;
	ALBEDO += ruled_gold * awake * wrinkle_owner * wrinkle_network * 0.68;

	// ---- LC-4B THE STAIN --------------------------------------------------
	// A persistent impression of withdrawn tissue. It keeps the body's own
	// vascular line, loses the body's structure, and gains the thin-film
	// iridescence of something wet that has been lying there a while. It is
	// deliberately beautiful and deliberately wrong to touch: no gore, no
	// grey, no dissolve, and nothing that reads as a separate organism.
	if (is_stain > 0.5) {
		float radial = clamp(length(fauna_local.xz) * 3.4, 0.0, 1.0);
		// Capillary negative space: the vessels are where the mark is NOT.
		float capillary = fauna_cloisonne_wire(fauna_local * 1.7,
				pattern_jitter, family_motif + 3.0);
		// A thin-film order that turns with the view, so the mark moves as
		// the player's lamp passes rather than sitting flat.
		float film = fract(hue_jitter * 0.85 + fresnel * 1.35
				+ radial * 0.55);
		vec3 iridescence = vec3(
				0.5 + 0.5 * cos(6.28318530718 * (film + 0.00)),
				0.5 + 0.5 * cos(6.28318530718 * (film + 0.33)),
				0.5 + 0.5 * cos(6.28318530718 * (film + 0.67)));
		// nutrient carries how much this lineage has returned here.
		float depth = clamp(0.35 + nutrient * 0.75, 0.0, 1.0);
		vec3 membrane = wine * bruise * (0.55 + 0.45 * depth);
		vec3 mark = membrane * (1.0 - capillary * 0.62)
				+ iridescence * jewel_color * 0.55 * awake
						* (0.30 + fresnel * 0.95)
				+ ruled_gold * capillary * awake * 0.28 * depth;
		// It fades at its own edge instead of ending on a cut line.
		float edge = 1.0 - smoothstep(0.62, 1.0, radial);
		mark *= 0.35 + 0.65 * edge;
		ALBEDO = mix(ALBEDO, mark, clamp(0.90 * edge + 0.10, 0.0, 1.0));
	}
	if (incarnation_id > 0.5 && incarnation_id < 6.5) {
		ALBEDO = mix(ALBEDO, incarnation_skin.rgb,
			0.28 + irradiance.y * 0.20);
	}
	// CT-1: the atlas normal through a derivative cotangent frame — the
	// fauna meshes carry no tangents, so the frame is built per pixel from
	// the world position and the atlas coordinate.
	if (skin_ready > 0.001) {
		vec3 n_ts = texture(skin_normal, fauna_skin_uv).rgb * 2.0 - 1.0;
		n_ts.xy *= skin_normal_depth * skin_ready;
		vec3 n_w = normalize(fauna_normal);
		vec3 dp1 = dFdx(fauna_world);
		vec3 dp2 = dFdy(fauna_world);
		vec2 duv1 = dFdx(fauna_skin_uv);
		vec2 duv2 = dFdy(fauna_skin_uv);
		vec3 dp2perp = cross(dp2, n_w);
		vec3 dp1perp = cross(n_w, dp1);
		vec3 t = dp2perp * duv1.x + dp1perp * duv2.x;
		vec3 b = dp2perp * duv1.y + dp1perp * duv2.y;
		float inv_max = inversesqrt(max(dot(t, t), max(dot(b, b), 1e-8)));
		vec3 perturbed = normalize(t * inv_max * n_ts.x + b * inv_max * n_ts.y + n_w * n_ts.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(perturbed, 0.0)).xyz);
		// The fauna contract (DreamFaunaTest): no PBR or emission writes — the
		// atlas reaches the light only through ALBEDO and this NORMAL.
	}
}
