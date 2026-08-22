// ORISON SURFACE — the layered surface system (TASKS.md §MX, owner direction
// 2026-08-21: maximum perceived geometric complexity per polygon).
//
// One maintained surface for the whole material library. A material is a
// STACK, read bottom to top:
//
//   BASE      albedo · OpenGL normal · roughness (standalone R, glTF
//             metallicRoughness G, or packed ORM) · metallic · optional AO
//   PROJECTION mesh UV (the builder's world-box metres) or world triplanar
//             (the MatLib props), with the M-COVER anti-repetition modes
//             (hex / cell-snapped / rows) carried over verbatim from
//             floor_coverage.gdshader
//   HEIGHT    the set's height map, calibrated in MILLIMETRES of relief over
//             the set's tile in metres, as offset parallax or POM — with the
//             governor built in: it fades at grazing angles and with
//             distance, and `parallax_budget` lets the station's measured
//             cost turn it down (MX-2). Never in triplanar mode.
//   DETAIL    a second-frequency albedo/normal pair — dedicated maps, or the
//             set's own maps at 3.718x (self-detail) until MX-3 ships them
//   MASKS     first-class grayscale fields, each blending a secondary STATE
//             of the surface: damage (substrate shows), grime (settles in
//             cavities), moisture (darkens, polishes), wear (crests rub
//             bright), oxidation, gilding, corruption (the dream's flesh),
//             emission, translucency. A field is a texture channel
//             (mask_tex RGBA / mask2_tex RGBA in world metres) or, with no
//             texture, a procedural fbm of world position — so any surface
//             can be given a state with no new asset. Every field is
//             amount x smoothstep(threshold, threshold + softness, raw).
//   OPTIONAL  clearcoat, anisotropy, wrap-translucency (BACKLIGHT).
//
// Art direction is preserved by construction: the authored albedo is only
// ever multiplied or replaced by a state the mask asked for; nothing here
// regrades it. Every optional layer sits behind a uniform bool so an unused
// layer costs a uniform branch and no fetch.
//
// Two thin shaders compile this include:
//   orison_surface.gdshader          opaque (no alpha path at all)
//   orison_surface_cutout.gdshader   alpha scissor / hash for genuine cutouts
// The include defines uniforms, varyings and the work; the thin shaders own
// vertex() / fragment() and write the built-ins from the struct returned.

#include "res://shaders/dream_corruption_layers.gdshaderinc"

// --------------------------------------------------------------- projection
group_uniforms projection;
// 0 = mesh UV (glTF world-box metres / tile), 1 = world triplanar (props).
uniform int uv_mode : hint_range(0, 1) = 0;
// Triplanar: texture repeats per metre (= 1 / metres_per_tile).
uniform float uv_scale = 1.0;
uniform float triplanar_sharpness = 4.0;
// Metres of world per texture tile for the HEIGHT calibration (mesh UV mode:
// the set's metres_per_tile as baked; triplanar: 1 / uv_scale).
uniform float tile_m = 1.0;
group_uniforms;

// --------------------------------------------------------------------- base
group_uniforms base;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 0.35;
uniform bool has_normal_tex = true;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_rough_tex = true;
// 0 = roughness in R (ingest sets), 1 = glTF metallicRoughness (rough G,
// metal B), 2 = packed ORM (AO R, rough G, metal B).
uniform int rough_channel : hint_range(0, 2) = 0;
uniform float roughness_mul = 1.0;
uniform float metallic = 0.0;
// AO from the ORM map when packed; otherwise a cavity term from height.
uniform float cavity_ao : hint_range(0.0, 1.0) = 0.35;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

// ----------------------------------------------------------------- coverage
group_uniforms coverage;
// 0 PLAIN, 1 HEX, 2 CELL-SNAPPED hex, 3 ROWS — floor_coverage.gdshader's
// modes, same uniforms, so FloorCoveragePass's RULES carry over unchanged.
uniform int coverage : hint_range(0, 3) = 0;
uniform vec3 albedo_mean = vec3(0.5);
uniform float rough_mean = 0.5;
uniform float hex_scale = 1.0;
uniform float lattice_cells = 3.0;
uniform float rows_per_tile = 14.0;
uniform bool grain_along_u = true;
group_uniforms;

