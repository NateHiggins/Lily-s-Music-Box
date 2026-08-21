shader_type spatial;
render_mode unshaded, cull_back;

#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_phase_transition.gdshaderinc"
#include "res://shaders/dream_irradiance.gdshaderinc"
#include "res://shaders/dream_incarnation.gdshaderinc"

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

// DreamMazeRoot binds the shared field to every ShaderMaterial. R5 makes this
// the sole owner of rupture reveal and tissue-to-gold transmutation. The live
// lamp still wakes specular motion; it no longer decides whether the wound
// exists.
uniform sampler3D exposure_tex : filter_linear, repeat_enable,
		hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;
uniform vec4 phase_stage_thresholds = vec4(0.10, 0.34, 0.48, 0.78);
uniform vec2 phase_gold_thresholds = vec2(0.70, 0.92);
uniform float phase_warp_max_uv : hint_range(0.0, 0.12) = 0.085;
uniform float phase_gold_afterglow : hint_range(0.0, 0.35) = 0.16;
// R6 binds one shared-World3D camera. The feed is composited only on the
// existing aperture class and only after the same durable field reaches its
// high state. Depth remains zero because that camera excludes this surface.
uniform sampler2D portal_view : source_color, filter_linear;
uniform float portal_active : hint_range(0.0, 1.0) = 0.0;
uniform vec2 portal_phase_thresholds = vec2(0.88, 0.98);
// 1 isolates the portal id/coverage; 2 reports the sole permitted depth zero.
uniform int portal_debug_view : hint_range(0, 2) = 0;
// The ruled capture presentation closes every authored eye before the final
// central view disappears. One uniform moves all eye vertices in the existing
// batch; no lid node or draw is created for the cinematic.
uniform float embrace_amount : hint_range(0.0, 1.0) = 0.0;
// How much of each intrusion limb currently exists, 0 retracted .. 1 full
// crossing. Pushed by DreamMazeRoot from the SAME durable-field sample that
// drives the reflected gold light, rather than sampled here from
// exposure_tex, so the CPU's embrace-proximity evaluation and this vertex
// stage can never disagree about how much limb is real. Beyond the grown
// fraction the tube collapses to a hair-fine filament instead of vanishing:
// nothing pops when exposure rises, and the filament is the brief's own
// "running ahead of the main mass".
uniform float intrusion_reach : hint_range(0.0, 1.0) = 0.0;

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
uniform int breach_debug_view : hint_range(0, 2) = 0;
// 1 shows infection/rupture/gold, 2 isolates the bounded aperture warp field.
uniform int phase_debug_view : hint_range(0, 2) = 0;

varying vec3 v_world;
varying vec3 v_normal;
varying vec4 v_gene;
// x=eye flag, y=direct-camera weight, z=resting openness,
// w=authored gaze target class. Individual eye centers and frames remain
// vertex-only: the family costs attributes and triangles, not another draw.
varying vec4 v_eye_state;
// The aperture shares the body draw, but its one flat face needs a local
// frame so the fragment shader can look sideways down an impossible tunnel.
// x=breach flag, y/z=authored half extents, w=seeded phase.
varying vec4 v_breach_state;
varying vec3 v_breach_center;
varying vec3 v_breach_side;
varying vec3 v_breach_up;
varying vec3 v_breach_normal;
varying float v_anatomy_class;


