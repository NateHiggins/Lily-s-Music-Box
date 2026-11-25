shader_type spatial;
// The first-person rubber-hose arm (Lily, 2026-11-24): black-and-white cel
// shading in the manner of a 1920s-30s cartoon. A fixed key light in view space
// (upper left, toward the viewer) keeps the look the same in every room: the
// world's coloured lamps never tint the arm. Two flat tones per surface, a single
// hard shine on the hose, and a film grain that changes at 12 drawings a second.
render_mode unshaded, cull_back, depth_draw_opaque, skip_vertex_transform;

uniform float tone : hint_range(0.0, 1.0) = 0.96;        // lit tone: white glove, black ink
uniform float shadow_tone : hint_range(0.0, 1.0) = 0.70; // shadow tone as a share of tone
uniform float band : hint_range(-1.0, 1.0) = 0.12;       // where light turns to shadow
uniform float shine : hint_range(0.0, 1.0) = 0.0;        // the hose's hard highlight, 0 = none
uniform float shine_size : hint_range(0.8, 0.999) = 0.93;
uniform vec3 key_dir = vec3(-0.45, 0.70, 0.55);          // view space
uniform float grain : hint_range(0.0, 0.2) = 0.045;
uniform float frame_rate = 12.0;

varying vec3 view_normal;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view_normal = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(view_normal);
	vec3 l = normalize(key_dir);
	float lit = dot(n, l);
	float value = lit > band ? tone : tone * shadow_tone;
	if (shine > 0.0) {
		vec3 half_dir = normalize(l + vec3(0.0, 0.0, 1.0));
		if (dot(n, half_dir) > shine_size) {
			value = mix(value, 1.0, shine);
		}
	}
	float drawing = floor(TIME * frame_rate);
	value += (hash(floor(FRAGCOORD.xy * 0.5) + drawing * 7.13) - 0.5) * grain;
	ALBEDO = vec3(clamp(value, 0.0, 1.0));
}
