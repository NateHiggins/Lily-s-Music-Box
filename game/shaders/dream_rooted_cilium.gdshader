shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 root_color : source_color = vec3(.25,.25,.22);
uniform vec3 shaft_color : source_color = vec3(.62,.61,.54);
uniform vec3 cargo_color : source_color = vec3(.42,.48,.43);
uniform vec4 cellular_state_a = vec4(.5,0.,1.,0.);
uniform vec4 cellular_state_b = vec4(0.,.5,0.,0.);
uniform vec4 cellular_state_c = vec4(0.);
uniform float cellular_time = 0.0;

varying float along;
varying float cargo;

void vertex() {
	along = UV.y;
	float phase = INSTANCE_CUSTOM.x * 6.28318;
	float function_kind = INSTANCE_CUSTOM.y;
	float direction = mix(-1.0, 1.0, step(.5, cellular_state_b.x + INSTANCE_CUSTOM.z));
	float wave = sin(cellular_time * (2.4 + function_kind) + phase - along * 2.2);
	float disorder = cellular_state_c.x * sin(cellular_time * .37 + phase * 4.0);
	float withdraw = max(cellular_state_b.w, cellular_state_c.y);
	VERTEX.x += along * along * (wave * .018 * (1.0 - withdraw) + disorder * .022);
	VERTEX.y *= 1.0 - withdraw * .78;
	cargo = pow(max(0.0, sin(along * 18.0 - cellular_time * direction * 4.0 + phase)), 22.0)
		* cellular_state_a.x * (1.0 - cellular_state_c.x);
}

void fragment() {
	float basal = 1.0 - smoothstep(.08,.24,along);
	float transition = smoothstep(.08,.16,along) * (1.0 - smoothstep(.18,.28,along));
	float tip = smoothstep(.86,.98,along);
	ALBEDO = mix(root_color, shaft_color, smoothstep(.10,.35,along)) + cargo_color * cargo * .55;
	float phase_edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	ALBEDO += cargo_color * transition * .12 + vec3(.34,.33,.27) * tip + vec3(.12) * phase_edge;
	ROUGHNESS = mix(.72,.48,along);
	EMISSION = cargo_color * (cargo * .16 + transition * .025) * (1.0 - cellular_state_c.y);
}