void vertex() {
	// Red is flex, green is a deterministic per-tendril phase, blue names
	// tissue / golden eye / pupil. Doorway joins in the lineage mesh carry
	// zero flex, while hazard tendrils spend the full bounded 45 mm sway.
	float flex = COLOR.r;
	float phase = COLOR.g * 6.28318530718 + gene_phase + motion_phase;
	float slow = TIME * 6.28318530718 * motion_hz;
	float anatomy_class = CUSTOM0.a;
	// Normalised class ids survive every backend's vertex-attribute path:
	// 0 body, .25 eye, .375 intrusion limb, .50 false-depth face,
	// .625 living rim, .75 plaster, 1.0 timber lath. The eye window is
	// +-0.10 and every other window +-0.045, so .375 collides with nothing.
	float eye_flag = 1.0 - step(0.10, abs(anatomy_class - 0.25));
	float limb_flag = 1.0 - step(0.045, abs(anatomy_class - 0.375));
	float breach_flag = 1.0 - step(0.045, abs(anatomy_class - 0.50));
	float rim_flag = 1.0 - step(0.045, abs(anatomy_class - 0.625));
	float plaster_flag = 1.0 - step(0.045, abs(anatomy_class - 0.75));
	float lath_flag = 1.0 - step(0.045, abs(anatomy_class - 1.0));
	float breach_part = max(max(breach_flag, rim_flag),
			max(plaster_flag, lath_flag));
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
		float aperture = max(0.025, CUSTOM3.y * (1.0 - blink * 0.94)
				* (1.0 - embrace_amount * 0.975));
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
	if (limb_flag > 0.5) {
		// THE LIMB GROWS OUT OF THE RECORD, NOT OUT OF THE BEAM. CUSTOM3.a is
		// this ring's 0..1 station along the limb; the uniform says how much
		// of the limb the durable field has earned. Grown rings keep their
		// authored thickness; beyond the front the same centerline survives
		// at six percent radius -- torso-thick down to hair-fine, exactly the
		// plate's anatomy -- so the limb visibly EXTENDS as exposure rises
		// and never pops or retracts with the lamp.
		float along = CUSTOM3.a;
		vec3 ring_center = CUSTOM0.xyz;
		float grown = 1.0 - smoothstep(intrusion_reach,
				intrusion_reach + 0.07, along);
		float thickness = mix(0.06, 1.0, grown);
		VERTEX = ring_center + (VERTEX - ring_center) * thickness;
		// Slow reach-scaled sway, largest at the free end. Both terms sit far
		// under the photosensitivity bar: motion_hz is 0.13, so the fastest
		// component here completes a cycle in about eleven seconds.
		vec3 sway_dir = normalize(CUSTOM1.xyz);
		float limb_phase = CUSTOM1.a * 6.28318530718;
		float amp = CUSTOM2.a * along * intrusion_reach;
		VERTEX += sway_dir * sin(slow * 0.70 + limb_phase + along * 2.7)
				* amp;
		VERTEX.y += cos(slow * 0.47 + limb_phase * 1.3 + along * 3.4)
				* amp * 0.45;
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
	v_breach_state = vec4(breach_part, CUSTOM1.a, CUSTOM2.a, CUSTOM3.a);
	v_breach_center = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
	v_breach_side = breach_part > 0.5
			? normalize((MODEL_MATRIX * vec4(CUSTOM1.xyz, 0.0)).xyz)
			: vec3(1.0, 0.0, 0.0);
	v_breach_up = breach_part > 0.5
			? normalize((MODEL_MATRIX * vec4(CUSTOM2.xyz, 0.0)).xyz)
			: vec3(0.0, 1.0, 0.0);
	v_breach_normal = breach_part > 0.5
			? normalize((MODEL_MATRIX * vec4(CUSTOM3.xyz, 0.0)).xyz)
			: vec3(0.0, 0.0, 1.0);
	v_anatomy_class = anatomy_class;
}


float breach_rect_ring(vec2 p, float radius, float width) {
	float box = max(abs(p.x) * 0.82, abs(p.y));
	return 1.0 - smoothstep(width, width + 0.030, abs(box - radius));
}


// x=golden frame lattice, y=vanishing sclera, z=vanishing pupil,
// w=diagnostic recession band. Nine bounded taps make a wall-thin face read
// tens of metres deep; no camera, SubViewport or second room is involved.
vec4 breach_interior(vec2 uv, vec2 view_shift, float phase) {
	vec2 vanishing = view_shift * 0.16
			+ vec2(cos(phase * 6.28318530718),
			sin(phase * 6.28318530718)) * 0.035;
	float lattice = 0.0;
	float depth_band = 0.0;
	for (int layer = 0; layer < 9; layer++) {
		float z = (float(layer) + 0.72) / 9.0;
		float scale = 1.0 + z * 6.4;
		vec2 p = (uv - vanishing * z) * scale;
		// Alternating quarter-turn offsets make the nested rectangles a broken
		// Greek-key mechanism instead of a stack of polite picture frames.
		float quarter = mod(float(layer), 2.0) * 0.085 - 0.0425;
		p += vec2(sign(p.y), -sign(p.x)) * quarter;
		float frame = breach_rect_ring(p, 0.79, 0.014 + z * 0.005);
		float key = step(0.34, abs(sin((p.x + p.y) * 9.0
				+ phase * 6.28318530718 + float(layer) * 1.7)));
		frame *= mix(0.48, 1.0, key);
		float near_weight = 1.0 - z * 0.62;
		lattice = max(lattice, frame * near_weight);
		depth_band = max(depth_band, frame * z);
	}
	// Fine cables cross several apparent depths. They bend independently of
	// the architectural lattice, turning a decorative tunnel into a dense
	// reproductive knot without spending a strand of real geometry.
	float cable_a = 1.0 - smoothstep(0.020, 0.046,
			abs(uv.x - sin(uv.y * 5.4 + phase * 8.0) * 0.17));
	float cable_b = 1.0 - smoothstep(0.018, 0.042,
			abs(uv.y + cos(uv.x * 6.2 - phase * 6.0) * 0.13));
	lattice = max(lattice, max(cable_a, cable_b) * 0.56);
	depth_band = max(depth_band, max(cable_a, cable_b) * 0.72);
	vec2 eye_p = (uv - vanishing) * vec2(5.2,
			8.6 / max(0.035, 1.0 - embrace_amount * 0.965));
	float eye_d = length(eye_p);
	float sclera = 1.0 - smoothstep(0.78, 0.96, eye_d);
	float pupil = 1.0 - smoothstep(0.21, 0.34, eye_d);
	return vec4(clamp(lattice, 0.0, 1.0), sclera, pupil,
			clamp(depth_band, 0.0, 1.0));
}


void fragment() {
	vec3 n = normalize(v_normal);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	// A five-sided tube is deliberately faceted. Face the shading normal to
	// the viewer on the visible side so a winding transition in the knot does
	// not turn one entire loop black.
	if (dot(n, view_dir) < 0.0) {
		n = -n;
	}
	float irradiance_y = clamp(v_world.y / max(0.001, exposure_height),
			0.0625, 0.9375);
	vec2 irradiance_field = texture(exposure_tex, vec3(
			v_world.x / exposure_extent, v_world.z / exposure_extent,
			irradiance_y)).rg;
	vec4 irradiance = dream_irradiance(v_world, n, irradiance_field,
			lamp_origin);
	float awake = irradiance.w;
	vec4 incarnation_tissue = dream_incarnation_surface(v_world,
			v_world.xz, irradiance_field.r, awake, awake, 0.0, 0,
			vec4(0.0));
	vec3 light_dir = normalize(lamp_origin - v_world);
	float diffuse = 0.18 + 0.82 * max(dot(n, light_dir), 0.0);
	vec3 half_dir = normalize(light_dir + view_dir);
	float specular = pow(max(dot(n, half_dir), 0.0), 38.0);

	float exposed = irradiance_field.r;
	vec4 phase_state = dream_phase_state(exposed, phase_stage_thresholds,
			phase_gold_thresholds);
	float hammered = 0.78 + 0.22 * sin((v_world.x + v_world.z) * 31.0
			+ v_world.y * 19.0 + gene_phase);
	vec3 old_gold = vec3(0.10, 0.055, 0.012);
	vec3 warm_gold = vec3(0.72, 0.40, 0.09);
	vec3 pale_leaf = vec3(1.08, 0.82, 0.38);
	vec3 alloy = mix(old_gold, warm_gold,
			clamp(0.42 + exposed * 0.48 + hammered * 0.20, 0.0, 1.0));
	vec3 reflected_gold = alloy * diffuse * (0.85 + hammered * 0.22)
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
	if (incarnation_id > 0.5 && incarnation_id < 6.5) {
		tissue_colour = mix(tissue_colour, incarnation_tissue.rgb, 0.72);
	}
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
	// The only licensed R5 phase: the same tissue becomes the same living gold
	// the architecture exposes. It is a continuum, not a second material.
	living_tissue = mix(living_tissue, reflected_gold * 1.08,
			phase_state.z * 0.76);
	vec3 reflected = mix(reflected_gold, living_tissue,
			clamp(organic_mix, 0.0, 1.0));

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
	vec3 cooled_phase_gold = alloy * phase_gold_afterglow
			* (0.72 + hammered * 0.28);
	dormant = mix(dormant, cooled_phase_gold, phase_state.z * 0.72);
	float genome_vein = pow(vein, mix(1.45, 0.70,
			clamp(irradiance_vein_branch * 0.62, 0.0, 1.0)));
	float anatomy_line = clamp(max(genome_vein,
			pow(1.0 - abs(dot(n, view_dir)), 3.0) * 0.72), 0.0, 1.0);
	vec3 neon_anatomy = dream_irradiance_hue(mix(deep_plum,
			warm_gold, genome_vein * 0.42)) * anatomy_line * irradiance.x;
	float genome_pulse = 0.96 + 0.04 * sin(TIME * TAU * 0.07
			/ max(0.25, irradiance_viscosity) + irradiance_pulse_phase);
	vec3 oblique_tissue = dream_irradiance_hue(living_tissue)
			* irradiance.y * (0.28 + genome_vein * 0.54 + wetfilm * 0.18)
			* genome_pulse;
	vec3 dark_body = dormant * max(0.0, dark_glow) * 0.12
			+ neon_anatomy * max(0.0, dark_glow) * 1.85;
	vec3 lit_body = reflected * awake * 2.45;
	ALBEDO = dark_body * mix(1.0, 1.80, clamp(organic_mix, 0.0, 1.0))
			+ lit_body + oblique_tissue;
	// This is the owner's explicit exception to the old zero-emission rule:
	// a local afterglow that reveals the moving limb but cannot reveal the
	// architecture around it. The lamp response still outweighs it several
	// times over and receives only a trace of bloom support.
	// Compatibility + ACES compress this deliberately dark linear value very
	// aggressively.  The multiplier affects only the organism's own pixels:
	// it cannot cast light onto the room, so raising it restores the ruled
	// silhouette without inventing a second practical or waking the gold.
	EMISSION = dark_body * 0.55 + oblique_tissue * 0.12
			+ lit_body * 0.035
			+ cooled_phase_gold * phase_state.z
			* (0.035 + vein * 0.065);

	// ARCHITECTURE TORN INTO THE BODY. Class .75 is shattered plaster/rubble;
	// class 1.0 is exposed lath. They are real geometry but stay dim enough that
	// the wine tissue remains the corruption rather than a clean construction
	// diagram. Class .50 is the one opaque face carrying false interior depth.
	float breach_flag = 1.0 - step(0.045, abs(v_anatomy_class - 0.50));
	float rim_flag = 1.0 - step(0.045, abs(v_anatomy_class - 0.625));
	float plaster_flag = 1.0 - step(0.045, abs(v_anatomy_class - 0.75));
	float lath_flag = 1.0 - step(0.045, abs(v_anatomy_class - 1.0));
	float breach_part = max(max(breach_flag, rim_flag),
			max(plaster_flag, lath_flag));
	vec3 breach_rel = v_world - v_breach_center;
	vec2 breach_uv = vec2(dot(breach_rel, v_breach_side)
			/ max(v_breach_state.y, 0.001),
			dot(breach_rel, v_breach_up) / max(v_breach_state.z, 0.001));
	float reveal_threshold = dream_phase_reveal_threshold(breach_uv, v_world,
			v_breach_state.w);
	if (breach_part > 0.5 && phase_state.y < reveal_threshold) {
		// Ordered material coverage exposes the intact wall already behind the
		// always-submitted wound. No node, mesh or collision ever toggles.
		discard;
	}
	vec3 old_plaster = vec3(0.28, 0.205, 0.145);
	vec3 split_lath = vec3(0.24, 0.095, 0.026);
	vec3 plaster_colour = old_plaster * (0.25 + awake * (0.66 + diffuse));
	plaster_colour += warm_gold * vein * awake * 0.22;
	vec3 lath_colour = split_lath * (0.45 + awake * (0.72 + diffuse * 0.52));
	lath_colour += vec3(0.62, 0.29, 0.055) * awake * specular * 0.28;
	ALBEDO = mix(ALBEDO, plaster_colour, plaster_flag);
	ALBEDO = mix(ALBEDO, lath_colour, lath_flag);
	EMISSION = mix(EMISSION, old_plaster * 0.006, plaster_flag);
	EMISSION = mix(EMISSION, split_lath * 0.008, lath_flag);

	vec4 breach_pattern = vec4(0.0);
	float local_warp_support = 0.0;
	float portal_mix = 0.0;
	vec3 portal_colour = vec3(0.0);
	if (breach_flag > 0.5) {
		// The nine recession taps are paid only on the small aperture face,
		// never across the tentacles and wall grafts sharing this material.
		local_warp_support = (1.0 - smoothstep(0.28, 1.12,
				length(breach_uv))) * phase_state.w;
		breach_uv = dream_phase_bounded_warp(breach_uv, phase_state.w,
				phase_warp_max_uv, v_breach_state.w, TIME);
		float face_view = max(abs(dot(view_dir, v_breach_normal)), 0.16);
		vec2 view_shift = vec2(dot(view_dir, v_breach_side),
				dot(view_dir, v_breach_up)) / face_view;
		breach_pattern = breach_interior(breach_uv, view_shift,
				v_breach_state.w);
		// The irregular triangle fan is the aperture mask. A narrow inner fade
		// preserves the R4 false-depth lattice at the torn edge, so the live
		// room reads as being beyond a wound rather than pasted onto an oval.
		float portal_phase = smoothstep(portal_phase_thresholds.x,
				portal_phase_thresholds.y, exposed) * portal_active;
		float portal_inset = 1.0 - smoothstep(0.82, 1.12,
				length(breach_uv));
		portal_mix = portal_phase * portal_inset;
		if (portal_active > 0.5) {
			vec2 portal_uv = clamp(breach_uv * 0.5 + vec2(0.5),
					vec2(0.002), vec2(0.998));
			// ViewportTexture's image origin is opposite the local wall frame.
			portal_uv.y = 1.0 - portal_uv.y;
			portal_colour = texture(portal_view, portal_uv).rgb;
			// Retain the room's photographed values while biasing the impossible
			// view slightly toward the organism's plum/antique-gold invariant.
			portal_colour *= vec3(0.96, 0.88, 1.03);
		}
	}
	vec3 tunnel_dark = vec3(0.0035, 0.0010, 0.0065)
			+ vec3(0.18, 0.075, 0.012) * breach_pattern.x * 0.24
			+ warm_gold * breach_pattern.x * phase_state.z * 0.16;
	vec3 tunnel_lit = vec3(0.007, 0.002, 0.011)
			+ mix(warm_gold * 0.72, vec3(0.92, 0.62, 0.22),
			breach_pattern.w)
			* breach_pattern.x * awake * 0.68;
	vec3 vanishing_sclera = vec3(0.38, 0.19, 0.045)
			* (0.13 + awake * 1.35);
	tunnel_lit = mix(tunnel_lit, vanishing_sclera,
			breach_pattern.y * (1.0 - breach_pattern.z));
	tunnel_lit = mix(tunnel_lit, vec3(0.001, 0.0002, 0.0012),
			breach_pattern.z);
	ALBEDO = mix(ALBEDO, tunnel_dark + tunnel_lit, breach_flag);
	EMISSION = mix(EMISSION,
			tunnel_dark * 0.46 + tunnel_lit * 0.038, breach_flag);
	ALBEDO = mix(ALBEDO, portal_colour * 0.92,
			portal_mix * breach_flag);
	EMISSION = mix(EMISSION, portal_colour * 0.025,
			portal_mix * breach_flag);

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
	if (breach_debug_view > 0) {
		vec3 debug_colour = vec3(0.003, 0.002, 0.004);
		if (breach_debug_view == 1) {
			debug_colour = mix(debug_colour, vec3(0.10, 0.74, 1.0),
					breach_flag);
			debug_colour = mix(debug_colour, vec3(0.88, 0.70, 0.45),
					plaster_flag);
			debug_colour = mix(debug_colour, vec3(0.55, 0.19, 0.035),
					lath_flag);
		} else if (breach_flag > 0.5) {
			debug_colour = mix(vec3(0.055, 0.015, 0.13),
					vec3(0.12, 0.90, 1.0), breach_pattern.w);
			debug_colour = mix(debug_colour, vec3(1.0, 0.66, 0.08),
					breach_pattern.x);
			debug_colour = mix(debug_colour, vec3(1.0, 0.08, 0.34),
					breach_pattern.y);
		}
		ALBEDO = debug_colour;
		EMISSION = debug_colour * 0.45;
	}
	if (phase_debug_view > 0) {
		vec3 debug_colour = vec3(0.004, 0.003, 0.006);
		if (phase_debug_view == 1) {
			debug_colour = vec3(phase_state.z, phase_state.y, phase_state.x);
		} else {
			debug_colour = vec3(local_warp_support,
					local_warp_support * 0.32, 1.0 - local_warp_support)
					* breach_flag;
		}
		ALBEDO = debug_colour;
		EMISSION = debug_colour * 0.52;
	}
	if (portal_debug_view > 0) {
		vec3 debug_colour = vec3(0.002, 0.002, 0.004);
		if (breach_flag > 0.5) {
			if (portal_debug_view == 1) {
				debug_colour = mix(vec3(0.035, 0.015, 0.075),
						vec3(0.05, 0.92, 1.0), portal_mix);
			} else {
				// Blue is depth zero. No green/yellow/red recursive layers can
				// exist in the R6 renderer or this diagnostic.
				debug_colour = vec3(0.08, 0.20, 0.92) * portal_mix;
			}
		}
		ALBEDO = debug_colour;
		EMISSION = debug_colour * 0.48;
	}
}
