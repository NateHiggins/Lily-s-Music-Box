shader_type fog;
#include "res://shaders/lamp_optical_sample.gdshaderinc"

uniform float density_gain : hint_range(0.0, 0.25) = 0.055;
uniform float grime : hint_range(0.0, 1.0) = 0.28;
uniform float smoke : hint_range(0.0, 1.0) = 0.08;
uniform float optical_time = 0.0;
uniform float lamp_output : hint_range(0.0, 1.2) = 1.0;
uniform float detail_octaves : hint_range(1.0, 2.0) = 2.0;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void fog() {
	vec3 p = WORLD_POSITION;
	LampOpticalSample optical = sample_lamp_optics(WORLD_POSITION);
	// Reject empty froxels before procedural noise evaluations.
	// This is an exact zero-density path, not a reduced detail/quality tier.
	float occupancy = optical.visibility * smoothstep(0.0, 0.004, optical.scattering)
		* step(0.000001, dot(optical.radiance, vec3(0.333333)));
	if (occupancy <= 0.0 || lamp_output <= 0.0 || SDF >= 0.0) {
		DENSITY = 0.0;
		ALBEDO = vec3(0.94, 0.92, 0.88);
		EMISSION = vec3(0.0);
	} else {
		float along = clamp(optical.beam_depth / 6.5, 0.0, 1.0);
		// SDF is negative inside the real cone. Fade its outer 18 cm rather than
		// drawing a second transparent cone mesh.
		float edge = 1.0 - smoothstep(-0.18, 0.0, SDF);
		vec3 convected = p * vec3(1.4, 2.2, 1.1)
			+ vec3(0.0, optical_time * 0.075, optical_time * 0.025);
		float dust = value_noise(convected) * 0.58;
		if (detail_octaves > 1.5) {
			dust += value_noise(convected * 2.07 + 9.0) * 0.22;
		}
		float lens_grime = value_noise(vec3(UVW.xz * 8.0, 2.4)) * grime;
		float convection = smoothstep(0.25, 0.9,
			value_noise(convected * vec3(0.7, 1.8, 0.7)));
		float bounded = edge * smoothstep(0.01, 0.10, along)
			* (1.0 - smoothstep(0.84, 1.0, along));
		DENSITY = density_gain * lamp_output * bounded
			* (0.34 + dust + lens_grime * (1.0 - along) + smoke * convection);
		// Shared instantaneous field bounds participating air. Native spotlight
		// shadow injection supplies scene-mesh occlusion in the engine froxels;
		// do not substitute eight analytic lab boxes for the composed building.
		DENSITY *= occupancy;
		// The lamp already supplies its thermal spectrum. Nearly neutral dust
		// avoids tinting that warm light orange a second time.
		ALBEDO = vec3(0.94, 0.92, 0.88);
		EMISSION = vec3(0.0);
	}
}
