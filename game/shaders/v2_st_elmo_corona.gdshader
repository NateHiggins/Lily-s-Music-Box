shader_type spatial;
// St. Elmo's fire: a blue-violet corona streaming from a grounded tip in a
// high-charge storm. One quad per tip, faced to the camera about world up.
// Fog-exempt: the corona is seen through the storm that makes it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float corona = 0.0;
varying float tip_seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_camera = CAMERA_POSITION_WORLD - origin;
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_camera + vec3(1e-4, 0.0, 0.0)));
	float size = INSTANCE_CUSTOM.x;
	tip_seed = INSTANCE_CUSTOM.y;
	// The quad stands on the tip: the brush-discharge rises above it.
	vec3 world = origin + right * VERTEX.x * size + vec3(0.0, 1.0, 0.0) * (VERTEX.y + 0.35) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float seed = tip_seed;
	float t = TIME * 6.0 + seed * 37.0;
	// A crown of tongues fanning up from the tip, flickering independently.
	float fan = atan(uv.x, uv.y + 1.0);
	float tongues = 0.5 + 0.5 * sin(fan * 9.0 + t * 1.7) * sin(fan * 5.0 - t * 1.1 + seed);
	float r = length(vec2(uv.x, (uv.y + 0.85) * 0.75));
	float body = exp(-r * r * 5.0) * (0.6 + 0.8 * tongues * smoothstep(-0.6, 0.6, uv.y));
	vec2 tip = uv - vec2(0.0, -0.7);
	float core = exp(-dot(tip, tip) * 30.0);
	float flicker = 0.75 + 0.25 * sin(t * 3.3) * sin(t * 1.9 + seed);
	vec3 colour = mix(vec3(0.45, 0.35, 1.0), vec3(0.78, 0.86, 1.0), core);
	ALBEDO = colour * (body + core * 1.5) * corona * flicker * 2.4;
}
