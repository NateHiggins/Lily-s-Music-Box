shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
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

// A mote scatters through its volume; it is not a flat card whose brightness
// changes with the billboard normal. Both vectors point away from the mote,
// hence -dot(LIGHT, VIEW) is the physical forward-scattering cosine.
void light() {
	float cosine = -dot(LIGHT, VIEW);
	const float g = 0.25;
	float phase = (1.0 - g*g) / pow(max(1.0 + g*g - 2.0*g*cosine, 0.01), 1.5);
	// Godot supplies the real scene shadow, cone, range and thermal color.
	// The shared field gates occupancy in fragment(), never adds radiance
	// again for every light or bypasses the renderer's shadow attenuation.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * phase / (4.0 * PI);
}
