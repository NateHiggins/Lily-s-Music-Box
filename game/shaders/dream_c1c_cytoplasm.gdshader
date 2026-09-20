shader_type spatial;
render_mode blend_mix, cull_back, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

instance uniform float optical_time = 0.0;
instance uniform float lamp_intensity = 0.0;
instance uniform vec3 lamp_spectrum = vec3(1.0, .82, .58);
instance uniform float flicker_amplitude = 0.0;
instance uniform float optical_lag = 0.0;
instance uniform float ether_component = 0.0;
instance uniform float flicker_phase = 0.0;
instance uniform int optical_regime = 1;
instance uniform vec3 packet_position = vec3(2.0);
varying vec3 p_local;

float hash31(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float value_noise(vec3 p) {
	vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex() { p_local=VERTEX; }
void fragment() {
	vec3 advect=p_local*3.1+vec3(-optical_time*.035,optical_time*.018,optical_time*.011);
	float broad=value_noise(advect)+.45*value_noise(advect*2.17+5.3);
	float current=pow(.5+.5*sin(p_local.x*3.3+sin(p_local.z*2.1)-optical_time*.13),5.0);
	float wake=exp(-length(p_local-packet_position)*5.5);
	float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
	vec3 base=mix(vec3(.135,.155,.105),vec3(.23,.205,.115),broad*.58);
	base+=vec3(.035,.055,.045)*current+vec3(.015,.03,.055)*wake;
	base=mix(base,base*lamp_spectrum,.13*lamp_intensity);
	base+=vec3(.035,.018,.055)*ether_component*current*(1.0-facing);
	ALBEDO=base; ROUGHNESS=.88; SPECULAR=.035;
	SSS_STRENGTH=.35; SSS_TRANSMITTANCE_COLOR=vec4(base,1.0);
	SSS_TRANSMITTANCE_DEPTH=.56; SSS_TRANSMITTANCE_BOOST=.28;
	BACKLIGHT=base*(.12+.18*lamp_intensity)*(1.0-broad*.22);
	float lag_wave=exp(-abs(flicker_phase-(.22+optical_lag))/.11)*flicker_amplitude;
	ALPHA=clamp(.018+broad*.052+current*.018+wake*.028+(1.0-facing)*.014+lag_wave*.018,.012,.12);
}
