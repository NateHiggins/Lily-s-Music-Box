shader_type spatial;
render_mode unshaded, cull_back;

#include "res://shaders/dream_corruption_layers.gdshaderinc"

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
uniform float tissue_cell_scale : hint_range(0.25, 8.0) = 2.15;
uniform float tissue_fold_scale : hint_range(0.25, 8.0) = 1.35;
uniform float tissue_transmission : hint_range(0.0, 2.0) = 0.72;
uniform float wet_specular_gain : hint_range(0.0, 3.0) = 1.15;
uniform float gold_vessel_width : hint_range(0.72, 0.98) = 0.925;

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
	// THREE MATERIAL LAYERS, ONE SURFACE.  The include supplies masks rather
	// than a finished colour so later breach and phase shaders can share the
	// same anatomy without inheriting this fragment() or adding overdraw.
	vec3 tissue_p = v_world * vec3(tissue_cell_scale,
			tissue_cell_scale * 0.78, tissue_cell_scale);
	float tissue_phase = gene_phase + v_gene.g * 0.73 + motion_phase * 0.11;
	float cells = dream_corruption_cells(tissue_p, TIME, tissue_phase);
	float folds = dream_corruption_folds(v_world * tissue_fold_scale, TIME,
			tissue_phase);
	float vein = dream_corruption_vessels(tissue_p * 0.58, tissue_phase,
			gold_vessel_width);
	float wetfilm = dream_corruption_wetfilm(tissue_p, TIME, tissue_phase);

	vec3 deep_plum = vec3(0.042, 0.009, 0.030);
	vec3 bruise_violet = vec3(0.090, 0.022, 0.072);
	vec3 rose_tissue = vec3(0.235, 0.050, 0.088);
	vec3 tissue_colour = mix(deep_plum, bruise_violet,
			0.22 + cells * 0.58);
	// Cell interiors and fold valleys differ by almost a stop.  The earlier
	// pass varied only hue and read as one flat magenta polygon at room scale.
	tissue_colour *= 0.52 + cells * 0.62 + folds * 0.16;
	// Thickness is inferred from a grazing view and fold crests.  It never
	// becomes a light source; it is a rose tint inside the lamp response.
	float grazing = pow(1.0 - clamp(abs(dot(n, view_dir)), 0.0, 1.0), 2.1);
	tissue_colour = mix(tissue_colour, rose_tissue,
			clamp((grazing * 0.48 + folds * 0.20) * tissue_transmission,
			0.0, 0.58));
	float wet_highlight = pow(max(dot(n, half_dir), 0.0),
			mix(26.0, 96.0, wetfilm));
	vec3 living_tissue = tissue_colour * (0.46 + diffuse * 1.18)
			+ vec3(1.0, 0.48, 0.55) * wet_highlight * wetfilm
			* wet_specular_gain * 0.34
			+ mix(warm_gold, pale_leaf, vein * 0.46) * vein
			* (0.38 + diffuse * 0.44 + specular * 0.96);
	reflected = mix(reflected, living_tissue, clamp(organic_mix, 0.0, 1.0));

	float eye_shell = smoothstep(0.34, 0.60, v_gene.b)
			* (1.0 - smoothstep(0.80, 0.96, v_gene.b));
	float pupil = smoothstep(0.82, 0.98, v_gene.b);
	reflected = mix(reflected, warm_gold * (0.34 + diffuse * 0.52)
			+ pale_leaf * specular * 1.10, eye_shell);
	reflected = mix(reflected, vec3(0.006, 0.002, 0.004), pupil);

	// Not enough to light the room or reveal its architecture. It is a local
	// biological afterglow: wine-black tissue, dim ochre eyes, black pupils.
	// ACES crushes the earlier 0.05-linear wine to the first display code
	// values; it technically existed and was visually absent.  This is the
	// same bounded luminance the original dark-live proof needed, but shifted
	// away from neon magenta into blood/plum so it reads as matter, not light.
	vec3 dormant_tissue = mix(vec3(0.22, 0.025, 0.11),
			vec3(0.34, 0.055, 0.22), 0.12 + cells * 0.42)
			* (0.45 + cells * 0.55 + folds * 0.20);
	vec3 dormant = mix(vec3(0.16, 0.045, 0.012), dormant_tissue,
			clamp(organic_mix, 0.0, 1.0));
	dormant = mix(dormant, vec3(0.54, 0.25, 0.035), eye_shell);
	dormant = mix(dormant, vec3(0.025, 0.002, 0.008), pupil);
	vec3 dark_body = dormant * max(0.0, dark_glow);
	vec3 lit_body = reflected * awake * 2.45;
	ALBEDO = dark_body * mix(1.0, 1.80, clamp(organic_mix, 0.0, 1.0))
			+ lit_body;
	// This is the owner's explicit exception to the old zero-emission rule:
	// a local afterglow that reveals the moving limb but cannot reveal the
	// architecture around it. The lamp response still outweighs it several
	// times over and receives only a trace of bloom support.
	// Compatibility + ACES compress this deliberately dark linear value very
	// aggressively.  The multiplier affects only the organism's own pixels:
	// it cannot cast light onto the room, so raising it restores the ruled
	// silhouette without inventing a second practical or waking the gold.
	EMISSION = dark_body * 0.55 + lit_body * 0.035;
}
