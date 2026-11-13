shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_burley, specular_schlick_ggx;
// WHERE THE WAKING CELL HAS BEEN (Lily, 2026-11-13: "i want the encroachment
// to colour the floor where it's traveled in a negative spectral trail that
// ripples in normal map reverting back to the floor texture").
//
// The owner lays a soft disc on the floor every few centimetres of the
// cell's way, each stamped with the moment it was laid. Inside a disc the
// floor is shown as a spectrum laid over its own negative: bands of the
// whole rainbow that turn with the ripples and with the floor's light and
// dark, so the grain and the boards are still there, in colours no floor
// has. Ripples run along it the
// way the cell went (Lily: "have the ripples follow the direction it moves"):
// each disc remembers the heading it was laid on, and its ripples are a wake,
// fronts square to that heading and bowed back at the edges, running after
// the cell. They are in the picture and in the light (they are the normal
// map, so a lamp glints along them). A mark laid while the cell stood still
// has no heading and only rings from where the cell is. A disc comes up over its first
// second, holds, then goes back to the floor as it ages, raggedly, last where
// the cloud is thickest; the ripples calm as it goes.
//
// It reads the floor from the screen, so it marks whatever floor it lies on.
// Optical: it has no surface of its own to map.

uniform float cell_time = 0.0;
uniform vec3 cell_at = vec3(0.0);     // where the cell is now, in this mesh's space
uniform float fade_s = 95.0;          // seconds from laid to gone
// A mark's life (Lily: "make the ripples return to a negative afterimage
// before returning to the bare floor as a longer trail"): first the rippling
// spectrum; that settles, over the first two fifths, into the floor's plain
// negative, still and a little fainter, an afterimage; and over the last
// third the afterimage goes back to the bare floor.
uniform float strength = 0.92;        // how far toward its negative the floor goes
uniform float split = 0.009;          // how far the ripples pull the spectrum apart, in screen units
uniform float rainbow_share = 0.72;   // how much of the mark is the rainbow, the rest the plain negative
uniform float ripple_depth = 0.9;     // how hard the ripples tilt the light
uniform vec3 stain_color : source_color = vec3(0.50, 0.28, 0.70);   // the encroachment's purple, a breath of it
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D cloud_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // cytoplasm_web.png
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_local;
varying float v_born;
varying vec2 v_disc;
varying vec2 v_way;
varying float v_radius;

void vertex() {
	v_local = VERTEX;
	v_born = UV2.x;
	v_radius = UV2.y;
	v_disc = UV * 2.0 - 1.0;      // -1..1 across the disc
	v_way = COLOR.rg * 2.0 - 1.0; // the heading this disc was laid on, in x and z; nothing if it stood
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
	// Ripples. The slope is worked out, not sampled, so it is the same ripple
	// in the picture and in the light.
	float calm = 1.0 - smoothstep(fade_s * 0.14, fade_s * 0.42, age);
	float moving = smoothstep(0.2, 0.7, length(v_way));
	vec2 way = moving > 0.0 ? normalize(v_way) : vec2(1.0, 0.0);
	vec2 across_way = vec2(-way.y, way.x);
	// A wake: fronts square to the heading, bowed back at the trail's edges,
	// running the way the cell went.
	float off_line = dot(v_disc * v_radius, across_way);
	float wake_phase = (dot(p, way) + abs(off_line) * 0.8) * 44.0 - cell_time * 4.6;
	vec2 slope = normalize(way + across_way * sign(off_line) * 0.8) * cos(wake_phase) * moving;
	// Rings from where the cell is: all there is under a standing cell, a
	// trace of them near a moving one.
	vec2 from_cell = p - cell_at.xz;
	float far = length(from_cell) + 0.0001;
	float ring_phase = far * 46.0 - cell_time * 4.2;
	float ring_fall = exp(-far * 1.4);
	slope += (from_cell / far) * cos(ring_phase) * ring_fall * mix(1.0, 0.25, moving);
	// A slow swell across it all, so no two crests are quite alike.
	slope += across_way * cos(dot(p, across_way) * 15.0 + cell_time * 1.1) * 0.22;
	slope *= calm;
	// How much of the mark is here: soft at the disc's edge, coming up over
	// the first second, and going back raggedly as it ages.
	float cloud = texture(cloud_tex, p * 1.3).g * 0.7 + texture(cloud_tex, p * 3.1 + 0.3).g * 0.3;
	float going = smoothstep(fade_s * 0.66, fade_s, age + (0.5 - cloud) * fade_s * 0.25);
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
	// The spectrum (Lily: "more rainbow, less plain negative"). Bands of the
	// whole rainbow lie along the trail and run with the ripples; which colour
	// falls where turns with the wake's phase, the distance from the cell, the
	// cloud and the floor's own light and dark, so the boards and the grain
	// show as shifts of hue. The negative is what the rainbow is laid over,
	// and how bright the floor was is kept, so it is still that floor.
	float crest = mix(0.5 + 0.5 * sin(ring_phase), 0.5 + 0.5 * sin(wake_phase), moving);
	float light = dot(turned, vec3(0.30, 0.59, 0.11));
	float hue = mix(ring_phase, wake_phase, moving) * 0.045 + far * 1.3 + cloud * 0.9 + light * 1.6 - cell_time * 0.07;
	vec3 spectrum = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + hue));
	vec3 rainbow = spectrum * (0.30 + 1.25 * light) + 0.10 * spectrum * crest;
	turned = mix(turned, rainbow, rainbow_share * calm);
	turned = mix(turned, stain_color * (0.3 + dot(under, vec3(0.33))), 0.06);
	// The picture is the floor's own light already; show it as it is and let
	// the lamps add only their glint on the ripples.
	ALBEDO = vec3(0.0);
	EMISSION = mix(under, turned, strength * mix(0.78, 1.0, calm));
	NORMAL_MAP = vec3(0.5 - 0.5 * clamp(slope.x * ripple_depth, -1.0, 1.0), 0.5 + 0.5 * clamp(slope.y * ripple_depth, -1.0, 1.0), 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.55, 0.22, calm);
	SPECULAR = 0.5;
	ALPHA = mark;
}
