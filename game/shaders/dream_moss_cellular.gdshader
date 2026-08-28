shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

#include "res://shaders/dream_cellular_surface.gdshaderinc"

uniform vec3 membrane_dark : source_color = vec3(.075,.008,.105);
uniform vec3 membrane_lit : source_color = vec3(.42,.045,.55);
uniform vec3 cytoplasm_color : source_color = vec3(.92,.20,.72);
uniform vec3 signal_color : source_color = vec3(.88,.50,1.0);
uniform vec4 cellular_phenotype = vec4(.78,.48,.88,.42);
uniform vec4 cellular_state_a = vec4(.5,0.,1.,0.);
uniform vec4 cellular_state_b = vec4(0.,.5,0.,0.);
uniform vec4 cellular_state_c = vec4(0.);
uniform float cellular_seed = 0.0;
uniform float cellular_time = 0.0;
uniform float membrane_role = 0.0; // 0 network, 1 heart, 2 cargo/protein

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
	float domain = membrane.x;
	float thickness = clamp(membrane.y,0.,1.);
	vec3 color = mix(membrane_dark, membrane_lit, .24 + domain * .52 + thickness * .18);
	float pioneer = 1.0 - step(.5, membrane_role);
	float adhesion = smoothstep(.90,.98,cell_value(cell_pos * 19.0 + cellular_seed)) * pioneer;
	color += signal_color * adhesion * cellular_state_a.z * .18;
	color = mix(color, cytoplasm_color, membrane.w * (.38 + cellular_state_a.y * .34));
	color += signal_color * (membrane.z * .22 + transport.x * .65 + transport.y * .18 + transport.z * .45);
	color = mix(color, vec3(.12,.055,.075), cellular_state_c.x * .64 + cellular_state_c.y * .32);
	ALBEDO = color;
	ROUGHNESS = clamp(.62 - membrane.z * .22 + cellular_state_c.x * .28, .20, .92);
	METALLIC = .03 + transport.y * .10;
	SSS_STRENGTH = clamp(.16 + membrane.w * .48 - cellular_state_c.x * .12,0.,.7);
	EMISSION = signal_color * (membrane.z * .12 + transport.x * .30 + transport.z * .22) * (1.0 - cellular_state_c.y);
	ALPHA = 1.0;
}
