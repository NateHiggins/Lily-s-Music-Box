shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// THE WAKING COLONY'S MEMBRANE (Lily, 2026-11-09: "elaborate and exaggerated
// optical lensing and refractive/reflective opalescent 3d shading").
//
// A thick, living lens over the colony's organelles. Three things, all view
// dependent, so the cell changes as the camera and the companion's lamp move:
//   - refraction: the opaque scene behind (the organelles, the floor) is read
//     back from the screen, offset by the membrane's normal and its thickness,
//     with red, green and blue bent by different amounts (dispersion);
//   - thin-film interference: a soap-bubble opal whose hue rides the film's
//     uneven thickness and the angle it is seen at;
//   - Fresnel reflection: glassy at grazing angles, clear face-on.
// The tardigrade's own membrane normal stock gives the film its micro-relief,
// so this organism and the tardigrade share a skin.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D tardi_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cell_time = 0.0;
uniform float lens_strength = 0.16;      // exaggerated on purpose
uniform float dispersion = 0.35;
uniform float film_nm = 760.0;           // mean film thickness: higher orders read paler
uniform float film_spread_nm = 220.0;    // how much it varies over the cell
uniform float opal_gain = 0.55;
uniform vec3 tint : source_color = vec3(0.92, 0.97, 1.0);
uniform float breathe = 1.0;
// The cytoplasm seen through the film (Lily, 2026-11-13): milky, translucent,
// an irregular web of microtubules that shifts and pulls like muscle. It is
// read from a density map at three depths under the film, each sliding its
// own way, tightening when the canopy's travelling pull passes. Optical, like
// the lensing: the fibres with real surfaces are the Cytoskeleton mesh.
uniform sampler2D cytoplasm_web : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float milk = 0.66;
uniform vec3 milk_color : source_color = vec3(0.90, 0.93, 1.0);
uniform float web_scale = 5.5;       // repeats of the web per metre... of a half-metre cell
uniform float pull_rate = 0.42;      // the cytoskeleton shader's own
uniform float pull_waves = 2.0;

varying float v_thick;
varying vec3 v_local;
varying vec3 v_normal_local;
varying vec3 v_eye_local;

float twitch(float t) {
	float s = fract(t);
	return s < 0.2 ? smoothstep(0.0, 0.2, s) : 1.0 - smoothstep(0.2, 1.0, s);
}

// The web at one depth under the film: seen from above on the crown, wrapped
// around on the flank, so it never smears down the sides.
vec3 web_at(vec3 p, vec3 n, vec2 slide, float squeeze) {
	vec2 top = p.xz * web_scale * squeeze + slide;
	vec2 side = vec2(atan(p.z, p.x) * 0.9549, p.y * web_scale * 1.6) * squeeze + slide;
	float crown = smoothstep(0.35, 0.75, abs(n.y));
	return mix(texture(cytoplasm_web, side).rgb, texture(cytoplasm_web, top).rgb, crown);
}

void vertex() {
	v_thick = COLOR.r;           // 0 skirt .. 1 crown (authored in Blender)
	v_local = VERTEX;
	v_normal_local = NORMAL;
	v_eye_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	// Slow peristalsis: two travelling waves over the dome, never in step.
	float w = sin(cell_time * 0.9 + VERTEX.x * 22.0 + VERTEX.z * 9.0)
			+ 0.6 * sin(cell_time * 1.37 - VERTEX.z * 26.0 + VERTEX.x * 5.0);
	VERTEX += NORMAL * w * 0.0035 * breathe * smoothstep(0.0, 0.25, v_thick);
}

vec3 film(float d_nm, float cos_t) {
	// Two-beam interference in a film of index 1.36 for three wavelengths.
	vec3 lambda = vec3(650.0, 540.0, 450.0);
	vec3 phase = 6.2831853 * 2.0 * 1.36 * d_nm * cos_t / lambda;
	return 0.5 + 0.5 * cos(phase);
}