// ------------------------------------------------------------------- height
group_uniforms height;
uniform sampler2D height_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_height = false;
// Relief spanned by height 0..1, in millimetres. A mortar joint is ~10,
// a tile joint ~3, a floorboard seam ~1.5, plaster 0.
uniform float height_relief_mm = 0.0;
// The map's WORKING range (5th..95th percentile, measured by the pass): the
// ingest's band-passed heights sit around 0.5 and never reach 0 or 1, so
// the millimetres are mapped onto the range the map actually uses.
uniform vec2 height_range = vec2(0.0, 1.0);
// 0 off, 1 offset parallax (one extra fetch), 2 POM (marched).
uniform int parallax_mode : hint_range(0, 2) = 0;
uniform int pom_steps_min : hint_range(2, 16) = 6;
uniform int pom_steps_max : hint_range(4, 48) = 18;
// The governor. `parallax_budget` is set by the station's measured cost
// (1 = full relief, 0 = flat); grazing and distance fades are automatic.
uniform float parallax_budget : hint_range(0.0, 1.0) = 1.0;
uniform float parallax_grazing_cos : hint_range(0.0, 0.9) = 0.18;
uniform float parallax_fade_start_m = 5.0;
uniform float parallax_fade_end_m = 9.0;
group_uniforms;

// ------------------------------------------------------------------- detail
group_uniforms detail;
uniform bool has_detail = false;
// With no dedicated maps the base albedo/normal are re-read at detail_scale.
uniform bool detail_self = true;
uniform sampler2D detail_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_scale = 3.718;
uniform float detail_albedo_strength : hint_range(0.0, 1.0) = 0.25;
uniform float detail_normal_strength : hint_range(0.0, 2.0) = 0.5;
group_uniforms;

// ----------------------------------------------------------------- emission
group_uniforms emission;
uniform bool has_emission_tex = false;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
group_uniforms;

// ------------------------------------------------------------------- masks
group_uniforms masks;
// Field textures in world metres (box projection), RGBA = four fields.
// mask_tex:  R damage   G grime    B moisture    A wear
// mask2_tex: R oxidation G gilding B corruption  A emission
uniform bool has_mask_tex = false;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform bool has_mask2_tex = false;
uniform sampler2D mask2_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float mask_tile_m = 2.0;
// Procedural fields when no texture: fbm of world position at this scale.
uniform float mask_proc_scale = 1.3;
// Per field: amount (0 = state off), threshold on the raw field, softness.
uniform vec4 mask_amount = vec4(0.0);
uniform vec4 mask_threshold = vec4(0.55);
uniform vec4 mask_softness = vec4(0.15);
uniform vec4 mask2_amount = vec4(0.0);
uniform vec4 mask2_threshold = vec4(0.55);
uniform vec4 mask2_softness = vec4(0.15);
// Where the states may show, in world space: an xz rect (x0, z0, x1, z1)
// and a y range, soft-edged. A batched prop draw spans a storey; a case's
// states reach only the part of it inside the case's flat.
uniform vec4 state_rect = vec4(-1.0e5, -1.0e5, 1.0e5, 1.0e5);
uniform vec2 state_y = vec2(-1.0e5, 1.0e5);
uniform float state_edge_m = 0.15;
// 0 lit; 1 mask fields RGBA; 2 mask2 fields; 3 height; 4 cavity (R) / crest
// (G) / parallax fade (B).
uniform int debug_view : hint_range(0, 4) = 0;
group_uniforms;

