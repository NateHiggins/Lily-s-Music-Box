shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/dream_fauna_style.gdshaderinc"
#include "res://shaders/dream_irradiance.gdshaderinc"

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
// Existing FA2 primitives have no authored fauna COLOR/CUSTOM0 channels. The
// ruled part kit flips this to one; until then the procedural cell field keeps
// Slice A observable without pretending those meshes were already authored.
uniform float vertex_channels_ready : hint_range(0.0, 1.0) = 0.0;

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

void vertex() {
	fauna_data = INSTANCE_CUSTOM;
	float flags = fauna_high_byte(INSTANCE_CUSTOM.b);
	float activity = fauna_unit(fauna_low_byte(INSTANCE_CUSTOM.b));
	float hush = fauna_flag(flags, 1.0);
	float phase = fract(INSTANCE_CUSTOM.r) * 6.28318530718;
	float gait = sin(TIME * 6.28318530718 * gait_hz + phase);
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
	VERTEX.y += gait * gait_amount * live_activity;
	VERTEX.xz *= 1.0 + gait * 0.06 * live_activity;
	fauna_local = VERTEX;
	fauna_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fauna_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	fauna_vertex_region = vec4(COLOR.rgb, CUSTOM0.x);
}

void fragment() {
	float nutrient = fauna_unit(fauna_high_byte(fauna_data.g));
	float emergence = fauna_unit(fauna_low_byte(fauna_data.g));
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

	float retained = irradiance_field.r;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - fauna_world);
	float fresnel = pow(1.0 - clamp(abs(dot(normalize(fauna_normal), view_dir)),
			0.0, 1.0), 2.2);
	float cone_edge = smoothstep(0.015, 0.20, awake)
			* (1.0 - smoothstep(0.34, 0.78, awake));

	float procedural_wire = fauna_cloisonne_wire(fauna_local, pattern_jitter,
			family_motif);
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
	float jewel_mask = authored_jewel * vertex_channels_ready;

	vec3 wine = dream_irradiance_hue(mix(base_color,
			base_color * vec3(1.10, 0.86, 1.08), hue_jitter));
	float life = clamp(0.72 + nutrient * 0.16 + emergence * 0.12, 0.0, 1.0);
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
	float vein = pow(anatomy_line, mix(1.8, 0.72,
			clamp(irradiance_vein_branch * 0.65, 0.0, 1.0)));
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
	ALBEDO = dark_body + mix(lit_wine, full_body,
			max(irradiance.y * 0.58, irradiance.z));
}
