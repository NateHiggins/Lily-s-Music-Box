shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;
// THE WAKING COLONY'S VAPOUR (Lily, 2026-11-13: "an obscuring purplish vapor
// that can smooth where it interfaces with the floor and cilia"; then
// "thinner vapor but give it opalescent turbulence mixed with dark nebulous
// sparks").
//
// A thin bank of the encroachment's own purple lying round the foot of the
// cell: most where the membrane meets the floor and the cilia come out,
// thinning outward and upward, with nothing under the middle of the dome. It
// is a stack of level sheets the owner builds; this shader gives each sheet
// its share of the bank from where the fragment is in the cell's own space
// and fades it out against whatever solid thing is just behind it (the floor,
// a limb, a chair leg), which is what softens the seams.
//
// It is never still. The cloud that shapes it is stirred by itself, so it
// curls and folds; an opal runs through the folds, its colour turning with
// the stir and with the angle it is seen at; and through it drift dark
// nebulae with darker sparks in them that wink in and out. The dark is dark:
// it takes light away, it does not glow.
//
// Lit by the room, so it is dim in the dark. Optical: no surface to map.

uniform float cell_time = 0.0;
uniform float effort = 0.0;           // the cell is going somewhere: the bank trails behind it
uniform vec2 heading = vec2(0.0);
uniform float pull_rate = 0.42;       // the cytoskeleton's beat: the bank swells with it
uniform float pull_waves = 2.0;
uniform vec3 vapor_color : source_color = vec3(0.50, 0.28, 0.70);
uniform vec3 work_color : source_color = vec3(0.72, 0.36, 0.92);
uniform vec3 dark_color : source_color = vec3(0.025, 0.010, 0.045);
uniform float density = 0.92;         // how much the whole bank hides at its thickest: halfway between her first bank and her thin one
uniform float sheets = 11.0;          // how many sheets share it
uniform float soft_m = 0.05;          // metres over which it fades into a solid thing
uniform float opal = 0.70;            // how much of the bank's colour is the opal
uniform float sparks = 0.8;           // how much the dark nebulae and their sparks show
uniform vec2 rim = vec2(0.27, 0.23);  // the membrane's half-extents on the floor
uniform sampler2D cloud_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // cytoplasm_web.png: R web, G cloud, B streaks
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_local;
varying float v_rise;

float twitch(float t) {
	float s = fract(t);
	return s < 0.2 ? smoothstep(0.0, 0.2, s) : 1.0 - smoothstep(0.2, 1.0, s);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_rise = COLOR.r;             // 0 the sheet on the floor .. 1 the top one
	v_local = VERTEX;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// Where this is round the cell: 1 at the membrane's foot.
	vec2 at = v_local.xz + heading * effort * 0.10 * (0.4 + v_rise);
	float out_r = length(at / rim);
	float place = fract(atan(-at.y, at.x) / 6.2831853);
	float pull = twitch(cell_time * pull_rate - place * pull_waves);
	// Turbulence: the cloud stirs the place it is read from, twice over, and
	// the higher sheets slide over the lower ones.
	vec2 uv = at * 1.5 + vec2(cell_time * 0.021, -cell_time * 0.017) + vec2(0.31, 0.17) * v_rise;
	vec2 stir = texture(cloud_tex, uv * 0.55 + vec2(cell_time * 0.013, cell_time * 0.009)).gb - 0.5;
	uv += stir * 0.42;
	vec2 curl = texture(cloud_tex, uv * 1.3 - vec2(cell_time * 0.017, 0.0)).bg - 0.5;
	uv += curl * 0.16;
	float billow = texture(cloud_tex, uv).g * 0.62 + texture(cloud_tex, uv * 2.3 - vec2(cell_time * 0.034, 0.0)).g * 0.38;
	float wisps = texture(cloud_tex, uv * 0.7 + vec2(0.0, cell_time * 0.012)).b;
	// A thin bank round the foot with a ragged edge the billows push and pull.
	float edge = out_r - (billow - 0.5) * 1.1;
	float ring = smoothstep(0.32, 0.93, out_r) * (1.0 - smoothstep(1.15, 2.45 + 0.25 * pull, edge));
	float top = mix(1.0, 0.35, smoothstep(1.0, 2.3, out_r)) * (0.90 + 0.25 * pull);
	float column = 1.0 - smoothstep(0.0, top, v_rise);
	float foot = 1.0 - smoothstep(1.0, 1.6, out_r);
	float body = mix(0.28 + 1.0 * smoothstep(0.25, 0.80, billow), 1.0, foot * 0.88) + 0.28 * wisps * ring;
	// Dark nebulae: slow blots of the dark, and in them sparks, each in its
	// own cell of a fine grid, winking at its own time.
	float nebula = smoothstep(0.42, 0.72, texture(cloud_tex, uv * 0.9 + vec2(-cell_time * 0.008, cell_time * 0.011) + 0.37).g
			* (0.6 + 0.8 * texture(cloud_tex, uv * 2.1 + 0.11).r));
	vec2 grid = (at + stir * 0.05) * 24.0 + vec2(0.0, v_rise * 3.0);
	vec2 cell = floor(grid);
	vec2 mote = vec2(hash(cell), hash(cell + 17.0)) * 0.6 + 0.2;
	float wink = pow(max(0.0, sin(cell_time * (1.2 + 2.0 * hash(cell + 5.0)) + 6.2831853 * hash(cell + 9.0))), 6.0);
	float spark = (1.0 - smoothstep(0.05, 0.22, length(fract(grid) - mote))) * wink * step(0.55, hash(cell + 3.0));
	float dark = clamp((0.75 * nebula + 1.0 * spark * (0.35 + 0.65 * nebula)) * sparks, 0.0, 1.0);
	// Soft against whatever solid thing is just behind this sheet.
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_far = -behind.z / behind.w;
	float soft = clamp((scene_far + VERTEX.z) / soft_m, 0.0, 1.0);
	// Each sheet's share, so the stack hides `density` at its thickest; the
	// dark is denser than the vapour it drifts in, or it would not read.
	float share = 1.0 - pow(1.0 - clamp(density, 0.0, 0.98), 1.0 / sheets);
	float veil = clamp(share * 2.1 * ring * column * body, 0.0, 0.72);
	ALPHA = clamp(veil * (1.0 + 2.6 * dark), 0.0, 0.85) * soft;
	// The opal: its hue turns with the stir, the height and the angle of view.
	float graze = 1.0 - abs(dot(normalize(VIEW), vec3(0.0, 1.0, 0.0)));
	vec3 sheen = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + billow * 1.7 + stir.x * 1.2 + v_rise * 0.5
			+ graze * 0.6 + cell_time * 0.03));
	vec3 purple = mix(vapor_color, work_color, 0.35 * pull) * (0.75 + 0.35 * billow);
	vec3 lit = mix(purple, mix(purple, vec3(1.0), 0.35) * (0.45 + 0.9 * sheen), opal * smoothstep(0.25, 0.75, billow + 0.3 * wisps));
	ALBEDO = mix(lit, dark_color, dark);
	EMISSION = vapor_color * (0.04 + 0.06 * pull) * (1.0 - dark) + sheen * 0.05 * opal * (1.0 - dark);
	ROUGHNESS = 1.0;
}
