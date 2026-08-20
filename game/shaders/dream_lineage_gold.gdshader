shader_type spatial;
render_mode unshaded, cull_back;

// THE BODY'S OWN GOLD, LIT ANALYTICALLY BY THE SERVICE LAMP.
//
// Owner override 2026-08-20: the body remains faintly present in darkness.
// The low term is deliberately wine-black and far below the lamp response;
// it is enough to show that motion and danger did not switch off with the
// tool. The analytic gold pass is still the dominant read. It is necessary
// because the service SpotLight3D is almost co-located with the eye: on a thin
// suspended knot the object and its cast shadow align, and ordinary Forward+
// shading reads the whole organism as a black cut-out against the bright
// ceiling behind it. The architecture already evaluates this same lamp in its
// own shader for the same reason.

uniform vec3 lamp_origin = vec3(0.0);
uniform vec3 lamp_splash = vec3(0.0);
uniform vec3 lamp_dir = vec3(0.0, 0.0, -1.0);
uniform float lamp_reach = 8.5;
uniform float lamp_cos_outer = 0.766;
uniform float lamp_energy = 0.0;

// DreamMazeRoot binds the shared field to every ShaderMaterial. The lineage
// does not grow from it in this slice, but exposed ancestry returns a little
// more colour than untouched ancestry. The lamp is still a hard gate.
uniform sampler3D exposure_tex : filter_linear, repeat_enable,
		hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;

uniform float gene_phase = 0.0;
uniform float dark_glow = 0.018;
uniform float motion_gain = 0.0;
uniform float motion_hz = 0.13;
uniform float motion_phase = 0.0;
uniform float organic_mix = 0.0;

varying vec3 v_world;
varying vec3 v_normal;
varying vec4 v_gene;


void vertex() {
	// Red is flex, green is a deterministic per-tendril phase, blue names
	// tissue / golden eye / pupil. Doorway joins in the lineage mesh carry
	// zero flex, while hazard tendrils spend the full bounded 45 mm sway.
	float flex = COLOR.r;
	float phase = COLOR.g * 6.28318530718 + gene_phase + motion_phase;
	float slow = TIME * 6.28318530718 * motion_hz;
	VERTEX.x += sin(slow + phase + VERTEX.y * 1.7) * 0.045
			* flex * motion_gain;
	VERTEX.z += cos(slow * 0.83 + phase + VERTEX.x * 1.3) * 0.032
			* flex * motion_gain;
	VERTEX += NORMAL * sin(slow * 0.55 + phase + VERTEX.y * 2.1) * 0.010
			* flex * motion_gain;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_gene = COLOR;
}


void fragment() {
	vec3 to_fragment = v_world - lamp_origin;
	float distance_m = length(to_fragment);
	vec3 ray = distance_m > 0.0001
			? to_fragment / distance_m : vec3(0.0, 0.0, -1.0);
	float cone = smoothstep(lamp_cos_outer,
			mix(lamp_cos_outer, 1.0, 0.18), dot(ray, lamp_dir));
	float reach = pow(1.0 - clamp(distance_m / max(0.5, lamp_reach),
			0.0, 1.0), 0.62);
	float awake = cone * reach * clamp(lamp_energy, 0.0, 1.35);

	vec3 n = normalize(v_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	// A five-sided tube is deliberately faceted. Face the shading normal to
	// the viewer on the visible side so a winding transition in the knot does
	// not turn one entire loop black.
	if (dot(n, view_dir) < 0.0) {
		n = -n;
	}
	vec3 light_dir = normalize(lamp_origin - v_world);
	float diffuse = 0.18 + 0.82 * max(dot(n, light_dir), 0.0);
	vec3 half_dir = normalize(light_dir + view_dir);
	float specular = pow(max(dot(n, half_dir), 0.0), 38.0);

	float ex_y = clamp(v_world.y / max(0.001, exposure_height),
			0.0625, 0.9375);
	float exposed = texture(exposure_tex, vec3(v_world.x / exposure_extent,
			v_world.z / exposure_extent, ex_y)).r;
	float hammered = 0.78 + 0.22 * sin((v_world.x + v_world.z) * 31.0
			+ v_world.y * 19.0 + gene_phase);
	vec3 old_gold = vec3(0.10, 0.055, 0.012);
	vec3 warm_gold = vec3(0.72, 0.40, 0.09);
	vec3 pale_leaf = vec3(1.08, 0.82, 0.38);
	vec3 alloy = mix(old_gold, warm_gold,
			clamp(0.42 + exposed * 0.48 + hammered * 0.20, 0.0, 1.0));
	vec3 reflected = alloy * diffuse * (0.85 + hammered * 0.22)
			+ pale_leaf * specular * 1.15;
	// Hazard growth is the living underside of the architecture, not a brass
	// pipe. In the beam its wine-dark tissue remains visible between thin,
	// irregular gold veins. Lineage frames leave organic_mix at zero and keep
	// the older antique-alloy reading.
	float vein_a = sin(v_world.y * 17.0 + v_world.x * 11.0
			- v_world.z * 13.0 + v_gene.g * 17.0 + gene_phase);
	float vein_b = sin(v_world.y * 37.0 - v_world.x * 23.0
			+ v_world.z * 29.0 - v_gene.g * 9.0);
	float vein_c = sin((v_world.x + v_world.z) * 31.0
			+ v_world.y * 7.0 + gene_phase * 1.7);
	float vein_noise = 0.5 + 0.5 * (vein_a * 0.52
			+ vein_b * 0.31 + vein_c * 0.17);
	float vein = smoothstep(0.70, 0.91, vein_noise);
	vec3 living_tissue = vec3(0.020, 0.001, 0.045)
			* (0.72 + diffuse * 0.88)
			+ mix(warm_gold, pale_leaf, vein * 0.46) * vein
			* (0.42 + specular * 0.98);
	reflected = mix(reflected, living_tissue, clamp(organic_mix, 0.0, 1.0));

	float eye_shell = smoothstep(0.34, 0.60, v_gene.b)
			* (1.0 - smoothstep(0.80, 0.96, v_gene.b));
	float pupil = smoothstep(0.82, 0.98, v_gene.b);
	reflected = mix(reflected, warm_gold * (0.34 + diffuse * 0.52)
			+ pale_leaf * specular * 1.10, eye_shell);
	reflected = mix(reflected, vec3(0.006, 0.002, 0.004), pupil);

	// Not enough to light the room or reveal its architecture. It is a local
	// biological afterglow: wine-black tissue, dim ochre eyes, black pupils.
	vec3 dormant = mix(vec3(0.22, 0.006, 0.20),
			vec3(0.34, 0.025, 0.24), hammered * 0.32);
	dormant = mix(dormant, vec3(0.54, 0.25, 0.035), eye_shell);
	dormant = mix(dormant, vec3(0.025, 0.002, 0.008), pupil);
	vec3 dark_body = dormant * max(0.0, dark_glow);
	vec3 lit_body = reflected * awake * 2.80;
	ALBEDO = dark_body + lit_body;
	// This is the owner's explicit exception to the old zero-emission rule:
	// a local afterglow that reveals the moving limb but cannot reveal the
	// architecture around it. The lamp response still outweighs it several
	// times over and receives only a trace of bloom support.
	EMISSION = dark_body * 0.95 + lit_body * 0.08;
}
