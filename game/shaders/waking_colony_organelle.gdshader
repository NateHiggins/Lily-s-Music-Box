shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE WAKING COLONY'S ORGANELLES. Disparate on purpose: each region has its
// own substance, its own small motion and a faint opal of its own, so seen
// through the lensing membrane the cell reads as a crowded, working interior
// rather than one material. Region and phase come from the Blender build's
// Anatomy color (B region, G phase); the GDScript owner streams each
// organelle around the cell (cyclosis), this shader moves its surface.

uniform float cell_time = 0.0;
uniform float region = 1.0;          // set per material: 1 nucleus .. 6 filament
uniform vec3 base_color : source_color = vec3(0.6, 0.2, 0.4);
uniform vec3 glow_color : source_color = vec3(0.9, 0.5, 1.0);
uniform float glow = 0.2;
uniform float glassy = 0.0;          // vacuoles: clear and reflective

varying float v_phase;
varying vec3 v_local;

void vertex() {
	v_phase = COLOR.g;
	v_local = VERTEX;
	float t = cell_time + v_phase * 17.0;
	vec3 wobble = vec3(0.0);
	if (region < 1.5) {
		// Nucleus: a slow, uneven heave.
		wobble = NORMAL * 0.003 * sin(t * 0.8 + VERTEX.y * 60.0) * sin(t * 0.53 + VERTEX.x * 41.0);
	} else if (region < 3.5) {
		// Nucleolus / vacuoles: breathing.
		wobble = NORMAL * 0.0025 * sin(t * 1.4 + v_phase * 6.0);
	} else if (region < 4.5) {
		// Mitochondria: a peristaltic ripple running along the rod.
		wobble = NORMAL * 0.0012 * sin(t * 3.0 - VERTEX.z * 260.0);
	} else if (region < 5.5) {
		// Granules: Brownian jitter, bounded.
		wobble = vec3(sin(t * 5.1 + VERTEX.x * 900.0), sin(t * 4.3 + VERTEX.y * 870.0), sin(t * 4.7 + VERTEX.z * 930.0)) * 0.0012;
	} else {
		// Filaments: a slow travelling flex.
		wobble = vec3(0.0, sin(t * 1.1 + VERTEX.x * 40.0) * 0.003, 0.0);
	}
	VERTEX += wobble;
}

void fragment() {
	float cos_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - cos_v, 2.5);
	float bands = 0.5 + 0.5 * sin(v_local.x * 180.0 + v_local.y * 140.0 + cell_time * 0.4 + v_phase * 9.0);
	vec3 opal = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + fres * 1.3 + bands * 0.25));
	ALBEDO = mix(base_color, base_color * 0.4 + opal * 0.25, glassy);
	ROUGHNESS = mix(0.42, 0.06, glassy);
	SPECULAR = mix(0.5, 0.9, glassy);
	SSS_STRENGTH = mix(0.55, 0.1, glassy);
	float pulse = 0.5 + 0.5 * sin(cell_time * 1.7 + v_phase * 6.2831853);
	EMISSION = glow_color * glow * (0.35 + 0.65 * pulse) + opal * fres * (0.25 + glassy * 0.6);
	BACKLIGHT = base_color * 0.6;
}
