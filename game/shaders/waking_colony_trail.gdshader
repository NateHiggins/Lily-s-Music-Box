shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_burley, specular_schlick_ggx;
// WHERE THE WAKING CELL HAS BEEN (Lily, 2026-11-13: "i want the encroachment
// to colour the floor where it's traveled in a negative spectral trail that
// ripples in normal map reverting back to the floor texture").
//
// The owner lays a soft disc on the floor every few centimetres of the
// cell's way, each stamped with the moment it was laid. Inside a disc the
// floor is shown as its own negative: every colour turned to its opposite,
// split a little into its spectrum where the ripples bend it, so the grain
// and the boards are still there, wrong-coloured. Ripples run out over it
// from where the cell is now, in the picture and in the light (they are the
// normal map, so a lamp glints along them). A disc comes up over its first
// second, holds, then goes back to the floor as it ages, raggedly, last where
// the cloud is thickest; the ripples calm as it goes.
//
// It reads the floor from the screen, so it marks whatever floor it lies on.
// Optical: it has no surface of its own to map.

uniform float cell_time = 0.0;
uniform vec3 cell_at = vec3(0.0);     // where the cell is now, in this mesh's space
uniform float fade_s = 45.0;          // seconds from laid to gone
uniform float strength = 0.92;        // how far toward its negative the floor goes
uniform float split = 0.006;          // how far the ripples pull the spectrum apart, in screen units
uniform float ripple_depth = 0.9;     // how hard the ripples tilt the light
uniform vec3 stain_color : source_color = vec3(0.50, 0.28, 0.70);   // the encroachment's purple, a breath of it
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D cloud_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // cytoplasm_web.png
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_local;
varying float v_born;
varying vec2 v_disc;

void vertex() {
	v_local = VERTEX;
	v_born = UV2.x;
	v_disc = UV * 2.0 - 1.0;      // -1..1 across the disc
}

// The floor's colour at a bent place on the screen, unless something stands
// nearer than the floor there (a limb, a chair leg): then the straight place,
// so nothing in front of the floor leaves a coloured ghost on it.
float floor_at(vec2 bent_uv, vec2 straight_uv, float here_far, int channel, mat4 unproject) {
	float depth = texture(depth_tex, bent_uv).x;
	vec4 behind = unproject * vec4(bent_uv * 2.0 - 1.0, depth, 1.0);
	vec2 uv = (-behind.z / behind.w) < here_far - 0.03 ? straight_uv : bent_uv;
	return texture(screen_tex, uv)[channel];
}

// A colour's opposite at the same lightness: the grain keeps its light and
// dark, the hue goes to the other side.
vec3 negative(vec3 c) {
	return vec3(max(c.r, max(c.g, c.b)) + min(c.r, min(c.g, c.b))) - c;
}

void fragment() {
	float age = cell_time - v_born;
	vec2 p = v_local.xz;
	// Ripples: rings running out from the cell, and two slow swells across
	// them. The slope is worked out, not sampled, so it is the same ripple in
	// the picture and in the light.
	vec2 from_cell = p - cell_at.xz;
	float far = length(from_cell) + 0.0001;
	float calm = 1.0 - smoothstep(fade_s * 0.25, fade_s * 0.9, age);
	float ring_phase = far * 46.0 - cell_time * 4.2;
	float ring_fall = exp(-far * 1.4);
	vec2 slope = (from_cell / far) * cos(ring_phase) * ring_fall;
	slope += vec2(0.8, 0.6) * cos(dot(p, vec2(0.8, 0.6)) * 23.0 - cell_time * 1.7) * 0.35;
	slope += vec2(-0.5, 0.86) * cos(dot(p, vec2(-0.5, 0.86)) * 15.0 + cell_time * 1.1) * 0.25;
	slope *= calm;
	// How much of the mark is here: soft at the disc's edge, coming up over
	// the first second, and going back raggedly as it ages.
	float cloud = texture(cloud_tex, p * 1.3).g * 0.7 + texture(cloud_tex, p * 3.1 + 0.3).g * 0.3;
	float going = smoothstep(fade_s * 0.30, fade_s, age + (0.5 - cloud) * fade_s * 0.45);
	float disc = 1.0 - smoothstep(0.35, 1.0, length(v_disc) + (0.5 - cloud) * 0.35);
	float mark = disc * smoothstep(0.0, 1.2, age) * (1.0 - going);
	// The floor under it, bent by the ripples and pulled apart into its
	// spectrum along them, then turned to its negative.
	vec2 bend = slope * split;
	vec3 under = texture(screen_tex, SCREEN_UV).rgb;
	vec3 bent;
	bent.r = floor_at(SCREEN_UV + bend * 1.8, SCREEN_UV, -VERTEX.z, 0, INV_PROJECTION_MATRIX);
	bent.g = floor_at(SCREEN_UV + bend, SCREEN_UV, -VERTEX.z, 1, INV_PROJECTION_MATRIX);
	bent.b = floor_at(SCREEN_UV - bend * 0.8, SCREEN_UV, -VERTEX.z, 2, INV_PROJECTION_MATRIX);
	vec3 turned = negative(bent);
	// A spectral edge rides the crests.
	float crest = 0.5 + 0.5 * sin(ring_phase);
	vec3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + far * 2.2 - cell_time * 0.11 + cloud * 0.5));
	turned = mix(turned, turned * (0.55 + 0.9 * spectrum), 0.45 * calm * (0.4 + 0.6 * crest * ring_fall));
	turned = mix(turned, stain_color * (0.3 + dot(under, vec3(0.33))), 0.10);
	// The picture is the floor's own light already; show it as it is and let
	// the lamps add only their glint on the ripples.
	ALBEDO = vec3(0.0);
	EMISSION = mix(under, turned, strength);
	NORMAL_MAP = vec3(0.5 - 0.5 * clamp(slope.x * ripple_depth, -1.0, 1.0), 0.5 + 0.5 * clamp(slope.y * ripple_depth, -1.0, 1.0), 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.55, 0.22, calm);
	SPECULAR = 0.5;
	ALPHA = mark;
}
