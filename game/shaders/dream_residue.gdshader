shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx, unshaded;
// DREAM SALIVA (design/DREAM_SALIVA_DIRECTION.md).
//
//   "iridescent holographic reflective saliva goo ... that crystalizes like
//    superchilled frost in a otherworldly metalic neon rainbow with
//    dimensional breaking properties that persist and decay like its being
//    eroded by an eon of time in a couple seconds"
//
// Five demands, each of which fails differently, so each is built separately.
//
// IRIDESCENT means STRUCTURAL COLOUR: the hue must move with the viewing
// angle and with the lamp. A fixed rainbow gradient painted on a surface is
// the failure mode, so the hue here comes from a thin-film interference term
// driven by the angle between view and surface — look at it from somewhere
// else and it is a different colour.
//
// CRYSTALLISES LIKE FROST means it PROPAGATES rather than appearing: a
// noise-warped front runs outward, faster along some directions than others,
// with a bright leading edge. You can catch it in the act.
//
// ERODED BY AN EON IN A COUPLE OF SECONDS is the hard one, and it is why the
// stages are authored rather than lerped. Different properties die at
// different times — the structural colour goes before the substance does,
// then it pits, then it cracks, then only a ghost of mineral is left. A
// uniform fade is exactly what this must not look like.
//
// One mesh, one draw, up to MAX_PATCHES contacts. The frame is
// submission-bound (design/DT4_PERFORMANCE_REAUDIT.md).

const int MAX_PATCHES = 24;

// xyz centre, w radius
uniform vec4 patch_pos[24];
// xyz normal, w age in seconds
uniform vec4 patch_nrm[24];
// x seed, y intensity, z lifetime, w unused
uniform vec4 patch_par[24];
uniform int patch_count = 0;
uniform float dream_w = 0.0;

varying vec2 v_local;
varying float v_age;
varying float v_seed;
varying float v_life;
varying float v_intensity;
varying vec3 v_world;
varying vec3 v_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	int p = int(UV2.x + 0.5);
	vec4 pos = patch_pos[p];
	vec4 nrm = patch_nrm[p];
	vec4 par = patch_par[p];
	vec3 n = normalize(nrm.xyz + vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tx = normalize(cross(any, n));
	vec3 ty = cross(n, tx);
	// The unit disc in the mesh becomes a patch on the surface it was left on,
	// lifted a hair so it does not fight the wall for the depth buffer.
	vec2 uv = VERTEX.xy;
	float dead = par.z > 0.0 && nrm.w > par.z ? 0.0 : 1.0;
	vec3 world = pos.xyz + (tx * uv.x + ty * uv.y) * pos.w * dead + n * 0.004;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
	NORMAL = n;
	v_local = uv;
	v_age = nrm.w;
	v_seed = par.x;
	v_intensity = par.y;
	v_life = par.z;
	v_world = world;
	v_normal = n;
}

