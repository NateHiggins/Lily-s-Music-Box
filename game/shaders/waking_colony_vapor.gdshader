shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;
// THE WAKING COLONY'S VAPOUR (Lily, 2026-11-13: "an obscuring purplish vapor
// that can smooth where it interfaces with the floor and cilia").
//
// A low bank of the encroachment's own purple lying round the foot of the
// cell: thickest where the membrane meets the floor and the cilia come out,
// thinning outward and upward, with nothing under the middle of the dome. It
// is a stack of level sheets the owner builds; this shader gives each sheet
// its share of the bank from where the fragment is in the cell's own space,
// billows it with a drifting cloud, and fades it out against whatever solid
// thing is just behind it (the floor, a limb, a chair leg), which is what
// hides the seams. It is lit by the room, so it is dark in the dark.
//
// Optical, like the membrane's lensing: it has no surface to map.

uniform float cell_time = 0.0;
uniform float effort = 0.0;           // the cell is going somewhere: the bank trails behind it
uniform vec2 heading = vec2(0.0);
uniform float pull_rate = 0.42;       // the cytoskeleton's beat: the bank swells with it
uniform float pull_waves = 2.0;
uniform vec3 vapor_color : source_color = vec3(0.50, 0.28, 0.70);
uniform vec3 work_color : source_color = vec3(0.72, 0.36, 0.92);
uniform float density = 0.97;         // how much the whole bank hides at its thickest
uniform float sheets = 11.0;          // how many sheets share it
uniform float soft_m = 0.05;          // metres over which it fades into a solid thing
uniform vec2 rim = vec2(0.27, 0.23);  // the membrane's half-extents on the floor
uniform sampler2D cloud_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // cytoplasm_web.png: G cloud, B streaks
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 v_local;
varying float v_rise;

float twitch(float t) {
	float s = fract(t);
	return s < 0.2 ? smoothstep(0.0, 0.2, s) : 1.0 - smoothstep(0.2, 1.0, s);
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
	// Billows: two drifting reads of the cloud, the higher sheets sliding
	// over the lower ones.
	vec2 uv = at * 1.5 + vec2(cell_time * 0.021, -cell_time * 0.017) + vec2(0.31, 0.17) * v_rise;
	float billow = texture(cloud_tex, uv).g * 0.62 + texture(cloud_tex, uv * 2.3 - vec2(cell_time * 0.034, 0.0)).g * 0.38;
	float wisps = texture(cloud_tex, uv * 0.7 + vec2(0.0, cell_time * 0.012)).b;
	// A bank round the foot: none under the middle, most at the rim, and a
	// ragged edge that the billows push out and pull in; it lies lower the
	// farther out it is.
	float edge = out_r - (billow - 0.5) * 0.9;
	float ring = smoothstep(0.30, 0.92, out_r) * (1.0 - smoothstep(1.2, 2.6 + 0.25 * pull, edge));
	float top = mix(1.15, 0.40, smoothstep(1.0, 2.4, out_r)) * (0.90 + 0.25 * pull);
	float column = 1.0 - smoothstep(0.0, top, v_rise);
	// Thick by the foot whatever the billows do; patchy farther out.
	float foot = 1.0 - smoothstep(1.0, 1.7, out_r);
	float body = mix(0.30 + 0.95 * smoothstep(0.25, 0.80, billow), 1.0, foot) + 0.25 * wisps * ring;
	// Soft against whatever solid thing is just behind this sheet.
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_far = -behind.z / behind.w;
	float soft = clamp((scene_far + VERTEX.z) / soft_m, 0.0, 1.0);
	// Each sheet's share, so the stack hides `density` at its thickest.
	float share = 1.0 - pow(1.0 - clamp(density, 0.0, 0.98), 1.0 / sheets);
	ALPHA = clamp(share * 2.0 * ring * column * body, 0.0, 0.75) * soft;
	ALBEDO = mix(vapor_color, work_color, 0.35 * pull) * (0.75 + 0.35 * billow);
	EMISSION = vapor_color * (0.05 + 0.07 * pull);
	ROUGHNESS = 1.0;
}
