shader_type spatial;
render_mode cull_back, depth_draw_always, diffuse_burley, specular_schlick_ggx;

instance uniform int process_state = 0;
instance uniform float process_phase = 0.0;
instance uniform int illumination_mode = 0;
varying vec3 p_local;

float hash31(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }

void vertex() {
	p_local=VERTEX;
	float lobe=.105*sin(VERTEX.x*3.1+VERTEX.z*1.7)+.068*sin(VERTEX.y*4.3-VERTEX.z*2.1);
	lobe+=.19*pow(max(VERTEX.x,0.0),3.0)*(1.0-VERTEX.y*VERTEX.y);
	lobe+=.11*pow(max(-VERTEX.z,0.0),4.0)*(1.0-VERTEX.x*VERTEX.x);
	float contraction=process_state==3 ? .060*sin(VERTEX.x*7.0+VERTEX.z*5.0+process_phase) : 0.0;
	VERTEX+=NORMAL*(lobe+contraction);
}

void fragment() {
	vec3 n=normalize(NORMAL); float facing=clamp(abs(dot(n,normalize(VIEW))),0.0,1.0); float rim=pow(1.0-facing,2.25);
	float proteins=pow(hash31(floor(p_local*10.0)),5.0); float fold=.5+.5*sin(p_local.x*14.0+p_local.z*9.0+proteins*2.0);
	vec3 pearl=mix(vec3(.16,.18,.165),vec3(.29,.31,.28),proteins*.26);
	vec3 thin_film=mix(vec3(.04,.075,.082),vec3(.105,.052,.025),fold);
	pearl+=thin_film*rim*(.32+(illumination_mode==2 ? .78 : .20));
	if (process_state==3) {
		float strain=pow(.5+.5*sin(dot(p_local,vec3(11.0,5.0,8.0))+process_phase),12.0)*rim;
		pearl=mix(pearl,pearl*vec3(.68,.82,1.02)+vec3(.055,.028,.008),strain*.68);
	}
	ALBEDO=pearl; ROUGHNESS=mix(.42,.20,rim)*(1.0-proteins*.12); SPECULAR=.24;
	// Local thickness/protein/fold variation prevents aquarium-glass uniformity.
	ALPHA=clamp(.035+rim*.44+proteins*.11+(1.0-facing)*fold*.065,.028,.66);
}
