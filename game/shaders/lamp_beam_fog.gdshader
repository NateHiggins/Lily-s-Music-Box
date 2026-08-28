shader_type fog;

uniform float density_gain : hint_range(0.0, 0.25) = 0.055;
uniform float grime : hint_range(0.0, 1.0) = 0.28;
uniform float smoke : hint_range(0.0, 1.0) = 0.08;
uniform float optical_time = 0.0;
uniform float lamp_output : hint_range(0.0, 1.2) = 1.0;

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
	float along = clamp(UVW.z, 0.0, 1.0);
	// SDF is negative inside the real cone. Fade its outer 18 cm rather than
	// drawing a second transparent cone mesh.
	float edge = 1.0 - smoothstep(-0.18, 0.0, SDF);
	vec3 convected = p * vec3(1.4, 2.2, 1.1)
		+ vec3(0.0, optical_time * 0.075, optical_time * 0.025);
	float dust = value_noise(convected) * 0.58
		+ value_noise(convected * 2.07 + 9.0) * 0.22;
	float lens_grime = value_noise(vec3(UVW.xy * 8.0, 2.4)) * grime;
	float convection = smoothstep(0.25, 0.9,
		value_noise(convected * vec3(0.7, 1.8, 0.7)));
	float bounded = edge * smoothstep(0.01, 0.10, along)
		* (1.0 - smoothstep(0.84, 1.0, along));
	DENSITY = density_gain * lamp_output * bounded
		* (0.34 + dust + lens_grime * (1.0 - along) + smoke * convection);
	ALBEDO = vec3(0.96, 0.78, 0.54);
	EMISSION = vec3(0.0);
}
