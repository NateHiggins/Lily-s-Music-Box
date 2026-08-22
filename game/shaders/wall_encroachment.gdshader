// SUPERSEDED 2026-08-22: the encroachment is now a STATE of the one layered
// surface (orison_surface.gdshaderinc, `encroachment` group, os_encroach) and
// ApartmentEncroachment builds its finishes through SurfacePass.surface_for.
// This file is kept as the reference of the WK-1 grammar; nothing binds it.
shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/dream_corruption_layers.gdshaderinc"

// WALL ENCROACHMENT — the dream's plates reaching into a case's waking flat
// (design/DREAM_ENCROACHMENT_BRIEF.md, decision 3; WK-1 is Mina's 2A).
//
// This replaces a baked wall-finish quad's StandardMaterial3D with the SAME
// finish — albedo with the century's survival mask in alpha, relief normal,
// roughness — plus a creep of the case's substance plates, masked in world
// space and clipped to the unit's own footprint, driven by `intensity` from
// the case's state. Nothing outside the unit rect changes; at intensity 0
// the result is the shipping finish.
//
// The creep grammar is the resident's material language (SIX_INCARNATIONS):
//   plate_a  the wicking substance (Mina: ink fibre) rising from skirting and
//            corners, dried to blue-black, with thin leader lines near its
//            front that stop short of the plaster they have not reached;
//   plate_c  the gilt (Mina: gilt edge) along the torn edge of the survival
//            mask — where the plaster already failed, the dream gilds it;
//   plate_b  the blank (Mina: erased stock): calm pale islands at the late
//            stage where something was deliberately spared.
// All three are static plates; motion is a sub-0.1 Hz breath in the front
// only. No flashing, no screen-space anything.

uniform sampler2D finish_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D finish_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D finish_rough : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float finish_normal_scale = 0.42;
uniform float alpha_cutoff = 0.5;

uniform sampler2D plate_a_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_a_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_b_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_c_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_c_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float plate_tile_m = 1.6;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Unit footprint in world metres: x0, z0, x1, z1 (Godot axes).
uniform vec4 unit_rect = vec4(-1.0, -1.0, 1.0, 1.0);
uniform float floor_y = 0.0;
uniform vec3 ink_tint : source_color = vec3(0.20, 0.19, 0.30);
uniform vec3 gilt_tint : source_color = vec3(0.86, 0.66, 0.30);
uniform float breath_hz = 0.05;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 box_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return p.zy;
	return p.xy;
}

// Per-2 m-cell hashed offset so a 1.6 m plate does not repeat across a wall.
vec2 antitile(vec2 uv) {
	vec2 cell = floor(uv * 0.5);
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	return uv + vec2(h * 5.17, fract(h * 7.31) * 3.83);
}

void fragment() {
	vec4 finish = texture(finish_albedo, UV);
	// Where the century stripped the plaster the quad discards; the wicking
	// substance grows a membrane back over the bare brick, so it can restore
	// the surface as it advances.
	float membrane = 0.0;
	vec3 albedo = finish.rgb;
	// glTF packs roughness in G of the metallic-roughness map.
	float rough = texture(finish_rough, UV).g;
	vec3 n_ts = texture(finish_normal, UV).rgb;
	float metal = 0.0;

	vec3 n = normalize(v_normal);
	bool inside = v_world.x >= unit_rect.x && v_world.x <= unit_rect.z
			&& v_world.z >= unit_rect.y && v_world.z <= unit_rect.w;
	if (intensity > 0.001 && inside) {
		vec2 puv = antitile(box_uv(v_world, n) / max(0.05, plate_tile_m));
		float height = max(0.0, v_world.y - floor_y);
		// Distance to the wall's own ENDS, measured along the wall's axis: the
		// corners of the room wick. (Measured to any rect edge it was zero all
		// along a perimeter wall, which sits on an edge, and the ink climbed
		// everywhere.)
		float to_edge = abs(n.z) > 0.5
				? min(v_world.x - unit_rect.x, unit_rect.z - v_world.x)
				: min(v_world.z - unit_rect.y, unit_rect.w - v_world.z);
		float breath = 0.5 + 0.5 * sin(TIME * 6.2831853 * breath_hz + v_world.x * 0.4);
		float field = dream_corruption_fbm3(v_world * 3.4 + 7.0);
		float fine = dream_corruption_fbm3(v_world * 9.0 + 1.0);

		// ---- plate_a: the wicking substance ---------------------------------
		float rise = 1.0 - smoothstep(0.0, 0.35 + 1.25 * intensity, height);
		float corner = 1.0 - smoothstep(0.0, 0.35 + 0.95 * intensity, to_edge);
		float reach = max(rise, corner) * (0.50 + 0.50 * intensity);
		float wick_drive = reach * 0.60 + field * 0.50 + fine * 0.18 - 0.20 + 0.03 * breath;
		float wick = smoothstep(0.49, 0.56, wick_drive);
		membrane = wick;
		// Leader lines in the band just ahead of the front, stopping short.
		float front_band = smoothstep(0.38, 0.50, wick_drive) * (1.0 - wick);
		float lines = dream_corruption_vessels(v_world * 2.6, 0.31, 0.96) * front_band
				* smoothstep(0.15, 0.45, intensity);
		vec3 ink_plate = texture(plate_a_albedo, puv).rgb;
		vec3 ink = ink_plate * ink_tint * 2.6;
		albedo = mix(albedo, ink, wick * 0.88);
		albedo = mix(albedo, ink_tint * 0.6, lines * 0.85);
		rough = mix(rough, 0.58, wick);
		vec3 ink_n = texture(plate_a_normal, puv).rgb;
		n_ts = mix(n_ts, ink_n, wick * 0.7);

		// ---- plate_c: gilt along the torn edge of the survival mask --------
		float torn = smoothstep(0.30, 0.55, finish.a) * (1.0 - smoothstep(0.55, 0.85, finish.a));
		float gilt = torn * smoothstep(0.28, 0.55, intensity) * smoothstep(0.35, 0.6, field + 0.2 * intensity);
		vec3 gilt_plate = texture(plate_c_albedo, puv * 1.7).rgb;
		albedo = mix(albedo, gilt_plate * gilt_tint * 1.3, gilt);
		metal = mix(metal, 0.9, gilt);
		rough = mix(rough, 0.32, gilt);
		n_ts = mix(n_ts, texture(plate_c_normal, puv * 1.7).rgb, gilt * 0.6);

		// ---- plate_b: the blank, spared ------------------------------------
		float blank_drive = dream_corruption_fbm3(v_world * 1.6 + 19.0) * 0.7
				+ smoothstep(0.55, 1.0, intensity) * 0.22 - 0.62;
		float blank = smoothstep(0.04, 0.10, blank_drive) * smoothstep(0.55, 0.8, intensity);
		vec3 blank_plate = texture(plate_b_albedo, puv * 0.8).rgb;
		albedo = mix(albedo, blank_plate, blank);
		rough = mix(rough, 0.72, blank);
		n_ts = mix(n_ts, vec3(0.5, 0.5, 1.0), blank * 0.8);
	}

	ALPHA = max(finish.a, membrane);
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	NORMAL_MAP = n_ts;
	NORMAL_MAP_DEPTH = finish_normal_scale;
}
