shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
// ORBITAL CILIA (DIRECTION_2 §D, DIRECTION_3 §J) — not eyelashes. A sensory
// organ occupying the ecological niche of eyelashes, in three anatomical
// classes carried by one MultiMesh:
//
//   0 FLESH filament — dark violet, flexible, extremely thin, a subtle wet
//     highlight; behaves like a whisker.
//   1 GOLD filament — fine metal tapering from a mineral follicle, like a
//     living clock spring; anisotropic along its length.
//   2 CRYSTAL cilium — a sparse faceted needle ending in a lens bulb, a
//     gold bead or a forked tip.
//
// INSTANCE_CUSTOM: (kind, length_scale, phase, thickness). The mesh is a
// tapered tube along +y from a follicle at y = 0.
#include "res://shaders/dream_corruption_layers.gdshaderinc"

uniform vec3 flesh_dark : source_color = vec3(0.115, 0.030, 0.105);
uniform vec3 flesh_lit : source_color = vec3(0.330, 0.095, 0.240);
uniform vec3 gold : source_color = vec3(0.90, 0.70, 0.32);
uniform vec3 crystal_tint : source_color = vec3(0.62, 0.42, 0.72);
uniform vec3 crystal_core : source_color = vec3(1.0, 0.72, 0.30);
uniform float attention : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 0.0;
uniform bool debug_gray = false;

varying vec2 v_uv;
varying float v_kind;
varying float v_phase;
varying vec3 v_world;

void vertex() {
	v_uv = UV;
	v_kind = INSTANCE_CUSTOM.x;
	v_phase = INSTANCE_CUSTOM.z;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = v_uv.y;
	int kind = int(v_kind + 0.5);
	vec3 albedo = flesh_dark;
	float rough = 0.5;
	float metal = 0.0;
	float aniso = 0.0;
	vec3 emission = vec3(0.0);
	float clear = 0.0;
	if (kind == 0) {
		// Flesh filament: dark at the follicle, warmer where it thins, with
		// a wet highlight that runs the length rather than sitting on it.
		albedo = mix(flesh_dark, flesh_lit, along * 0.7);
		rough = mix(0.42, 0.24, along);
		clear = 0.55;
	} else if (kind == 1) {
		// Gold filament: metal drawn out of a mineral follicle. Slightly
		// darker where it leaves the flesh, brighter along the free length.
		albedo = gold * (0.62 + 0.42 * along);
		metal = 1.0;
		rough = mix(0.40, 0.16, along);
		aniso = 0.7;
		// Where the follicle is, the metal is still becoming metal.
		albedo = mix(albedo * 0.5, albedo, smoothstep(0.0, 0.25, along));
	} else {
		// Crystal cilium: a faceted needle. Its body stays dark; its facets
		// and its terminal bulb do the work.
		float facet = dream_corruption_cells(vec3(v_uv * vec2(6.0, 30.0), seed + v_phase), 0.0, 0.3);
		albedo = crystal_tint * (0.30 + 0.55 * smoothstep(0.4, 0.85, facet));
		rough = mix(0.30, 0.05, smoothstep(0.35, 0.8, facet));
		metal = 0.25;
		// The terminal bulb: a tiny lens with a light in it.
		float bulb = smoothstep(0.86, 0.97, along);
		albedo = mix(albedo, crystal_tint * 1.5, bulb);
		emission += crystal_core * bulb * (0.25 + 0.75 * attention)
				* (0.6 + 0.4 * sin(TIME * 1.7 + v_phase * 6.283));
		clear = 0.8;
	}
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.7;
	ANISOTROPY = aniso;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	EMISSION = emission;
	CLEARCOAT = clear;
	CLEARCOAT_ROUGHNESS = 0.08;
	// The follicle end is in shadow: it is in a pit in the flesh.
	AO = mix(0.45, 1.0, smoothstep(0.0, 0.2, along));
	AO_LIGHT_AFFECT = 0.5;
	if (debug_gray) {
		ALBEDO = vec3(0.5);
		METALLIC = 0.0;
		ROUGHNESS = 0.5;
		EMISSION = vec3(0.0);
		ANISOTROPY = 0.0;
		CLEARCOAT = 0.0;
	}
}
