shader_type spatial;
// Preview only (Lily 2026-11-28: see the world in the comic look). A full-screen
// pass over the opaque frame: flat tone bands with the hue kept, ink outlines
// from depth and normal breaks, halftone dots in the shade band, a warm paper
// cast. No lettering, no texture: everything here is arithmetic.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

uniform sampler2D screen_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_normal : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform float bands = 3.0;                  // lit tones above the ink floor
uniform float ink_floor = 0.09;             // display luminance under which a pixel goes to solid ink
uniform float band_softness = 0.04;
uniform float line_px = 1.5;                // outline sample offset at 1440p
uniform float depth_edge = 0.02;            // relative depth break that inks a line
uniform float normal_edge = 0.35;           // normal break that inks a line
uniform float halftone_px = 7.0;
uniform float halftone_band = 0.34;         // below this tone, dots appear
uniform vec3 ink = vec3(0.045, 0.035, 0.03);   // display colour, near black
uniform vec3 paper = vec3(1.0, 0.965, 0.88);
uniform float saturation = 0.9;
// Adela's presence (Lily 2026-11-28, rulings adela_presence_rule/turn): the
// world is real around her. presence is the director's bled 0..1; the bubble
// is measured in metres from her, in the world the pixel shows.
uniform float presence = 0.0;
uniform vec3 adela_world = vec3(0.0);
uniform float bubble_inner = 3.0;
uniform float bubble_outer = 11.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(screen_depth, uv).r;
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -view.z / view.w;
}

vec3 normal_at(vec2 uv) {
	return texture(screen_normal, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = line_px / VIEWPORT_SIZE;
	// The screen texture is linear light before tone mapping. Band and ink in
	// display brightness (Reinhard then gamma), and hand linear light back.
	vec3 colour = texture(screen_color, uv).rgb;
	vec3 shown = pow(colour / (1.0 + colour), vec3(1.0 / 2.2));
	float lum = dot(shown, vec3(0.2126, 0.7152, 0.0722));

	// Tone: quantise brightness, keep the hue.
	float t = clamp(lum, 0.0, 0.999);
	// Each band edge is softened over band_softness so tones do not shimmer.
	float scaled = t * bands;
	float base = floor(scaled);
	float stepped = min(1.0, (base + 0.5 + smoothstep(1.0 - band_softness * bands, 1.0, fract(scaled))) / bands);
	vec3 hue = shown / max(lum, 1e-4);
	vec3 toned = clamp(hue * stepped, 0.0, 1.0);
	float grey = dot(toned, vec3(0.333));
	toned = mix(vec3(grey), toned, saturation) * paper;

	// Halftone dots in the shade band, on a 45 degree screen.
	vec2 cell_uv = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * (FRAGCOORD.xy / halftone_px);
	vec2 cell = fract(cell_uv) - 0.5;
	float coverage = clamp((halftone_band - t) / halftone_band, 0.0, 1.0);
	float dot_mask = step(length(cell), sqrt(coverage) * 0.62);
	toned = mix(toned, ink, dot_mask * step(ink_floor, t) * 0.85);

	// Solid ink where the light gives out.
	toned = mix(toned, ink, 1.0 - smoothstep(ink_floor - 0.02, ink_floor + 0.02, t));

	// Outlines: depth and normal breaks against four neighbours.
	float d0 = linear_depth(uv, INV_PROJECTION_MATRIX);
	vec3 n0 = normal_at(uv);
	float edge = 0.0;
	vec2 offsets[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 o = uv + offsets[i];
		float d = linear_depth(o, INV_PROJECTION_MATRIX);
		edge = max(edge, step(depth_edge, abs(d - d0) / max(d0, 0.05)));
		edge = max(edge, step(normal_edge, 1.0 - dot(n0, normal_at(o))));
	}
	// Thin lines far away so distance does not turn to mud.
	edge *= 1.0 - smoothstep(25.0, 60.0, d0);
	vec3 comic_shown = clamp(mix(toned, ink, edge), 0.0, 0.995);
	vec3 comic_linear = pow(comic_shown, vec3(2.2));
	vec3 comic = comic_linear / (1.0 - comic_linear);

	// The real world, where she is: lines and bands melt into the render.
	float real = 0.0;
	if (presence > 0.001) {
		float depth = texture(screen_depth, uv).r;
		vec4 view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, depth, 1.0);
		vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
		float reach = mix(bubble_inner, bubble_outer, presence);
		real = presence * (1.0 - smoothstep(reach * 0.45, reach, distance(world, adela_world)));
	}
	ALBEDO = mix(comic, colour, real);
}
