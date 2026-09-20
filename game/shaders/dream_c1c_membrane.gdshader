shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

instance uniform float optical_time = 0.0;
instance uniform float lamp_intensity = 0.0;
instance uniform vec3 lamp_spectrum = vec3(1.0, 0.82, 0.58);
instance uniform float flicker_amplitude = 0.0;
instance uniform float optical_lag = 0.0;
instance uniform float ether_component = 0.0;
instance uniform float flicker_phase = 0.0;
instance uniform int optical_regime = 1;
varying vec3 p_local;

float hash31(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float value_noise(vec3 p) {
	vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex() {
	p_local=VERTEX;
	float broad=.035*sin(VERTEX.x*2.4+VERTEX.z*1.7)+.022*sin(VERTEX.y*4.1-VERTEX.z*2.2);
	float adhered=-.025*smoothstep(-.78,-.35,VERTEX.y)*(1.0-smoothstep(.55,.94,length(VERTEX.xz)));
	VERTEX+=NORMAL*(broad+adhered);
}

void fragment() {
	vec3 n=normalize(NORMAL); vec3 v=normalize(VIEW);
	float facing=clamp(abs(dot(n,v)),0.0,1.0); float rim=pow(1.0-facing,2.1);
	float fold_noise=value_noise(p_local*4.2+vec3(0.0,optical_time*.018,0.0));
	float fold=pow(.5+.5*sin(p_local.x*8.5+p_local.z*6.7+fold_noise*4.0),9.0);
	float compression=smoothstep(-.80,-.48,p_local.y)*(1.0-smoothstep(.62,.96,length(p_local.xz)));
	float phase=sin((1.0-facing)*18.0+fold_noise*5.0+optical_time*.08-optical_lag*2.0)*.5+.5;
	vec3 neutral=mix(vec3(.115,.135,.128),vec3(.19,.205,.185),fold_noise*.45);
	vec3 interference=mix(vec3(.045,.105,.12),vec3(.16,.075,.035),phase);
	vec3 ether=mix(vec3(.035,.06,.08),vec3(.10,.045,.13),phase);
	vec3 color=neutral+interference*(rim*(.38+fold*.62)+compression*.10);
	float arrival=exp(-abs(flicker_phase-.10)/.10)*flicker_amplitude;
	color+=ether*ether_component*rim*fold*.62+interference*arrival*rim*.34;
	color*=mix(vec3(1.0),lamp_spectrum,.10*lamp_intensity);
	ALBEDO=color;
	ROUGHNESS=clamp(.52-rim*.18+fold_noise*.10, .28, .72);
	SPECULAR=.18;
	SSS_STRENGTH=.16;
	SSS_TRANSMITTANCE_COLOR=vec4(mix(vec3(.24,.29,.24),lamp_spectrum,.16),1.0);
	SSS_TRANSMITTANCE_DEPTH=.34;
	SSS_TRANSMITTANCE_BOOST=.24;
	BACKLIGHT=color*(.10+.16*lamp_intensity);
	// The boundary nearly vanishes head-on and returns only at folds, contact,
	// and refractive grazing angles. There is no uniform glass opacity.
	ALPHA=clamp(.003+rim*.22+fold*rim*.12+compression*.045+flicker_amplitude*fold*rim*.025,.002,.38);
}