// ------------------------------------------------------------------- states
group_uniforms states;
// damage: what shows where the surface is gone.
uniform vec3 substrate_color : source_color = vec3(0.42, 0.36, 0.30);
uniform float substrate_rough = 0.9;
uniform float damage_depth_mm = 4.0;
uniform float damage_edge_light = 0.18;
// grime: settles where the height is low.
uniform vec3 grime_color : source_color = vec3(0.38, 0.35, 0.31);
uniform float grime_rough = 0.92;
uniform float grime_in_cavities : hint_range(0.0, 1.0) = 0.7;
// moisture: darkens and polishes, fills the texture.
uniform float moisture_darken : hint_range(0.0, 1.0) = 0.45;
uniform float moisture_rough = 0.12;
// wear: crests rub bright and smooth.
uniform vec3 wear_color : source_color = vec3(1.10, 1.07, 1.02);
uniform float wear_rough = 0.30;
uniform float wear_on_crests : hint_range(0.0, 1.0) = 0.8;
// oxidation: for metals.
uniform vec3 oxide_color : source_color = vec3(0.26, 0.42, 0.36);
uniform float oxide_rough = 0.85;
// gilding: the dream's gold skin on the crests.
uniform vec3 gild_color : source_color = vec3(0.86, 0.66, 0.30);
uniform float gild_rough = 0.30;
uniform float gild_on_crests : hint_range(0.0, 1.0) = 0.6;
// corruption: the dream's flesh (dream_corruption_layers).
uniform vec3 flesh_deep : source_color = vec3(0.140, 0.030, 0.125);
uniform vec3 flesh_body : source_color = vec3(0.420, 0.085, 0.300);
uniform vec3 flesh_crest : source_color = vec3(0.620, 0.230, 0.470);
uniform float flesh_cell_scale = 3.2;
uniform float flesh_breath_hz = 0.07;
uniform float flesh_glow = 0.12;
// translucency (wrap), clearcoat, anisotropy.
uniform float translucency : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.3;
uniform float anisotropy : hint_range(-1.0, 1.0) = 0.0;
group_uniforms;

// -------------------------------------------------------------- encroachment
// WK-1 as a state of the one surface (was wall_encroachment.gdshader): a
// case's substance plates reach into the flat's wall finishes — the wicking
// plate rising from the skirting and the room's corners with leader lines
// ahead of its front, restoring torn plaster as a membrane; gilt along the
// torn survival edge once the case is well along; calm blanks late.
// `intensity` is the case's stage (ApartmentEncroachment), `unit_rect` clips
// the creep to the flat in world xz, `floor_y` is the storey's floor.
group_uniforms encroachment;
uniform bool has_encroachment = false;
uniform sampler2D plate_a_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_a_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_b_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_c_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_c_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float plate_tile_m = 1.6;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 unit_rect = vec4(-1.0, -1.0, 1.0, 1.0);
uniform float floor_y = 0.0;
uniform vec3 ink_tint : source_color = vec3(0.20, 0.19, 0.30);
uniform vec3 gilt_tint : source_color = vec3(0.86, 0.66, 0.30);
uniform float breath_hz = 0.05;
group_uniforms;

varying vec3 v_world;
varying vec3 v_wnormal;

struct OrisonSurface {
	vec3 albedo;
	float alpha;
	vec3 normal;        // view space, perturbed
	float rough;
	float metal;
	float ao;
	vec3 emission;
	vec3 backlight;
	float corruption;   // the corruption field, for cutout restore
	float damage;       // the damage field, for cutout tearing
	float membrane;     // the encroachment's restored surface, for the cutout
};

// ------------------------------------------------------------------ helpers
vec2 os_hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

void os_triangle_grid(vec2 uv, out float w1, out float w2, out float w3,
		out vec2 v1, out vec2 v2, out vec2 v3) {
	uv *= 3.4641016 * hex_scale;
	mat2 grid_to_skewed = mat2(vec2(1.0, 0.0), vec2(-0.57735027, 1.15470054));
	vec2 skewed = grid_to_skewed * uv;
	vec2 base = floor(skewed);
	vec3 t = vec3(fract(skewed), 0.0);
	t.z = 1.0 - t.x - t.y;
	if (t.z > 0.0) {
		w1 = t.z; w2 = t.y; w3 = t.x;
		v1 = base; v2 = base + vec2(0.0, 1.0); v3 = base + vec2(1.0, 0.0);
	} else {
		w1 = -t.z; w2 = 1.0 - t.y; w3 = 1.0 - t.x;
		v1 = base + vec2(1.0, 1.0); v2 = base + vec2(1.0, 0.0); v3 = base + vec2(0.0, 1.0);
	}
}

vec2 os_cell_offset(vec2 v, float steps) {
	vec2 o = os_hash22(v);
	if (steps > 0.5) {
		o = floor(o * steps) / steps;
	}
	return o;
}

