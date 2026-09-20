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

float hash31(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
void vertex(){p_local=VERTEX;}
void fragment(){
	vec3 n=normalize(NORMAL); float facing=abs(dot(n,normalize(VIEW))); float rim=pow(1.0-facing,2.0);
	float caustic=pow(.5+.5*sin(p_local.x*14.0+p_local.y*9.0-optical_time*.18-optical_lag*4.0),10.0);
	float content=hash31(floor(p_local*9.0));
	vec3 fluid=mix(vec3(.12,.21,.21),vec3(.24,.34,.27),content*.34);
	float arrival=exp(-abs(flicker_phase-(.38+optical_lag*.12))/.11)*flicker_amplitude;
	fluid+=rim*vec3(.07,.15,.15)+caustic*lamp_spectrum*(.025+.07*lamp_intensity+arrival*.06);
	if(optical_regime==0) fluid+=rim*vec3(.075,.16,.17)+caustic*vec3(.05,.11,.10);
	if(optical_regime==2 || optical_regime==3) fluid*=.68;
	ALBEDO=fluid; ROUGHNESS=.26; SPECULAR=.12;
	SSS_STRENGTH=.10; SSS_TRANSMITTANCE_COLOR=vec4(fluid,1.0);
	SSS_TRANSMITTANCE_DEPTH=.52; SSS_TRANSMITTANCE_BOOST=.32;
	BACKLIGHT=fluid*(.14+.24*lamp_intensity);
	ALPHA=clamp(.055+rim*.29+caustic*.035+(optical_regime==0? .035:0.0),.045,.42);
}
