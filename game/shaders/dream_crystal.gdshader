shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// THE CRYSTAL ORGAN (DIRECTION_2 §B5–B6, DIRECTION_3 §G) — halfway between
// skeleton, sensory organ, gemstone and machine. It reads as
//   deep tissue → mineral root → gold socket → crystal growth,
// never as a gem glued to an animal.
//
// Depth WITHOUT transparency (§B6): a faceted outer shell with strong
// Fresnel and sharp specular, and — through it — an interior found by
// marching the view ray in local space: fracture planes, inclusions, and a
// core that occasionally carries a pulse of light. The occasional
// astonishing glint is angle-gated, not continuous (§G).
#include "res://shaders/dream_corruption_layers.gdshaderinc"

uniform vec3 body_tint : source_color = vec3(0.28, 0.12, 0.34);
uniform vec3 deep_tint : source_color = vec3(0.10, 0.03, 0.14);
uniform vec3 core_color : source_color = vec3(1.0, 0.66, 0.26);
uniform vec3 gold : source_color = vec3(0.90, 0.70, 0.32);
uniform float attention : hint_range(0.0, 1.0) = 0.3;
uniform float excitation : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_phase : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform bool debug_gray = false;

varying vec3 v_local;
varying vec3 v_view_local;
varying vec3 v_world;
varying float v_root;

void vertex() {
	v_local = VERTEX;
	// The root end (y < 0) is buried in the gold socket and the flesh.
	v_root = smoothstep(0.15, -0.35, VERTEX.y);
	vec3 cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	v_view_local = normalize(VERTEX - cam_local);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Fracture planes: a few flat discontinuities at fixed angles, the way a
// mineral actually cleaves — not noise.
float dc_fracture(vec3 p, float seed_v) {
	float f = 0.0;
	f = max(f, 1.0 - smoothstep(0.0, 0.035, abs(dot(p, normalize(vec3(0.4, 0.8, 0.2))) - 0.12)));
	f = max(f, 1.0 - smoothstep(0.0, 0.028, abs(dot(p, normalize(vec3(-0.7, 0.3, 0.6))) + 0.05)));
	f = max(f, 1.0 - smoothstep(0.0, 0.022, abs(dot(p, normalize(vec3(0.2, -0.5, 0.85))) - 0.22)));
	return f * (0.6 + 0.4 * dream_corruption_fbm3(p * 9.0 + seed_v));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float ndv = clamp(dot(n, view_dir), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 4.0);
	// ---- the interior, marched in local space --------------------------
	vec3 ro = v_local;
	vec3 rd = v_view_local;
	vec3 inner = vec3(0.0);
	float depth_seen = 0.0;
	for (int i = 1; i <= 6; i++) {
		float t = float(i) * 0.13;
		vec3 p = ro + rd * t;
		if (dot(p, p) > 1.3) {
			break;
		}
		float fr = dc_fracture(p, seed);
		// Inclusions: sparse bright grains suspended in the body.
		float inc = smoothstep(0.86, 0.96, dream_corruption_cells(p * 11.0, 0.0, seed + 3.0));
		// The core, and the pulse that occasionally runs through it.
		float core = smoothstep(0.42, 0.0, length(p));
		float run = pow(0.5 + 0.5 * sin(pulse_phase * 6.2831853 - length(p) * 9.0), 8.0);
		float w = 1.0 / (1.0 + float(i) * 0.9);
		inner += (mix(deep_tint, body_tint, fr) * fr * 0.8
				+ gold * inc * 0.9
				+ core_color * core * (0.10 + 0.55 * run) * (0.35 + 0.65 * excitation)) * w;
		depth_seen += fr * w;
	}
	// ---- the shell -------------------------------------------------------
	vec3 albedo = mix(deep_tint, body_tint, 0.35 + 0.35 * depth_seen);
	albedo += inner * 0.75;
	// Buried in the socket: dark, rough, no glint.
	albedo = mix(albedo, deep_tint * 0.5, v_root);
	float rough = mix(0.06, 0.55, v_root);
	// The astonishing glint (§G): only when the view, the facet and a light
	// happen to line up — narrow, rare, and very bright when it happens.
	vec3 fl = normalize(vec3(0.3, 0.7, 0.6));
	float align = pow(clamp(dot(reflect(-view_dir, n), fl), 0.0, 1.0), 220.0);
	vec3 emission = core_color * align * 3.5 * (1.0 - v_root)
			+ inner * 0.35 * (0.4 + 0.6 * excitation);
	ALBEDO = albedo;
	METALLIC = mix(0.25, 0.05, v_root);
	ROUGHNESS = rough;
	SPECULAR = 0.95;
	EMISSION = emission;
	// Fresnel does the rest of the "glass" without ever going transparent.
	RIM = fres * 0.6;
	RIM_TINT = 0.4;
	AO = 1.0 - v_root * 0.55;
	AO_LIGHT_AFFECT = 0.4;
	if (debug_gray) {
		ALBEDO = vec3(0.6);
		METALLIC = 0.0;
		ROUGHNESS = 0.35;
		EMISSION = vec3(0.0);
		RIM = 0.0;
	}
}
