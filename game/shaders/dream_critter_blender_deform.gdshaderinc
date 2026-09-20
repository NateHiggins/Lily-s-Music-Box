// Blender-authored continuous anatomy. Imported absolute morph samples are
// shared by both warehouse batches. No bone, material or draw per individual.
uniform bool blender_provider_enabled = false;
uniform sampler2D blender_pose_tex : filter_nearest, repeat_disable;
uniform int blender_pose_width = 1024;
uniform int blender_pose_count = 19;
uniform float blender_slot_map[12];
uniform float blender_foot_base[12];
uniform float blender_cilia_base[12];
uniform float blender_prop_base[12];
uniform float blender_joint_base[12];
uniform float blender_manipulator_base[12];
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


// Explicit Lacrymaria source contract, validated against both imported LODs.
uniform vec3 blender_lacrymaria_root = vec3(0.0, 0.03, 0.37);
uniform vec2 blender_lacrymaria_reach = vec2(1.2, 6.4);

vec3 blender_rodrigues(vec3 point, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return point * c + cross(axis, point) * s + axis * dot(axis, point) * (1.0 - c);
}

vec3 blender_lacrymaria_center(float t, vec3 root, float reach, float wide, vec4 law) {
	vec3 direction = normalize(vec3(law.y * 0.34, 0.12 + sin(law.x * 0.37) * 0.18, 1.0));
	vec3 search = direction * reach * t;
	search += vec3(cos(law.x + 17.0 * t), sin(law.x * 0.73 + 13.0 * t), 0.0)
			* wide * 0.12 * sin(3.14159265 * t);
	// A fixed straight collar blends into the inherited hunting trajectory.
	// Both center and tangent match the trunk at the shared root ring.
	return root + mix(vec3(0.0, 0.0, reach * t), search, smoothstep(0.0, 0.12, t));
}

vec3 blender_lacrymaria_search(vec3 point, vec3 dimensions, vec4 law) {
	vec3 root = blender_lacrymaria_root * dimensions;
	float reach = dimensions.z * mix(blender_lacrymaria_reach.x, blender_lacrymaria_reach.y, clamp(law.z, 0.0, 1.0));
	float t = clamp((point.z - root.z) / max(reach, 0.0001), 0.0, 1.0);
	vec3 center = blender_lacrymaria_center(t, root, reach, dimensions.x, law);
	float low = max(0.0, t - 0.0005);
	float high = min(1.0, t + 0.0005);
	vec3 tangent = normalize(blender_lacrymaria_center(high, root, reach, dimensions.x, law)
			- blender_lacrymaria_center(low, root, reach, dimensions.x, law));
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), tangent));
	vec3 up = cross(tangent, side);
	vec3 offset = point - (root + vec3(0.0, 0.0, reach * t));
	return center + side * offset.x + up * offset.y + tangent * offset.z;
}

vec3 blender_lacrymaria_normal(vec3 point, vec3 normal, vec3 dimensions, vec4 law) {
	float epsilon = max(0.000001, min(dimensions.x, dimensions.y) * 0.0003);
	vec3 x = vec3(epsilon, 0.0, 0.0);
	vec3 y = vec3(0.0, epsilon, 0.0);
	vec3 z = vec3(0.0, 0.0, epsilon);
	vec3 dx = blender_lacrymaria_search(point+x,dimensions,law)-blender_lacrymaria_search(point-x,dimensions,law);
	vec3 dy = blender_lacrymaria_search(point+y,dimensions,law)-blender_lacrymaria_search(point-y,dimensions,law);
	vec3 dz = blender_lacrymaria_search(point+z,dimensions,law)-blender_lacrymaria_search(point-z,dimensions,law);
	return normalize(normal.x * cross(dy,dz) + normal.y * cross(dz,dx) + normal.z * cross(dx,dy));
}
