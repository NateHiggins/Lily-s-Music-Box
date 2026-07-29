// Full-screen infection distortion. intensity 0 = clean passthrough.
// Deliberately subtle: occasional scanline tears, slight chromatic split,
// and grain that grows with room infection. No jump-scare flashes.
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float rnd(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = step(1.0 - intensity * 0.012, rnd(vec2(floor(uv.y * 96.0), floor(TIME * 13.0))));
	uv.x += band * (rnd(vec2(TIME, uv.y)) - 0.5) * 0.035 * intensity;
	float split = 0.0016 * intensity;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(split, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(split, 0.0)).b;
	float grain = (rnd(uv * 913.7 + vec2(TIME)) - 0.5) * 0.07 * intensity;
	COLOR = vec4(col + grain, 1.0);
}
