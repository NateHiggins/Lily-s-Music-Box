shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// M-COVER PROBE. Not production: a StandardMaterial3D stand-in that takes the
// building's own albedo / normal / roughness set and the builder's world-box
// UVs (TEXCOORD_0 is already world metres / meters_per_tile), and renders the
// same surface under each anti-repetition option so the options can be
// photographed and priced against each other from one camera.
//
//   mode 0  PLAIN          one tap per map; what ships today
//   mode 1  MIRROR JITTER  one tap; each tile randomly mirrored in U and/or V.
//                          A seamless tile mirrored still meets its neighbour
//                          edge-for-edge, so this costs nothing and kills the
//                          "same order every tile" read — but not the motif.
//   mode 2  HEX STOCHASTIC three taps on a triangle grid, each at a hashed
//                          offset, blended variance-preserving (Heitz–Neyret
//                          2018 without the histogram transform). Kills the
//                          motif; slight softening where all three weights
//                          are similar.
//   mode 3  DETAIL         one tap plus the SAME set re-sampled at a second,
//                          irrational frequency as a detail layer (albedo
//                          overlay + normal add). Zero new VRAM; changes the
//                          feature size at mid distance so close and far no
//                          longer share one period.
//   mode 4  HEX + DETAIL
//   mode 5  MIRROR + DETAIL
//   mode 6  CELL-SNAPPED   hex stochastic whose three offsets are snapped to
//                          the tile's own divider grid (lattice_cells per
//                          tile: the 4 m terrazzo tile holds 3 x 3 cells of
//                          1.33 m). Every tap then agrees on where the baked
//                          brass strips are, so the lattice stays crisp while
//                          the aggregate inside each cell is shuffled among
//                          the nine authored cells. Structure by rule,
//                          variety by hash, no re-authoring.
//   mode 7  ROW OFFSET     for boards: one tap, each board row shifted along
//                          the grain by a hashed amount. Board edges survive
//                          exactly; the repeat along the run is gone.

uniform int mode = 0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_mul = 1.0;
uniform float metallic = 0.0;
uniform float normal_scale = 0.35;
uniform bool has_rough_tex = true;
// Means of the maps, measured by the harness: the variance-preserving blend
// needs to know what "average" is so three averaged taps do not go grey.
uniform vec3 albedo_mean = vec3(0.5);
uniform float rough_mean = 0.5;
// Detail layer: the same set by default (zero VRAM), at an irrational multiple.
uniform float detail_freq = 3.718;
uniform float detail_albedo_amount = 0.30;
uniform float detail_normal_amount = 0.45;
// Hex cells per tile. 1.0 = one hexagon is about one tile across.
uniform float hex_scale = 1.0;
// CELL-SNAPPED: divider cells per tile. The optional procedural lattice
// overlay is off (width 0) because snapping already keeps the baked one.
uniform float lattice_cells = 3.0;
uniform float lattice_width = 0.0;
uniform vec4 lattice_color : source_color = vec4(0.72, 0.55, 0.28, 1.0);
uniform float lattice_roughness = 0.35;
uniform float lattice_metallic = 0.6;
// ROW OFFSET: board rows per tile across the grain; grain runs along U.
uniform float rows_per_tile = 12.0;
uniform bool grain_along_u = true;

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// Heitz & Neyret triangle grid: which three vertices, and their barycentric weights.
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

// Three taps, variance-preserving blend around a known mean.
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
	vec2 uv1 = uv + cell_offset(v1, steps);
	vec2 uv2 = uv + cell_offset(v2, steps);
	vec2 uv3 = uv + cell_offset(v3, steps);
	vec4 c1 = textureGrad(tex, uv1, ddx, ddy);
	vec4 c2 = textureGrad(tex, uv2, ddx, ddy);
	vec4 c3 = textureGrad(tex, uv3, ddx, ddy);
	vec4 g = w1 * (c1 - mean) + w2 * (c2 - mean) + w3 * (c3 - mean);
	g /= sqrt(w1 * w1 + w2 * w2 + w3 * w3);
	return clamp(mean + g, 0.0, 1.0);
}

// One tap, tile mirrored per cell. Derivatives keep their magnitude so the
// mip chain does not see a seam at the cell edge.
vec2 mirror_uv(vec2 uv, out vec2 sgn) {
	vec2 cell = floor(uv);
	vec2 r = hash22(cell);
	vec2 f = fract(uv);
	sgn = vec2(1.0);
	if (r.x > 0.5) { f.x = 1.0 - f.x; sgn.x = -1.0; }
	if (r.y > 0.5) { f.y = 1.0 - f.y; sgn.y = -1.0; }
	return cell + f;
}