void fragment() {
	float r = length(v_local);
	if (r > 1.0 || v_life <= 0.0) {
		discard;
	}
	float age = v_age;
	float life = v_life;
	float t = clamp(age / max(0.001, life), 0.0, 1.0);
	vec2 np = v_local * 3.4 + vec2(v_seed * 11.0, v_seed * 7.0);

	// ---- THE FROST FRONT ------------------------------------------------
	// It propagates. The boundary is warped so it runs faster along some
	// directions than others, the way frost follows a scratch in glass.
	float warp = fbm(np * 1.6) * 0.55 + fbm(np * 4.1) * 0.22;
	float front = clamp(age / 0.55, 0.0, 1.4);
	float edge_r = r + warp * 0.62 - 0.30;
	float covered = smoothstep(front, front - 0.16, edge_r);
	if (covered <= 0.003) {
		discard;
	}
	// A bright leading edge, only while it is still running.
	float lead = smoothstep(front - 0.10, front, edge_r)
			* smoothstep(front + 0.05, front - 0.02, edge_r)
			* (1.0 - smoothstep(0.5, 1.0, age / 0.75));

	// ---- EROSION, NOT A FADE --------------------------------------------
	// Pits open and widen; then cracks; then only a ghost. Each on its own
	// clock, so the thing decays unevenly the way something old does.
	float pit_t = smoothstep(0.34, 0.92, t);
	float pits = smoothstep(0.52 - 0.30 * pit_t, 0.58 - 0.30 * pit_t, fbm(np * 5.2 + 3.1));
	float crack_t = smoothstep(0.46, 1.0, t);
	float cracks = smoothstep(0.46, 0.50, abs(fbm(np * 3.1 + 11.0) - 0.5) * 2.0);
	float substance = covered * (1.0 - pits * pit_t) * (1.0 - (1.0 - cracks) * crack_t * 0.85);
	// The very edge thins first, always -- and it is NOT A CIRCLE. Once the
	// front had run past the disc the outer boundary was the mesh's own rim,
	// so a fully grown patch photographed as a perfect circle: a decal, not
	// something spilled. The boundary carries the same warp the front did.
	substance *= smoothstep(1.0, 0.70 - 0.25 * t, r + warp * 0.42 - 0.19);
	if (substance <= 0.004) {
		discard;
	}

	// ---- STRUCTURAL COLOUR ----------------------------------------------
	// Thin-film interference: hue from the VIEW ANGLE, not from a gradient.
	// It also dies before the substance does, which is what makes the decay
	// read as erosion rather than as opacity going down.
	vec3 view_dir = normalize(VIEW);
	// BROAD BANDS, NOT A DIFFRACTION GRATING. The first version used 1/facing
	// directly, which reaches fifty at grazing angles and cycled the hue fifty
	// times across one patch -- photographed, it was a fine moiré that read as
	// a CD surface rather than as structural colour on something wet. The
	// angle still drives it, so the hue still moves as you move; it just
	// sweeps a couple of bands instead of dozens.
	float facing = clamp(abs(dot(normalize(v_normal), view_dir)), 0.22, 1.0);
	// The angle gives the patch its overall hue and makes it shift as you
	// move; the spatial term gives it BANDS. With only the angle it came out
	// one flat colour across the whole patch, because a flat patch has one
	// facing -- a neon rainbow needs more than one band in it.
	float film = (0.55 + 0.75 * (1.0 - facing)) * 1.6
			+ fbm(np * 1.1) * 1.7 + fbm(np * 3.3) * 0.5
			+ dream_w * 0.20 + v_seed * 2.0;
	vec3 iris = 0.5 + 0.5 * cos(6.2831853 * (film + vec3(0.0, 0.33, 0.67)));
	// Neon and metallic rather than pastel: pushed away from grey, hard.
	iris = pow(clamp(iris, vec3(0.0), vec3(1.0)), vec3(2.1));
	iris /= max(0.22, (iris.r + iris.g + iris.b) * 0.42);
	float colour_life = 1.0 - smoothstep(0.20, 0.72, t);

	// Crystal facets: flat cells that catch the light in one direction each.
	vec2 cell = floor(np * 6.0);
	float facet = hash21(cell);
	float crystallised = smoothstep(0.10, 0.55, age / max(0.001, life * 0.5));
	float glint = pow(max(0.0, dot(view_dir, normalize(v_normal
			+ vec3(facet - 0.5, hash21(cell + 7.0) - 0.5, 0.0) * 0.85))), 22.0);

	vec3 wet = vec3(0.62, 0.70, 0.78) * 0.35;
	vec3 body = mix(wet, iris, colour_life * crystallised);
	body += iris * glint * crystallised * colour_life * 2.4;
	body += vec3(1.0, 0.96, 0.9) * lead * 1.8;
	// The ghost: what is left once the colour has gone is dull mineral.
	vec3 ghost = vec3(0.20, 0.17, 0.24);
	body = mix(ghost, body, colour_life * 0.85 + 0.15);

	ALBEDO = body * v_intensity;
	ALPHA = clamp(substance * (0.55 + 0.45 * colour_life) * v_intensity, 0.0, 1.0);
	EMISSION = body * (0.35 * colour_life + lead * 1.2) * v_intensity;
}
