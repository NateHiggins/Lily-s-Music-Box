shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
varying vec3 optical_world;

void vertex() {
	optical_world = MODEL_MATRIX[3].xyz;
	float particle_scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * particle_scale,
		INV_VIEW_MATRIX[1] * particle_scale,
		INV_VIEW_MATRIX[2] * particle_scale, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	LampOpticalSample optical = sample_lamp_optics(optical_world);
	float core = 1.0 - smoothstep(0.18, 0.95, length(UV * 2.0 - 1.0));
	float occupied = smoothstep(0.00001, 0.003, dot(optical.radiance, vec3(0.333333)));
	ALBEDO = vec3(0.72, 0.65, 0.53);
	ROUGHNESS = 0.85;
	ALPHA = core * occupied * optical.visibility * 0.65;
	ALPHA_HASH_SCALE = 1.0;
	// Native lighting receives real geometry shadows. No emission or additive
	// glow can make a mote shine through an occluder or outside the beam.
}
