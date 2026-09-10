shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, ambient_light_disabled, specular_disabled;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
// A thin participating layer over native glass, not a replacement BRDF.
// Its geometry is on the lamp-only receiver layer; ordinary lights cannot
// add the lamp's field contribution a second time.
uniform float thickness_m = 0.004;
uniform float extinction_per_m = 8.0;
varying vec3 optical_world;
void vertex() {
	optical_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	LampOpticalSample optical = sample_lamp_optics(optical_world);
	float occupied = step(0.000001, dot(optical.radiance, vec3(0.333333)));
	float path_m = thickness_m / max(abs(dot(NORMAL, VIEW)), 0.2);
	float scatter = 1.0 - exp(-extinction_per_m * path_m);
	ALBEDO = vec3(0.94, 0.97, 1.0);
	ALPHA = scatter * occupied * optical.visibility * optical.transmittance;
	EMISSION = vec3(0.0);
}
void light() {
	float cosine = -dot(LIGHT, VIEW);
	const float g = 0.35;
	float phase = (1.0-g*g) / pow(max(1.0+g*g-2.0*g*cosine,0.01),1.5);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * phase / (4.0*PI);
}
