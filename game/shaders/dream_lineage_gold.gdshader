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
uniform int eye_debug_view : hint_range(0, 2) = 0;

varying vec3 v_world;
varying vec3 v_normal;
varying vec4 v_gene;
// x=eye flag, y=direct-camera weight, z=resting openness,
// w=authored gaze target class. Individual eye centers and frames remain
// vertex-only: the family costs attributes and triangles, not another draw.
varying vec4 v_eye_state;


void vertex() {
	// Red is flex, green is a deterministic per-tendril phase, blue names
	// tissue / golden eye / pupil. Doorway joins in the lineage mesh carry
	// zero flex, while hazard tendrils spend the full bounded 45 mm sway.
	float flex = COLOR.r;
	float phase = COLOR.g * 6.28318530718 + gene_phase + motion_phase;
	float slow = TIME * 6.28318530718 * motion_hz;
	float eye_flag = step(0.5, CUSTOM0.a);
	if (eye_flag > 0.5) {
		vec3 eye_center = CUSTOM0.xyz;
		vec3 eye_side = normalize(CUSTOM1.xyz);
		vec3 eye_up = normalize(CUSTOM2.xyz);
		float blink_clock = fract(TIME * CUSTOM3.z + CUSTOM3.x);
		// A blink occupies only fourteen percent of a long 14-22 s cycle.
		// Resting aperture remains the dominant authored state; closed eyes do
		// not repeatedly spring open merely to advertise that they animate.
		float blink = smoothstep(0.845, 0.905, blink_clock)
				* (1.0 - smoothstep(0.925, 0.985, blink_clock));
		float aperture = max(0.025, CUSTOM3.y * (1.0 - blink * 0.94));
		float local_y = dot(VERTEX - eye_center, eye_up);
		VERTEX += eye_up * local_y * (aperture - 1.0);

		// Only the one vertex family member whose record says "camera" tracks.
		// Shell/lids stay fixed; iris and pupil slide a bounded fraction of the
		// eye radius along their own seeded local frame.
		float mobile_iris = smoothstep(0.43, 0.92, COLOR.b) * CUSTOM1.a;
		if (mobile_iris > 0.0) {
			vec3 camera_world = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
			vec3 camera_local = (inverse(MODEL_MATRIX)
					* vec4(camera_world, 1.0)).xyz;
			vec3 toward_camera = normalize(camera_local - eye_center);
			float side_look = clamp(dot(toward_camera, eye_side), -0.72, 0.72);
			float up_look = clamp(dot(toward_camera, eye_up), -0.52, 0.52);
			VERTEX += (eye_side * side_look + eye_up * up_look)
					* CUSTOM2.a * 0.28 * mobile_iris;
		}
	}
	VERTEX.x += sin(slow + phase + VERTEX.y * 1.7) * 0.045
			* flex * motion_gain;
	VERTEX.z += cos(slow * 0.83 + phase + VERTEX.x * 1.3) * 0.032
			* flex * motion_gain;
	VERTEX += NORMAL * sin(slow * 0.55 + phase + VERTEX.y * 2.1) * 0.010
			* flex * motion_gain;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_gene = COLOR;
	v_eye_state = vec4(eye_flag, CUSTOM1.a, CUSTOM3.y, CUSTOM3.a);
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

	float eye_sclera = v_eye_state.x * smoothstep(0.22, 0.285, v_gene.b)
			* (1.0 - smoothstep(0.38, 0.52, v_gene.b));
	float eye_shell = v_eye_state.x * smoothstep(0.34, 0.60, v_gene.b)
			* (1.0 - smoothstep(0.80, 0.96, v_gene.b));
	float pupil = v_eye_state.x * smoothstep(0.82, 0.98, v_gene.b);
	reflected = mix(reflected, vec3(0.27, 0.15, 0.045)
			* (0.34 + diffuse * 0.48) + pale_leaf * specular * 0.28,
			eye_sclera);
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
	dormant = mix(dormant, vec3(0.31, 0.17, 0.055), eye_sclera);
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

	// Production diagnosis: view 1 shows resting aperture (ochre to bone) and
	// singles the direct tracker in magenta; view 2 identifies authored gaze
	// classes from root/room through branch-tip to camera. Non-eye anatomy is
	// suppressed so an anchor census can be read in one frame.
	if (eye_debug_view > 0) {
		vec3 debug_colour = vec3(0.002, 0.001, 0.003);
		if (v_eye_state.x > 0.5) {
			if (eye_debug_view == 1) {
				debug_colour = mix(vec3(0.23, 0.055, 0.012),
						vec3(1.0, 0.82, 0.36), v_eye_state.z);
				debug_colour = mix(debug_colour, vec3(1.0, 0.04, 0.46),
						v_eye_state.y);
			} else {
				debug_colour = mix(vec3(0.04, 0.24, 0.58),
						vec3(1.0, 0.16, 0.42), v_eye_state.w);
			}
		}
		ALBEDO = debug_colour;
		EMISSION = debug_colour * 0.45;
	}
}
