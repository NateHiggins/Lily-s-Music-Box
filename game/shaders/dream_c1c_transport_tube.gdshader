shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

instance uniform float optical_time=0.0;
instance uniform float lamp_intensity=0.0;
instance uniform vec3 lamp_spectrum=vec3(1.0,.82,.58);
instance uniform float flicker_amplitude=0.0;
instance uniform float optical_lag=0.0;
instance uniform float ether_component=0.0;
instance uniform float activity=0.0;
instance uniform float flicker_phase=0.0;
instance uniform int optical_regime=1;
varying vec3 p_local;

void vertex(){p_local=VERTEX;}
void fragment(){
	float facing=abs(dot(normalize(NORMAL),normalize(VIEW))); float rim=pow(1.0-facing,2.0);
	float flow=.5+.5*sin(p_local.x*9.0+p_local.y*5.0-optical_time*.55);
	float arrival=exp(-abs(flicker_phase-(.31+optical_lag*.14))/.12)*flicker_amplitude;
	vec3 tissue=mix(vec3(.045,.09,.075),vec3(.10,.16,.105),flow*.35);
	tissue+=lamp_spectrum*lamp_intensity*flow*.018+vec3(.025,.045,.055)*arrival;
	ALBEDO=tissue; ROUGHNESS=.58; SPECULAR=.06;
	SSS_STRENGTH=.18; SSS_TRANSMITTANCE_COLOR=vec4(tissue,1.0); SSS_TRANSMITTANCE_DEPTH=.24; SSS_TRANSMITTANCE_BOOST=.18;
	BACKLIGHT=tissue*(.08+.12*lamp_intensity);
	ALPHA=clamp(.065+rim*.31+flow*.025,.055,.42);
}
