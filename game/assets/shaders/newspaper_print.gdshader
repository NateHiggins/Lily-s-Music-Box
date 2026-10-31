shader_type canvas_item;
// A greyscale picture printed on the sheet at screen resolution, so the dots stay
// crisp at any size and the page's own paper shows through between them.
// mode 0: press halftone. mode 1: sepia gravure. mode 2: line work.

uniform int mode = 0;
uniform vec4 ink_color : source_color = vec4(0.11, 0.098, 0.086, 1.0);
uniform vec4 paper_color : source_color = vec4(0.886, 0.824, 0.706, 1.0);
uniform vec2 rect_size = vec2(100.0);
uniform float cell = 3.6;
uniform bool oval = false;

void fragment() {
	float grey = texture(TEXTURE, UV).r;
	vec4 printed;
	if (mode == 1) {
		printed = vec4(mix(ink_color.rgb, paper_color.rgb, grey), 1.0);
	} else if (mode == 2) {
		printed = vec4(ink_color.rgb, clamp((0.686 - grey) / 0.412, 0.0, 1.0));
	} else {
		vec2 p = UV * rect_size * 6.2831853 / cell;
		float u = (p.x + p.y) * 0.7071068;
		float v = (p.y - p.x) * 0.7071068;
		float screen = (cos(u) + cos(v)) * 0.25 + 0.5;
		printed = vec4(ink_color.rgb, smoothstep(-0.12, 0.12, screen - (grey * 0.92 + 0.05)));
	}
	if (oval) {
		vec2 q = UV * 2.0 - 1.0;
		printed.a *= step(dot(q, q), 1.0);
	}
	COLOR = printed;
}