vec4 os_hex_sample(sampler2D tex, vec2 uv, vec2 ddx, vec2 ddy, vec4 mean, float steps) {
	float w1; float w2; float w3; vec2 v1; vec2 v2; vec2 v3;
	os_triangle_grid(uv, w1, w2, w3, v1, v2, v3);
	vec4 c1 = textureGrad(tex, uv + os_cell_offset(v1, steps), ddx, ddy);
	vec4 c2 = textureGrad(tex, uv + os_cell_offset(v2, steps), ddx, ddy);
	vec4 c3 = textureGrad(tex, uv + os_cell_offset(v3, steps), ddx, ddy);
	vec4 g = w1 * (c1 - mean) + w2 * (c2 - mean) + w3 * (c3 - mean);
	g /= sqrt(w1 * w1 + w2 * w2 + w3 * w3);
	return clamp(mean + g, 0.0, 1.0);
}

// One covered read of a base map in mesh-UV mode.
vec4 os_covered(sampler2D tex, vec2 uv, vec2 ddx, vec2 ddy, vec4 mean) {
	if (coverage == 1 || coverage == 2) {
		float steps = (coverage == 2) ? lattice_cells : 0.0;
		return os_hex_sample(tex, uv, ddx, ddy, mean, steps);
	} else if (coverage == 3) {
		float row = floor((grain_along_u ? uv.y : uv.x) * rows_per_tile);
		float shift = os_hash22(vec2(row, 7.0)).x * 3.0;
		vec2 ruv = uv + (grain_along_u ? vec2(shift, 0.0) : vec2(0.0, shift));
		return textureGrad(tex, ruv, ddx, ddy);
	}
	return textureGrad(tex, uv, ddx, ddy);
}

// Triplanar read, Godot's own convention (uv1_triplanar) so the props look
// as they did, only layered.
vec4 os_tri(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.xy) * w.z + texture(tex, p.xz) * w.y
			+ texture(tex, p.zy * vec2(-1.0, 1.0)) * w.x;
}

vec2 os_box_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return p.zy;
	return p.xy;
}

float os_field_proc(vec3 p, float seed) {
	return dream_corruption_fbm3(p * mask_proc_scale + vec3(seed, seed * 1.7, seed * 0.3));
}

vec4 os_fields(vec4 raw, vec4 amount, vec4 threshold, vec4 softness) {
	return amount * smoothstep(threshold, threshold + max(softness, vec4(0.001)), raw);
}

// Tangent-space height read with the active projection.
float os_height_at(vec2 uv, vec2 ddx, vec2 ddy) {
	float h = textureGrad(height_tex, uv, ddx, ddy).r;
	return clamp((h - height_range.x) / max(0.02, height_range.y - height_range.x), 0.0, 1.0);
}

// Per-2 m-cell hashed offset so a 1.6 m plate does not repeat across a wall.
vec2 os_antitile(vec2 uv) {
	vec2 cell = floor(uv * 0.5);
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	return uv + vec2(h * 5.17, fract(h * 7.31) * 3.83);
}

