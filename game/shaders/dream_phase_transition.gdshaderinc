// One durable corruption continuum shared by the Orison skin and the body
// beneath it.  The caller supplies the accumulated exposure-field value; the
// live lamp cone is deliberately absent from this vocabulary.
//
// x: infection / architectural conversion
// y: rupture / breach reveal
// z: living-gold transmutation
// w: bounded local distortion strength

#ifndef DREAM_PHASE_TRANSITION
#define DREAM_PHASE_TRANSITION

vec4 dream_phase_state(float drive, vec4 stage_thresholds,
		vec2 gold_thresholds) {
	float ruled_drive = clamp(drive, 0.0, 1.0);
	float infection = smoothstep(stage_thresholds.x, stage_thresholds.y,
			ruled_drive);
	float rupture = smoothstep(stage_thresholds.z, stage_thresholds.w,
			ruled_drive);
	float living_gold = smoothstep(gold_thresholds.x, gold_thresholds.y,
			ruled_drive);
	// Distortion cannot lead the wound.  Once the rupture exists it deepens
	// slowly with the same gold phase and never becomes a screen-space effect.
	float local_warp = rupture * mix(0.42, 1.0, living_gold);
	return vec4(infection, rupture, living_gold, local_warp);
}


float dream_phase_hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


// Stable ordered material reveal.  The aperture opens from its centre and
// reaches torn plaster, lath and rubble last; small world-space variation
// breaks the contour without temporal glitter.  Geometry is always submitted.
float dream_phase_reveal_threshold(vec2 local_uv, vec3 world_pos,
		float seed) {
	float radial = length(local_uv * vec2(0.80, 1.0));
	float fracture = 0.5 + 0.5 * sin(atan(local_uv.y, local_uv.x) * 7.0
			+ seed * 31.0 + radial * 9.0);
	float grain = dream_phase_hash21(floor(world_pos.xz * 22.0)
			+ floor(world_pos.yy * 13.0) + seed * 47.0);
	return clamp(0.045 + radial * 0.69 + fracture * 0.13 + grain * 0.08,
			0.045, 0.985);
}


// A spatial, aperture-local rotational field.  Its support falls to zero at
// the authored tear and its maximum displacement is supplied in UV units by
// the caller.  The 70-second breathing period avoids flicker and camera sway.
vec2 dream_phase_bounded_warp(vec2 local_uv, float amount, float max_uv,
		float seed, float time_s) {
	float radius = length(local_uv);
	float support = 1.0 - smoothstep(0.28, 1.12, radius);
	float breath = 0.72 + 0.28 * sin(time_s * 0.089 + seed * 6.28318530718);
	float turn = amount * support * breath * max_uv
			* (0.72 + 0.28 * sin(radius * 13.0 + seed * 19.0));
	float c = cos(turn);
	float s = sin(turn);
	vec2 rotated = vec2(c * local_uv.x - s * local_uv.y,
			s * local_uv.x + c * local_uv.y);
	vec2 shear = vec2(sin(local_uv.y * 8.0 + seed * 11.0),
			cos(local_uv.x * 7.0 - seed * 13.0)) * max_uv * 0.18;
	return local_uv + (rotated - local_uv) + shear * amount * support;
}

#endif
