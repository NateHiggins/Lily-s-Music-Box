shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

#include "res://shaders/dream_cellular_surface.gdshaderinc"

uniform vec3 membrane_dark : source_color = vec3(.12,.014,.15);
uniform vec3 membrane_lit : source_color = vec3(.56,.07,.58);
uniform vec3 cytoplasm_color : source_color = vec3(.92,.20,.72);
uniform vec3 signal_color : source_color = vec3(.88,.50,1.0);
uniform vec4 cellular_phenotype = vec4(.78,.48,.88,.42);
uniform vec4 cellular_state_a = vec4(.5,0.,1.,0.);
uniform vec4 cellular_state_b = vec4(0.,.5,0.,0.);
uniform vec4 cellular_state_c = vec4(0.);
uniform float cellular_seed = 0.0;
uniform float cellular_time = 0.0;
uniform float membrane_role = 0.0; // 0 network, 1 heart, 2 cargo/protein
uniform int optics_mode = 0; // 0 native, 1 phase, 2 DIC, 3 backlight, 4 fluorescence

varying vec3 cell_pos;
varying vec3 cell_nrm;

void vertex() {
	cell_pos = VERTEX;
	cell_nrm = NORMAL;
	float breath = cellular_state_b.y * sin(cellular_time * 1.35 + VERTEX.x * 3.0) * .018;
	float pioneer = 1.0 - step(.5, membrane_role);
	float front = smoothstep(.12,.88,UV.y) * cellular_state_a.z;
	VERTEX.xz += NORMAL.xz * pioneer * front * sin(UV.x * 12.0 + cellular_time * .35) * .028;
	VERTEX += NORMAL * breath * (1.0 - cellular_state_c.y);
}

void fragment() {
	vec3 view = normalize(VIEW);
	vec4 membrane = cell_membrane(cell_pos, normalize(cell_nrm), view,
		cellular_seed, cellular_phenotype, cellular_state_a, cellular_state_b,
		cellular_state_c, cellular_time);
	vec3 transport = cell_transport(cell_pos, cellular_seed, cellular_state_a,
		cellular_state_b, cellular_state_c, cellular_time);
	// Opaque, sorting-safe internal physiology: vacuoles displace the apparent
	// cytoplasm while vesicles and filament bundles follow the transport field.
	float vacuoles = smoothstep(.68,.86,cell_value(cell_pos * 5.7 + vec3(cellular_seed,.3,1.7)));
	float vesicles = smoothstep(.91,.975,cell_value(cell_pos * 24.0 - cellular_time * vec3(.18,0.,.11)));
	float filaments = pow(.5 + .5 * sin(cell_pos.x * 31.0 + cell_pos.z * 19.0 + cellular_time), 12.0);
	float domain = membrane.x;
	float thickness = clamp(membrane.y,0.,1.);
	vec3 color = mix(membrane_dark, membrane_lit, .24 + domain * .52 + thickness * .18);
	float pioneer = 1.0 - step(.5, membrane_role);
	float adhesion = smoothstep(.90,.98,cell_value(cell_pos * 19.0 + cellular_seed)) * pioneer;
	color += signal_color * adhesion * cellular_state_a.z * .18;
	color = mix(color, cytoplasm_color, membrane.w * (.38 + cellular_state_a.y * .34));
	color += signal_color * (membrane.z * .22 + transport.x * .65 + transport.y * .18 + transport.z * .45);
	color = mix(color, color * .28, vacuoles * (.48 + .30 * cellular_state_a.x));
	color += cytoplasm_color * vesicles * .38 + signal_color * filaments * transport.x * .22;
	color = mix(color, vec3(.12,.055,.075), cellular_state_c.x * .64 + cellular_state_c.y * .32);
	if (optics_mode == 1) {
		float phase_edge = pow(1.0 - abs(dot(normalize(cell_nrm), view)), 3.0);
		color = mix(vec3(dot(color,vec3(.299,.587,.114))), vec3(.35,.20,.48), phase_edge * .55);
	} else if (optics_mode == 2) {
		float shear = dot(normalize(cell_nrm), normalize(vec3(.72,.18,.66)));
		color = vec3(.35) + vec3(.30,.20,.38) * shear + color * .42;
	} else if (optics_mode == 3) {
		float absorption = clamp(vacuoles * .72 + filaments * .30 + thickness * .22,0.,1.);
		color = mix(vec3(.62,.18,.32), vec3(.045,.004,.07), absorption);
	} else if (optics_mode == 4) {
		color = vec3(.008,.012,.018) + vec3(.15,.95,.68) * vesicles + vec3(.88,.12,1.) * transport.x;
	}
	ALBEDO = color;
	ROUGHNESS = clamp(.62 - membrane.z * .22 + cellular_state_c.x * .28, .20, .92);
	METALLIC = .03 + transport.y * .10;
	SSS_STRENGTH = clamp(.16 + membrane.w * .48 - cellular_state_c.x * .12,0.,.7);
	EMISSION = signal_color * (membrane.z * .12 + transport.x * .30 + transport.z * .22) * (1.0 - cellular_state_c.y);
	if (optics_mode == 3) { BACKLIGHT = vec3(.28,.035,.10) * (1.0 - vacuoles * .72); }
	if (optics_mode == 4) { EMISSION += color * .72; }
	ALPHA = 1.0;
}