// WK-1's grammar over the resolved surface. Returns the membrane (where the
// wick restores a torn finish); edits albedo / rough / metal / n_ts in place.
float os_encroach(inout vec3 albedo, inout float rough, inout float metal,
		inout vec3 n_ts, float finish_alpha, vec3 n, float time) {
	bool inside = v_world.x >= unit_rect.x && v_world.x <= unit_rect.z
			&& v_world.z >= unit_rect.y && v_world.z <= unit_rect.w;
	if (intensity <= 0.001 || !inside) {
		return 0.0;
	}
	vec2 puv = os_antitile(os_box_uv(v_world, n) / max(0.05, plate_tile_m));
	float height = max(0.0, v_world.y - floor_y);
	// Distance to the wall's own ENDS along its axis: the corners wick.
	float to_edge = abs(n.z) > 0.5
			? min(v_world.x - unit_rect.x, unit_rect.z - v_world.x)
			: min(v_world.z - unit_rect.y, unit_rect.w - v_world.z);
	float breath = 0.5 + 0.5 * sin(time * 6.2831853 * breath_hz + v_world.x * 0.4);
	float field = dream_corruption_fbm3(v_world * 3.4 + 7.0);
	float fine = dream_corruption_fbm3(v_world * 9.0 + 1.0);

	// plate_a: the wicking substance
	float rise = 1.0 - smoothstep(0.0, 0.35 + 1.25 * intensity, height);
	float corner = 1.0 - smoothstep(0.0, 0.35 + 0.95 * intensity, to_edge);
	float reach = max(rise, corner) * (0.50 + 0.50 * intensity);
	float wick_drive = reach * 0.60 + field * 0.50 + fine * 0.18 - 0.20 + 0.03 * breath;
	float wick = smoothstep(0.49, 0.56, wick_drive);
	float front_band = smoothstep(0.38, 0.50, wick_drive) * (1.0 - wick);
	float lines = dream_corruption_vessels(v_world * 2.6, 0.31, 0.96) * front_band
			* smoothstep(0.15, 0.45, intensity);
	vec3 ink = texture(plate_a_albedo, puv).rgb * ink_tint * 2.6;
	albedo = mix(albedo, ink, wick * 0.88);
	albedo = mix(albedo, ink_tint * 0.6, lines * 0.85);
	rough = mix(rough, 0.58, wick);
	vec2 ink_n = (texture(plate_a_normal, puv).rg * 2.0 - 1.0) * normal_scale;
	n_ts.xy = mix(n_ts.xy, ink_n, wick * 0.7);

	// plate_c: gilt along the torn edge of the survival mask
	float torn = smoothstep(0.30, 0.55, finish_alpha) * (1.0 - smoothstep(0.55, 0.85, finish_alpha));
	float gilt = torn * smoothstep(0.28, 0.55, intensity) * smoothstep(0.35, 0.6, field + 0.2 * intensity);
	albedo = mix(albedo, texture(plate_c_albedo, puv * 1.7).rgb * gilt_tint * 1.3, gilt);
	metal = mix(metal, 0.9, gilt);
	rough = mix(rough, 0.32, gilt);
	n_ts.xy = mix(n_ts.xy, (texture(plate_c_normal, puv * 1.7).rg * 2.0 - 1.0) * normal_scale, gilt * 0.6);

	// plate_b: the blank, spared
	float blank_drive = dream_corruption_fbm3(v_world * 1.6 + 19.0) * 0.7
			+ smoothstep(0.55, 1.0, intensity) * 0.22 - 0.62;
	float blank = smoothstep(0.04, 0.10, blank_drive) * smoothstep(0.55, 0.8, intensity);
	albedo = mix(albedo, texture(plate_b_albedo, puv * 0.8).rgb, blank);
	rough = mix(rough, 0.72, blank);
	n_ts.xy *= 1.0 - blank * 0.8;
	return wick;
}

