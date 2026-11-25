shader_type spatial;
// Ink line for the first-person rubber-hose arm, drawn round every part (each
// finger, the cuff, the palm) so the flat fills read as one inked drawing: an inverted hull pushed out in
// screen space, so the line keeps one drawn width at any distance. The width
// "boils" a little at 12 drawings a second, like a hand-inked line redrawn per frame.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width_px : hint_range(0.0, 8.0) = 3.4;
uniform float boil : hint_range(0.0, 1.0) = 0.3;
uniform float frame_rate = 12.0;
uniform float depth_squeeze = 0.01;  // matches hose_arm_cel: drawn over the set

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 screen = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	float drawing = floor(TIME * frame_rate);
	float jitter = 1.0 + boil * (hash(VERTEX * 61.0 + drawing) - 0.5);
	if (length(screen) > 0.00001) {
		clip.xy += normalize(screen) * width_px * jitter * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	clip.z = clip.z * depth_squeeze + clip.w * (1.0 - depth_squeeze);
	POSITION = clip;
}

void fragment() {
	ALBEDO = vec3(0.0);
}
