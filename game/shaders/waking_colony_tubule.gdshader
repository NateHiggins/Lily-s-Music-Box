shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE WAKING COLONY'S CYTOSKELETON (Lily, 2026-11-13): microtubules that work
// like muscle fibres, milky and translucent.
//
// The Blender build lays fascicles from an organising centre under the crown
// down the inside of the dome to the cilia's roots. Anatomy R is the distance
// along a fibre (0 and 1 are its anchored ends), G its place around the cell.
// Each fibre pulls and lets go: a quick contraction, a slow release, and the
// pull travels around the cell so the canopy works in a wave, in step with
// nothing else. Pulled, a fibre is taut, thick in the belly and dense; let go,
// it hangs slack toward the middle of the cell and thins to a haze.
//
// The substance is the registered recipe waking_colony_tubule on the fibre's
// authored UVs (u around, v along): cross-striated, like muscle (RUL-012).
// Translucency is hashed, not blended, so the fibres are in the picture the
// lensing membrane bends.

uniform float cell_time = 0.0;
uniform float pull_rate = 0.42;      // contractions a second; well under what strobes on film
uniform float pull_waves = 2.0;      // how many pulls are travelling around the cell at once
uniform float slack = 0.007;         // metres a released fibre hangs in
uniform float milk = 0.86;           // how much of a fibre is there at rest
uniform vec3 base_color : source_color = vec3(0.86, 0.88, 0.96);
uniform vec3 glow_color : source_color = vec3(0.80, 0.70, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_tile = vec2(1.0);
uniform float normal_depth = 0.8;

varying float v_along;
varying float v_pull;

// A twitch: up in the first fifth of the cycle, down over the rest.
float twitch(float t) {
	float s = fract(t);
	return s < 0.2 ? smoothstep(0.0, 0.2, s) : 1.0 - smoothstep(0.2, 1.0, s);
}

void vertex() {
	v_along = COLOR.r;
	float place = COLOR.g;
	float pull = twitch(cell_time * pull_rate - place * pull_waves);
	// A slower swell of effort, different for every fascicle, so the wave
	// never repeats exactly.
	pull *= 0.5 + 0.5 * (0.5 + 0.5 * sin(cell_time * 0.17 + place * 11.0));
	float belly = sin(v_along * 3.14159265);
	// Let go, the fibre sags toward the middle of the cell and a little down.
	// The ends are anchored (belly is zero there).
	vec3 inward = normalize(vec3(-VERTEX.x, -0.03 - VERTEX.y * 0.4, -VERTEX.z));
	VERTEX += inward * slack * belly * (1.0 - pull);
	// Pulled, it thickens in the belly and trembles.
	VERTEX += NORMAL * belly * pull * (0.0012 + 0.0003 * sin(v_along * 44.0 - cell_time * 9.0));
	v_pull = pull;
}

void fragment() {
	// The striations crowd together as the fibre shortens.
	vec2 uv = vec2(UV.x, UV.y * (1.0 + 0.22 * v_pull)) * uv_tile;
	vec3 surf = texture(albedo_tex, uv).rgb;
	float cos_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - cos_v, 2.0);
	vec3 opal = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + fres * 1.2 + v_along * 0.6));
	ALBEDO = base_color * surf * 1.12;
	ROUGHNESS = clamp(texture(rough_tex, uv).r, 0.04, 1.0);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	SPECULAR = 0.6;
	SSS_STRENGTH = 0.7;
	BACKLIGHT = base_color * 0.7;
	EMISSION = glow_color * (0.03 + 0.20 * v_pull * sin(v_along * 3.14159265)) + opal * fres * 0.18;
	// Milk: a tube of it is densest at its edge, in its dense bands and when
	// it is pulled short.
	float dense_band = 1.0 - surf.g;
	ALPHA = clamp(milk * (0.66 + 0.34 * fres) * (0.86 + 1.3 * dense_band) * (0.72 + 0.50 * v_pull), 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
}
