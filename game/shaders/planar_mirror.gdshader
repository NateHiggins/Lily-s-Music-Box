shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D mirror_view : source_color, filter_linear_mipmap;
uniform float reflection_gain : hint_range(0.5, 1.5) = 0.92;
uniform float age_strength : hint_range(0.0, 1.0) = 0.24;

void fragment() {
	vec2 feed_uv = vec2(UV.x, 1.0 - UV.y);
	vec3 reflected = texture(mirror_view, feed_uv).rgb * reflection_gain;
	float edge = smoothstep(0.42, 0.50, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	float broad = sin(UV.x * 19.0 + sin(UV.y * 13.0) * 2.2)
		* sin(UV.y * 27.0 - UV.x * 8.0);
	float fine = sin(UV.x * 63.0 + UV.y * 41.0) * 0.18;
	float foxing = smoothstep(0.58, 0.92, broad * 0.5 + 0.5 + fine)
		* age_strength;
	float veil = edge * 0.34 + foxing * (0.22 + edge * 0.38);
	vec3 old_silver = vec3(0.52, 0.54, 0.50);
	ALBEDO = mix(reflected, old_silver, clamp(veil, 0.0, 0.68));
	ROUGHNESS = 0.10 + veil * 0.52;
	METALLIC = 0.08;
}
