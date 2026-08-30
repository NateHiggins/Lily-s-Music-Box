shader_type canvas_item;
render_mode unshaded;

uniform sampler3D exposure_tex : filter_linear, repeat_enable, hint_default_black;
uniform vec3 world_point = vec3(0.25, 1.25, 0.25);
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;

void fragment() {
	vec3 voxel_uv = vec3(world_point.x / exposure_extent,
			world_point.z / exposure_extent,
			clamp(world_point.y / exposure_height, 0.0625, 0.9375));
	float response = texture(exposure_tex, voxel_uv).g;
	COLOR = vec4(response, response, response, 1.0);
}
