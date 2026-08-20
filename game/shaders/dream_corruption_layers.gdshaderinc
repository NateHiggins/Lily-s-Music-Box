// Reusable material vocabulary for the Tenant's visible anatomy.
//
// These functions deliberately return masks and material terms rather than a
// finished colour.  Hazard growth and later breach/phase materials can share
// the same tissue, wet-film and living-gold grammar without sharing one giant
// fragment() implementation or paying another submitted surface.

#ifndef DREAM_CORRUPTION_LAYERS
#define DREAM_CORRUPTION_LAYERS

float dream_corruption_hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


float dream_corruption_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = dream_corruption_hash31(i);
	float n100 = dream_corruption_hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = dream_corruption_hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = dream_corruption_hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = dream_corruption_hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = dream_corruption_hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = dream_corruption_hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = dream_corruption_hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}


float dream_corruption_fbm3(vec3 p) {
	float value = dream_corruption_noise3(p) * 0.57;
	value += dream_corruption_noise3(p * 2.03 + 7.13) * 0.29;
	value += dream_corruption_noise3(p * 4.11 - 3.71) * 0.14;
	return value;
}


// Broad connected cells.  The slow domain travel makes pressure pass through
// the body without making the texture slide across it like projected video.
float dream_corruption_cells(vec3 p, float time_s, float phase) {
	vec3 drift = vec3(time_s * 0.011, -time_s * 0.007,
			time_s * 0.009);
	float domain = dream_corruption_fbm3(p * 0.72 + drift + phase * 5.7);
	float membrane = sin((domain + p.y * 0.085) * 12.56637061436);
	return smoothstep(-0.62, 0.78, membrane);
}


// Long tendon folds: directional enough to describe growth, irregular enough
// not to read as stripes.  The returned ridge is strongest at a fold crest.
float dream_corruption_folds(vec3 p, float time_s, float phase) {
	float warp = dream_corruption_fbm3(p * 0.47
			+ vec3(phase * 4.1, time_s * 0.006, -phase * 2.7));
	float bands = sin(p.y * 3.8 + p.x * 1.25 - p.z * 1.55
			+ warp * 8.0 + time_s * 0.12 + phase * 6.28318530718);
	return pow(clamp(1.0 - abs(bands), 0.0, 1.0), 2.4);
}


// A connected three-direction vessel field.  Gold occupies these narrow
// stress lines; the body between them remains plum tissue.
float dream_corruption_vessels(vec3 p, float phase, float width) {
	float warp_a = dream_corruption_fbm3(p * 0.21 + phase * 3.7) - 0.5;
	float warp_b = dream_corruption_fbm3(p * 0.37 - phase * 5.1) - 0.5;
	vec3 q = p + vec3(warp_a, warp_b, warp_a - warp_b) * 0.62;
	float a = sin(q.y * 7.1 + q.x * 4.3 - q.z * 5.2 + phase * 17.0);
	float b = sin(q.y * 15.7 - q.x * 9.2 + q.z * 11.6 - phase * 9.0);
	float c = sin((q.x + q.z) * 12.4 + q.y * 2.9 + phase * 21.0);
	float ridge = max(1.0 - abs(a), 1.0 - abs(b));
	ridge = max(ridge, (1.0 - abs(c)) * 0.93);
	return smoothstep(clamp(width, 0.72, 0.98), 0.998, ridge);
}


// Sub-pixel-scale wetness breakup.  It moves much faster than the folds but
// modulates only specular intensity, never silhouette, colour or hazard truth.
float dream_corruption_wetfilm(vec3 p, float time_s, float phase) {
	float grain = dream_corruption_noise3(p * 8.7
			+ vec3(time_s * 0.025, phase * 13.0, -time_s * 0.017));
	float streak = 0.5 + 0.5 * sin(p.y * 29.0 + p.x * 13.0
			+ grain * 6.0 + time_s * 0.21);
	return smoothstep(0.46, 0.92, mix(grain, streak, 0.42));
}

#endif