// --------------------------------------------------------------------- work
OrisonSurface orison_surface(vec2 mesh_uv, vec3 vertex, vec3 normal, vec3 tangent,
		vec3 binormal, vec3 eye_offset, mat4 view_matrix, float time) {
	OrisonSurface s;
	vec3 wn = normalize(v_wnormal);

	// ---- world-space fields first; they do not depend on the UV ----------
	// A field is only evaluated when its state has an amount: an unused
	// state costs nothing, which is what lets every surface carry the slots.
	vec2 mask_uv = os_box_uv(v_world, wn) / max(0.05, mask_tile_m);
	vec4 f1 = vec4(0.0);
	vec4 f2 = vec4(0.0);
	float edge_m = max(0.001, state_edge_m);
	float state_clip = smoothstep(0.0, edge_m, v_world.x - state_rect.x)
			* smoothstep(0.0, edge_m, state_rect.z - v_world.x)
			* smoothstep(0.0, edge_m, v_world.z - state_rect.y)
			* smoothstep(0.0, edge_m, state_rect.w - v_world.z)
			* smoothstep(0.0, edge_m, v_world.y - state_y.x)
			* smoothstep(0.0, edge_m, state_y.y - v_world.y);
	bvec4 want1 = greaterThan(mask_amount, vec4(0.0));
	bvec4 want2 = greaterThan(mask2_amount, vec4(0.0));
	if (any(want1)) {
		vec4 raw1;
		if (has_mask_tex) {
			raw1 = texture(mask_tex, mask_uv);
		} else {
			// Damage breaks along a finer octave so its edge is ragged, not a blob.
			raw1 = vec4(want1.r ? os_field_proc(v_world, 3.0) * 0.72
							+ dream_corruption_fbm3(v_world * mask_proc_scale * 4.7 + 5.0) * 0.28 : 0.0,
					want1.g ? os_field_proc(v_world, 11.0) : 0.0,
					want1.b ? os_field_proc(v_world, 23.0) : 0.0,
					want1.a ? os_field_proc(v_world, 41.0) : 0.0);
		}
		f1 = os_fields(raw1, mask_amount, mask_threshold, mask_softness) * state_clip;
	}
	if (any(want2)) {
		vec4 raw2;
		if (has_mask2_tex) {
			raw2 = texture(mask2_tex, mask_uv);
		} else {
			raw2 = vec4(want2.r ? os_field_proc(v_world, 57.0) : 0.0,
					want2.g ? os_field_proc(v_world, 71.0) : 0.0,
					want2.b ? os_field_proc(v_world, 89.0) : 0.0,
					want2.a ? os_field_proc(v_world, 101.0) : 0.0);
		}
		f2 = os_fields(raw2, mask2_amount, mask2_threshold, mask2_softness) * state_clip;
	}
	float damage = f1.r;
	float grime = f1.g;
	float moisture = f1.b;
	float wear = f1.a;
	float oxide = f2.r;
	float gild = f2.g;
	float corrupt = f2.b;
	float emit_mask = f2.a;
	float fine = (want1.r || want2.r || want2.g)
			? dream_corruption_fbm3(v_world * 9.0 + 1.0) : 0.5;

	// ---- projection + height tier --------------------------------------
	vec2 uv = mesh_uv;
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec3 tri_p = vec3(0.0);
	vec3 tri_w = vec3(0.0);
	float parallax_fade = 0.0;
	float h = 0.5;
	if (uv_mode == 1) {
		tri_w = pow(abs(wn), vec3(triplanar_sharpness));
		tri_w /= dot(tri_w, vec3(1.0));
		tri_p = v_world * uv_scale * vec3(1.0, -1.0, 1.0);
		if (has_height) {
			h = os_tri(height_tex, tri_p, tri_w).r;
			h = clamp((h - height_range.x) / max(0.02, height_range.y - height_range.x), 0.0, 1.0);
		}
	} else {
		if (has_height && parallax_mode > 0 && height_relief_mm > 0.0) {
			vec3 view_dir = normalize(normalize(-vertex + eye_offset)
					* mat3(tangent, -binormal, normal));
			float graze = smoothstep(parallax_grazing_cos, parallax_grazing_cos + 0.22, abs(view_dir.z));
			float dist = 1.0 - smoothstep(parallax_fade_start_m, parallax_fade_end_m, length(vertex));
			parallax_fade = graze * dist * parallax_budget;
			// Damage deepens the surface by a constant along the ray.
			float relief_uv = (height_relief_mm * 0.001 / max(0.02, tile_m)) * parallax_fade;
			float extra = damage * damage_depth_mm / max(0.1, height_relief_mm);
			if (parallax_mode == 1 || parallax_fade < 0.02) {
				float depth = 1.0 - os_height_at(uv, ddx, ddy) + extra;
				uv -= view_dir.xy * depth * relief_uv;
			} else {
				float num_layers = mix(float(pom_steps_max), float(pom_steps_min), abs(view_dir.z));
				float layer_depth = 1.0 / num_layers;
				float current_layer_depth = 0.0;
				vec2 delta = view_dir.xy * relief_uv / num_layers;
				vec2 ofs = uv;
				float depth = 1.0 - os_height_at(ofs, ddx, ddy) + extra;
				float current_depth = 0.0;
				for (int i = 0; i < 48; i++) {
					if (current_depth >= depth) {
						break;
					}
					ofs -= delta;
					depth = 1.0 - os_height_at(ofs, ddx, ddy) + extra;
					current_depth += layer_depth;
				}
				vec2 prev = ofs + delta;
				float after = depth - current_depth;
				float before = 1.0 - os_height_at(prev, ddx, ddy) + extra - current_depth + layer_depth;
				float weight = after / max(0.0001, after - before);
				uv = mix(ofs, prev, clamp(weight, 0.0, 1.0));
			}
		}
		if (has_height) {
			h = os_height_at(uv, ddx, ddy);
		}
	}
	float cavity = smoothstep(0.0, 0.6, h);       // 0 in the joints, 1 on the face
	float crest = smoothstep(0.55, 1.0, h);       // 1 on the high points

	// ---- base reads ------------------------------------------------------
	vec4 alb;
	vec4 nrm = vec4(0.5, 0.5, 1.0, 1.0);
	vec4 rgh = vec4(1.0);
	if (uv_mode == 1) {
		alb = os_tri(albedo_tex, tri_p, tri_w);
		if (has_normal_tex) {
			nrm = os_tri(normal_tex, tri_p, tri_w);
		}
		if (has_rough_tex) {
			rgh = os_tri(rough_tex, tri_p, tri_w);
		}
	} else {
		alb = os_covered(albedo_tex, uv, ddx, ddy, vec4(albedo_mean, 1.0));
		if (has_normal_tex) {
			nrm = os_covered(normal_tex, uv, ddx, ddy, vec4(0.5, 0.5, 1.0, 1.0));
		}
		if (has_rough_tex) {
			rgh = os_covered(rough_tex, uv, ddx, ddy, vec4(rough_mean));
		}
	}
	vec3 albedo = alb.rgb * albedo_color.rgb;
	float alpha = alb.a * albedo_color.a;
	float rough = 1.0;
	float metal = metallic;
	float ao = 1.0;
	if (has_rough_tex) {
		if (rough_channel == 0) {
			rough = rgh.r;
		} else {
			rough = rgh.g;
			if (rough_channel == 2) {
				ao = rgh.r;
				metal = rgh.b * metallic;
			}
		}
	}
	rough *= roughness_mul;
	if (rough_channel != 2 && has_height) {
		ao = mix(1.0, cavity, cavity_ao);
	}
	vec3 n_ts = has_normal_tex ? nrm.rgb * 2.0 - 1.0 : vec3(0.0, 0.0, 1.0);
	n_ts.xy *= normal_scale;
	// Normal-map z is recovered after every layer has pushed xy.

	// ---- detail tier -----------------------------------------------------
	if (has_detail) {
		vec4 d_alb;
		vec4 d_nrm;
		if (uv_mode == 1) {
			vec3 dp = tri_p * detail_scale;
			d_alb = detail_self ? os_tri(albedo_tex, dp, tri_w) : os_tri(detail_albedo, dp, tri_w);
			d_nrm = detail_self ? os_tri(normal_tex, dp, tri_w) : os_tri(detail_normal, dp, tri_w);
		} else {
			vec2 duv = uv * detail_scale;
			d_alb = detail_self ? texture(albedo_tex, duv) : texture(detail_albedo, duv);
			d_nrm = detail_self ? texture(normal_tex, duv) : texture(detail_normal, duv);
		}
		// Linear-light overlay around the detail's own mean keeps the base
		// colour; the detail only modulates.
		vec3 d_mean = detail_self ? albedo_mean : vec3(0.5);
		albedo *= clamp(1.0 + (d_alb.rgb - d_mean) * 2.0 * detail_albedo_strength, 0.3, 1.7);
		n_ts.xy += (d_nrm.xy * 2.0 - 1.0) * detail_normal_strength * normal_scale;
	}

	// ---- states, in the order the building acquires them ------------------
	// wear: crests rub bright and smooth
	float w = wear * mix(1.0, crest, wear_on_crests);
	albedo = mix(albedo, albedo * wear_color, w);
	rough = mix(rough, wear_rough, w);
	n_ts.xy *= 1.0 - 0.6 * w;
	// grime: settles in the cavities
	float g = grime * mix(1.0, 1.0 - cavity, grime_in_cavities);
	albedo = mix(albedo, albedo * grime_color, g);
	rough = mix(rough, max(rough, grime_rough), g);
	// oxidation: metal to oxide
	float o = oxide * (0.85 + 0.3 * fine);
	albedo = mix(albedo, oxide_color * (0.8 + 0.4 * fine), clamp(o, 0.0, 1.0));
	metal = mix(metal, 0.0, oxide);
	rough = mix(rough, oxide_rough, oxide);
	// moisture: darkens, polishes, fills the texture
	albedo *= 1.0 - moisture_darken * moisture;
	rough = mix(rough, moisture_rough, moisture);
	n_ts.xy *= 1.0 - 0.5 * moisture;
	// damage: the substrate shows, with a chipped lighter rim
	float rim = smoothstep(0.0, 0.5, damage) * (1.0 - smoothstep(0.5, 1.0, damage));
	albedo = mix(albedo, substrate_color * (0.85 + 0.3 * fine), damage);
	albedo += rim * damage_edge_light;
	rough = mix(rough, substrate_rough, damage);
	metal = mix(metal, 0.0, damage);
	n_ts.xy *= 1.0 - 0.7 * damage;
	ao *= 1.0 - 0.35 * damage;
	// gilding: gold leaf on the crests
	float gi = gild * mix(1.0, crest, gild_on_crests);
	albedo = mix(albedo, gild_color * (0.9 + 0.2 * fine), gi);
	metal = mix(metal, 1.0, gi);
	rough = mix(rough, gild_rough, gi);
	// corruption: the dream's flesh grows over everything above
	vec3 flesh = vec3(0.0);
	if (corrupt > 0.001) {
		float cells = dream_corruption_cells(v_world * flesh_cell_scale, time, corrupt);
		float vessels = dream_corruption_vessels(v_world * 2.6, corrupt, 0.96);
		float wet = dream_corruption_wetfilm(v_world, time, corrupt);
		float breath = 0.5 + 0.5 * sin(time * 6.2831853 * flesh_breath_hz + v_world.y * 0.7);
		flesh = mix(flesh_deep, flesh_body, cells);
		flesh = mix(flesh, flesh_crest, vessels * 0.8);
		albedo = mix(albedo, flesh, corrupt);
		rough = mix(rough, mix(0.55, 0.18, wet), corrupt);
		metal = mix(metal, 0.0, corrupt);
		n_ts.xy = mix(n_ts.xy, (vec2(cells, vessels) - 0.5) * 0.6, corrupt);
		s.emission = flesh_crest * flesh_glow * corrupt * (0.6 + 0.4 * breath) * vessels;
	} else {
		s.emission = vec3(0.0);
	}
	// emission
	vec3 e = emission_color * emission_energy;
	if (has_emission_tex) {
		e *= texture(emission_tex, uv_mode == 1 ? tri_p.xz : uv).rgb;
	}
	if (mask2_amount.a > 0.0) {
		e *= emit_mask;
	}
	s.emission += e;

	// ---- the encroachment, over everything above (WK-1 as a state) ---------
	float membrane = 0.0;
	if (has_encroachment) {
		membrane = os_encroach(albedo, rough, metal, n_ts, alpha, wn, time);
	}

	// ---- resolve -----------------------------------------------------------
	n_ts.z = sqrt(max(0.0, 1.0 - dot(n_ts.xy, n_ts.xy)));
	s.normal = normalize(tangent * n_ts.x + binormal * n_ts.y + normal * n_ts.z);
	s.albedo = albedo;
	s.alpha = alpha;
	s.rough = clamp(rough, 0.0, 1.0);
	s.metal = clamp(metal, 0.0, 1.0);
	s.ao = clamp(ao, 0.0, 1.0);
	s.backlight = albedo * translucency * (1.0 - g);
	s.corruption = corrupt;
	s.damage = damage;
	s.membrane = membrane;

	if (debug_view == 1) {
		s.albedo = f1.rgb; s.emission = f1.rgb; s.rough = 1.0; s.metal = 0.0;
	} else if (debug_view == 2) {
		s.albedo = f2.rgb; s.emission = f2.rgb; s.rough = 1.0; s.metal = 0.0;
	} else if (debug_view == 3) {
		s.albedo = vec3(h); s.emission = vec3(h); s.rough = 1.0; s.metal = 0.0;
	} else if (debug_view == 4) {
		s.albedo = vec3(cavity, crest, parallax_fade); s.emission = s.albedo; s.rough = 1.0; s.metal = 0.0;
	}
	return s;
}
