shader_type spatial;
// The first-person rubber-hose arm (Lily, 2026-11-24): drawn like a 1920s-30s
// rubber-hose cartoon limb, with no depth. One flat tone per part: ink-black hose,
// paper-white glove. No light, no shading, no highlight, so the shape reads as a
// flat drawing; the ink outline pass gives every part its line. A faint film grain
// changes at 12 drawings a second.
render_mode unshaded, cull_back, depth_draw_opaque;

uniform float tone : hint_range(0.0, 1.0) = 0.96;  // paper white or ink black
uniform float grain : hint_range(0.0, 0.2) = 0.035;
uniform float frame_rate = 12.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float drawing = floor(TIME * frame_rate);
	float value = tone + (hash(floor(FRAGCOORD.xy * 0.5) + drawing * 7.13) - 0.5) * grain;
	ALBEDO = vec3(clamp(value, 0.0, 1.0));
}
