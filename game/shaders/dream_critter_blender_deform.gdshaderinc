// Blender-authored continuous anatomy. Imported absolute morph samples are
// shared by both warehouse batches. No bone, material or draw per individual.
uniform bool blender_provider_enabled = false;
uniform sampler2D blender_pose_tex : filter_nearest, repeat_disable;
uniform int blender_pose_width = 1024;
uniform int blender_pose_count = 19;
uniform float blender_slot_map[12];
uniform float blender_foot_base[12];
uniform float blender_cilia_base[12];
// Review modes: 0 intact material; 1 neutral; 2 labelled anatomical cutaway.
uniform int blender_review_mode = 0;
varying float v_blender;
varying vec4 v_region;

vec3 blender_pose(int vertex_id, int pose, int component) {
	int pixel = (vertex_id * blender_pose_count + pose) * 2 + component;
	return texelFetch(blender_pose_tex,
			ivec2(pixel % blender_pose_width, pixel / blender_pose_width), 0).xyz;
}

vec3 blender_law_pose(int vertex_id, float amount, int component) {
	float sample_at = clamp(amount, 0.0, 1.0) * 16.0;
	int lo = int(floor(sample_at));
	int hi = min(lo + 1, 16);
	return mix(blender_pose(vertex_id, lo, component),
			blender_pose(vertex_id, hi, component), fract(sample_at));
}

vec3 blender_animated_pose(int vertex_id, float amount, vec2 phase, int component) {
	vec3 rest = blender_pose(vertex_id, 0, component);
	return blender_law_pose(vertex_id, amount, component)
			+ (blender_pose(vertex_id, 17, component) - rest) * phase.x
			+ (blender_pose(vertex_id, 18, component) - rest) * phase.y;
}
