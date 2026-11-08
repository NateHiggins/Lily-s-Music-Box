shader_type canvas_item;
// The supernatural mist at the edge of the walkable city (OrisonV2CityEdgeMist).
// Drifting pale vapour closes from the edges of sight inward as `mist` rises;
// `black` is the pass-out fade over it.

uniform float mist : hint_range(0.0, 1.0) = 0.0;
uniform float black : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;

// Precision-safe hash (no sin of large arguments, which stepped into visible
// square seams on the GPU).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * vec2(3.2, 1.8);
	vec2 drift = vec2(time_s * 0.035, -time_s * 0.02);
	float n = fbm(p + drift + fbm(p * 1.7 - vec2(0.0, time_s * 0.05)));
	// Sight closes from its edges first, so the way back stays visible longest.
	float edge = smoothstep(0.1, 0.8, length(UV - vec2(0.5)) * 1.4);
	// Thin through the first half of the stretch so the street stays readable,
	// then closing to fully opaque by the pass-out ring.
	float density = clamp(mist * (0.3 + 0.5 * n) + pow(mist, 3.0) * 0.6 + edge * mist * 0.35, 0.0, 1.0);
	vec3 vapour = mix(vec3(0.60, 0.65, 0.68), vec3(0.82, 0.85, 0.86), n);
	COLOR = vec4(mix(vapour, vec3(0.0), black), max(density, black));
}