void fragment() {
	vec2 muv = UV * 3.0 + vec2(cell_time * 0.006, -cell_time * 0.004);
	vec3 micro = texture(tardi_normal, muv).rgb * 2.0 - 1.0;
	vec3 n = normalize(NORMAL + (TANGENT * micro.x + BINORMAL * micro.y) * 0.35);
	float cos_v = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - cos_v, 3.0);

	// Uneven film: thin where the cell is stretched over its crown.
	float swirl = sin(v_local.x * 31.0 + cell_time * 0.31) * sin(v_local.z * 27.0 - cell_time * 0.23)
			+ 0.5 * sin((v_local.x + v_local.z) * 63.0 + cell_time * 0.7);
	float d = film_nm + film_spread_nm * (swirl * 0.5 + (0.5 - v_thick) * 0.8);
	// Real thin films show pale, pearly colour; keep the hues soft.
	vec3 opal = mix(vec3(0.85), film(d, mix(0.25, 1.0, cos_v)), 0.55);

	// Lensing: a thicker, more curved membrane bends the view behind it more.
	vec2 bend = n.xy * lens_strength * (0.55 + (1.0 - v_thick) * 0.9) * (0.4 + fres * 1.6);
	float lod = 0.2 + fres * 1.5;
	vec3 behind;
	behind.r = textureLod(screen_tex, SCREEN_UV + bend * (1.0 - dispersion), lod).r;
	behind.g = textureLod(screen_tex, SCREEN_UV + bend, lod).g;
	behind.b = textureLod(screen_tex, SCREEN_UV + bend * (1.0 + dispersion), lod).b;

	// What reaches the eye: the bent scene through a faintly tinted film,
	// the opal riding over it, strongest at grazing angles.
	// Face-on the cell is clear: the lensed interior. At grazing angles the
	// film's opal and the room's reflection take over.
	float sheen = pow(fres, 1.4);

	// The milky interior: three sheets of the web under the film, the deeper
	// the fainter, each drifting and each drawn tight as the pull goes by.
	vec3 n_local = normalize(v_normal_local);
	vec3 to_eye = normalize(v_eye_local - v_local);
	float facing = max(dot(to_eye, n_local), 0.3);
	float place = fract(atan(-v_local.z, v_local.x) / 6.2831853);
	float pull = twitch(cell_time * pull_rate - place * pull_waves);
	float fibres = 0.0;
	float cloud = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float k = float(layer);
		float depth = 0.012 + 0.024 * k;
		vec3 p = v_local - to_eye * depth / facing;
		vec2 slide = vec2(sin(cell_time * 0.21 + k * 1.7), cos(cell_time * 0.17 + k * 2.3)) * 0.035
				+ vec2(0.37, 0.61) * k + cell_time * vec2(0.004, -0.003) * (1.0 + k);
		vec3 w = web_at(p, n_local, slide, 1.0 + 0.05 * pull * (1.0 - 0.3 * k));
		float seen = 1.0 - 0.28 * k;
		fibres = max(fibres, (w.r * (0.55 + 0.45 * pull) + w.b * 0.30) * seen);
		cloud += w.g * seen;
	}
	// More milk where the eye looks through more of the cell.
	float through = mix(1.0, 0.55, v_thick) / facing;
	float milky = clamp(milk * (0.22 * cloud * through + 0.85 * fibres), 0.0, 0.88);

	ALBEDO = mix(opal * 0.03, milk_color, milky);
	EMISSION = behind * tint * (1.0 - sheen * 0.6) * (1.0 - milky) + opal * opal_gain * (0.03 + sheen * 0.9);
	ROUGHNESS = 0.04 + 0.08 * (1.0 - fres);
	SPECULAR = 0.9;
	METALLIC = 0.0;
	RIM = 0.4;
	RIM_TINT = 0.6;
	ALPHA = 1.0;
}