void fragment() {
	vec2 uv = UV;
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec4 alb;
	vec4 nrm;
	vec4 rgh;
	bool hex = (mode == 2 || mode == 4 || mode == 6);
	bool mirror = (mode == 1 || mode == 5);
	bool detail = (mode >= 3 && mode <= 5);
	if (mode == 7) {
		float row = floor((grain_along_u ? uv.y : uv.x) * rows_per_tile);
		float shift = hash22(vec2(row, 7.0)).x * 3.0;
		vec2 ruv = uv + (grain_along_u ? vec2(shift, 0.0) : vec2(0.0, shift));
		alb = textureGrad(albedo_tex, ruv, ddx, ddy);
		nrm = textureGrad(normal_tex, ruv, ddx, ddy);
		rgh = textureGrad(rough_tex, ruv, ddx, ddy);
	} else if (hex) {
		float steps = (mode == 6) ? lattice_cells : 0.0;
		alb = hex_sample(albedo_tex, uv, ddx, ddy, vec4(albedo_mean, 1.0), steps);
		nrm = hex_sample(normal_tex, uv, ddx, ddy, vec4(0.5, 0.5, 1.0, 1.0), steps);
		rgh = hex_sample(rough_tex, uv, ddx, ddy, vec4(rough_mean), steps);
	} else if (mirror) {
		vec2 sgn;
		vec2 muv = mirror_uv(uv, sgn);
		vec2 mdx = ddx * sgn;
		vec2 mdy = ddy * sgn;
		alb = textureGrad(albedo_tex, muv, mdx, mdy);
		nrm = textureGrad(normal_tex, muv, mdx, mdy);
		// A mirrored normal map has its tangent-space X (and/or Y) reversed.
		if (sgn.x < 0.0) nrm.x = 1.0 - nrm.x;
		if (sgn.y < 0.0) nrm.y = 1.0 - nrm.y;
		rgh = textureGrad(rough_tex, muv, mdx, mdy);
	} else {
		alb = texture(albedo_tex, uv);
		nrm = texture(normal_tex, uv);
		rgh = texture(rough_tex, uv);
	}
	vec3 albedo = alb.rgb;
	vec3 n = nrm.rgb;
	if (detail) {
		vec2 duv = uv * detail_freq + vec2(0.31, 0.77);
		vec3 da = texture(albedo_tex, duv).rgb;
		// Overlay around the set's own mean so the layer adds grain, not tint.
		albedo *= mix(vec3(1.0), 1.0 + (da - albedo_mean) * 1.6, detail_albedo_amount);
		vec3 dn = texture(normal_tex, duv).rgb;
		n.xy += (dn.xy - 0.5) * detail_normal_amount;
	}
	vec3 out_albedo = clamp(albedo, 0.0, 1.0) * albedo_color.rgb;
	float r = has_rough_tex ? rgh.r : 1.0;
	float out_rough = clamp(r * roughness_mul, 0.0, 1.0);
	float out_metal = metallic;
	if (mode == 6 && lattice_width > 0.0) {
		// Distance to the nearest tile edge in tile units, anti-aliased by
		// the screen-space derivative so the strip stays one strip at range.
		vec2 f = abs(fract(uv) - 0.5);
		float edge = 0.5 - max(f.x, f.y);
		// Screen-space footprint of one pixel in tile units, clamped: fwidth
		// of a wrapped coordinate spikes at the fract() seam and at grazing
		// angles, and an unclamped spike painted the strip 15 cm wide.
		float fw = clamp(max(fwidth(uv.x), fwidth(uv.y)), 0.0005, 0.01);
		float strip = 1.0 - smoothstep(lattice_width, lattice_width + fw, edge);
		out_albedo = mix(out_albedo, lattice_color.rgb, strip);
		out_rough = mix(out_rough, lattice_roughness, strip);
		out_metal = mix(out_metal, lattice_metallic, strip);
		n = mix(n, vec3(0.5, 0.5, 1.0), strip);
	}
	ALBEDO = out_albedo;
	ROUGHNESS = out_rough;
	METALLIC = out_metal;
	NORMAL_MAP = clamp(n, 0.0, 1.0);
	NORMAL_MAP_DEPTH = normal_scale;
}
