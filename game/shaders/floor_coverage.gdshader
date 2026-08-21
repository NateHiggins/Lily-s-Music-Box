shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// FLOOR COVERAGE — M-COVER in production (owner ruling 2026-08-21, "1 yes").
//
// A StandardMaterial3D stand-in for the building's floor sets. It takes the
// set's own albedo / normal / roughness maps and the builder's world-box UVs
// (TEXCOORD_0 is already world metres / the set's tile size) and renders
// them with the anti-repetition rule that suits the set's STRUCTURE:
//
//   coverage 0  PLAIN        one tap — what shipped before
//   coverage 1  HEX          three taps on a triangle grid at hashed offsets,
//                            variance-preserving blend; for FIELD sets with
//                            no structure to keep (concrete, hex mosaic)
//   coverage 2  CELL-SNAPPED hex whose offsets are snapped to the tile's own
//                            divider grid (`lattice_cells` per tile), so the
//                            baked dividers stay on their lattice while the
//                            aggregate in each cell is shuffled; terrazzo
//   coverage 3  ROWS         one tap, each board row shifted along the grain
//                            by a hashed amount; board edges survive exactly
//                            and the tile-period joint line is gone; oak
//
// Frames and costs that chose these: art/renders/material_coverage_m/.
// The probe this was promoted from: game/tests/coverage_probe.gdshader.

uniform int coverage : hint_range(0, 3) = 0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_mul = 1.0;
uniform float metallic = 0.0;
uniform float normal_scale = 0.35;
uniform bool has_rough_tex = true;
// Map means measured by the pass: the variance-preserving blend needs to
// know what "average" is so three averaged taps do not go grey.
uniform vec3 albedo_mean = vec3(0.5);
uniform float rough_mean = 0.5;
// Hex cells per tile (1.0 = one hexagon about one tile across).
uniform float hex_scale = 1.0;
// CELL-SNAPPED: divider cells per tile along each axis.
uniform float lattice_cells = 3.0;
// ROWS: board rows per tile across the grain, and which axis the grain runs.
uniform float rows_per_tile = 14.0;
uniform bool grain_along_u = true;

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

void triangle_grid(vec2 uv, out float w1, out float w2, out float w3,
		out vec2 v1, out vec2 v2, out vec2 v3) {
	uv *= 3.4641016 * hex_scale;
	mat2 grid_to_skewed = mat2(vec2(1.0, 0.0), vec2(-0.57735027, 1.15470054));
	vec2 skewed = grid_to_skewed * uv;
	vec2 base = floor(skewed);
	vec3 t = vec3(fract(skewed), 0.0);
	t.z = 1.0 - t.x - t.y;
	if (t.z > 0.0) {
		w1 = t.z; w2 = t.y; w3 = t.x;
		v1 = base; v2 = base + vec2(0.0, 1.0); v3 = base + vec2(1.0, 0.0);
	} else {
		w1 = -t.z; w2 = 1.0 - t.y; w3 = 1.0 - t.x;
		v1 = base + vec2(1.0, 1.0); v2 = base + vec2(1.0, 0.0); v3 = base + vec2(0.0, 1.0);
	}
}

vec2 cell_offset(vec2 v, float steps) {
	vec2 o = hash22(v);
	if (steps > 0.5) {
		o = floor(o * steps) / steps;
	}
	return o;
}

vec4 hex_sample(sampler2D tex, vec2 uv, vec2 ddx, vec2 ddy, vec4 mean, float steps) {
	float w1; float w2; float w3; vec2 v1; vec2 v2; vec2 v3;
	triangle_grid(uv, w1, w2, w3, v1, v2, v3);
	vec4 c1 = textureGrad(tex, uv + cell_offset(v1, steps), ddx, ddy);
	vec4 c2 = textureGrad(tex, uv + cell_offset(v2, steps), ddx, ddy);
	vec4 c3 = textureGrad(tex, uv + cell_offset(v3, steps), ddx, ddy);
	vec4 g = w1 * (c1 - mean) + w2 * (c2 - mean) + w3 * (c3 - mean);
	g /= sqrt(w1 * w1 + w2 * w2 + w3 * w3);
	return clamp(mean + g, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec4 alb;
	vec4 nrm;
	vec4 rgh;
	if (coverage == 1 || coverage == 2) {
		float steps = (coverage == 2) ? lattice_cells : 0.0;
		alb = hex_sample(albedo_tex, uv, ddx, ddy, vec4(albedo_mean, 1.0), steps);
		nrm = hex_sample(normal_tex, uv, ddx, ddy, vec4(0.5, 0.5, 1.0, 1.0), steps);
		rgh = hex_sample(rough_tex, uv, ddx, ddy, vec4(rough_mean), steps);
	} else if (coverage == 3) {
		float row = floor((grain_along_u ? uv.y : uv.x) * rows_per_tile);
		float shift = hash22(vec2(row, 7.0)).x * 3.0;
		vec2 ruv = uv + (grain_along_u ? vec2(shift, 0.0) : vec2(0.0, shift));
		alb = textureGrad(albedo_tex, ruv, ddx, ddy);
		nrm = textureGrad(normal_tex, ruv, ddx, ddy);
		rgh = textureGrad(rough_tex, ruv, ddx, ddy);
	} else {
		alb = texture(albedo_tex, uv);
		nrm = texture(normal_tex, uv);
		rgh = texture(rough_tex, uv);
	}
	ALBEDO = alb.rgb * albedo_color.rgb;
	float r = has_rough_tex ? rgh.r : 1.0;
	ROUGHNESS = clamp(r * roughness_mul, 0.0, 1.0);
	METALLIC = metallic;
	NORMAL_MAP = nrm.rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
