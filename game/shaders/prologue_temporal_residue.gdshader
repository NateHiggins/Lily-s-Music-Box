shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float age = 0.0;
void fragment() {
	vec2 p = SCREEN_UV - vec2(0.86, 0.43);
	float r = length(p);
	float fade = 1.0 - smoothstep(0.0, 1.0, age);
	vec2 offset = normalize(p + vec2(0.0001)) * sin(r * 48.0 - age * 9.0);
	offset *= 0.0014 * fade * exp(-r * 5.0);
	COLOR = vec4(texture(screen_texture, SCREEN_UV + offset).rgb, 1.0);
}
