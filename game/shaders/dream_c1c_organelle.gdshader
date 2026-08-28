shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

uniform int physical_layer = 0; // suspension, fluid, nucleus, storage, network, fiber, gate, packet
instance uniform float optical_time = 0.0;
instance uniform float lamp_intensity = 0.0;
instance uniform vec3 lamp_spectrum = vec3(1.0,.82,.58);
instance uniform float flicker_amplitude = 0.0;
instance uniform float optical_lag = 0.0;
instance uniform float ether_component = 0.0;
instance uniform float activity = 0.0;
instance uniform float flicker_phase = 0.0;
instance uniform int optical_regime = 1;
varying vec3 p_local;

float hash31(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float value_noise(vec3 p) {
	vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex(){ p_local=VERTEX; }
void fragment(){
	vec3 n=normalize(NORMAL); vec3 v=normalize(VIEW); float facing=abs(dot(n,v)); float rim=pow(1.0-facing,2.2);
	float coarse=value_noise(p_local*3.2+vec3(optical_time*.012,0.0,0.0));
	float fine=value_noise(p_local*13.7+3.1);
	float pulse=.5+.5*sin(p_local.x*4.1+p_local.z*2.7-optical_time*.42-optical_lag*3.0);
	vec3 color=mix(vec3(.105,.145,.125),vec3(.18,.20,.145),coarse*.36); float rough=.76; float spec=.055; float sss=.23; float depth=.22;
	if(physical_layer==1){ // vacuolar pressure volume
		color=mix(vec3(.20,.29,.28),vec3(.31,.40,.34),coarse*.42)+rim*vec3(.08,.13,.12);
		rough=.30; spec=.12; sss=.11; depth=.46;
	}else if(physical_layer==2){ // layered blue-black information body
		float folds=pow(.5+.5*sin(p_local.y*12.0+p_local.x*5.0+coarse*3.0),5.0);
		color=mix(vec3(.007,.018,.028),vec3(.025,.070,.095),coarse*.45)+folds*vec3(.008,.025,.04);
		color+=rim*mix(vec3(.015,.045,.065),vec3(.06,.025,.08),ether_component);
		rough=.82; spec=.04; sss=.08; depth=.055;
	}else if(physical_layer==3){ // energy/folded storage bodies
		float folds=pow(.5+.5*sin(p_local.x*17.0+p_local.y*7.0+fine*2.0),7.0);
		color=mix(vec3(.16,.12,.052),vec3(.29,.23,.085),coarse*.36)+folds*vec3(.08,.045,.008)*activity;
		if(optical_regime==1) color+=lamp_spectrum*lamp_intensity*folds*.075;
		rough=.60; sss=.18; depth=.16;
	}else if(physical_layer==4){ // flexible transport network
		color=mix(vec3(.065,.115,.085),vec3(.16,.20,.115),coarse*.38)+pulse*vec3(.018,.038,.025);
		if(optical_regime==1) color+=lamp_spectrum*lamp_intensity*pulse*.055;
		rough=.72; sss=.25; depth=.23;
	}else if(physical_layer==5){ // birefringent tension fibers
		float strain=pow(.5+.5*sin(dot(n,vec3(8.0,5.0,11.0))+optical_time*.16),12.0)*rim;
		vec3 spectral=mix(vec3(.04,.11,.12),vec3(.14,.055,.16),.5+.5*sin(optical_time*.21+p_local.x*5.0));
		float arrival=exp(-abs(flicker_phase-(.58+optical_lag*.18))/.12)*flicker_amplitude;
		color=vec3(.065,.085,.078)+spectral*strain*(.28+ether_component*1.05+arrival*.95);
		rough=mix(.68,.34,strain); spec=.11; sss=.10; depth=.12;
	}else if(physical_layer==6){ // embedded gate / local machinery
		color=mix(vec3(.19,.23,.20),vec3(.33,.28,.17),coarse*.42)+rim*vec3(.035,.055,.045);
		rough=.58; spec=.08; sss=.20; depth=.17;
	}else if(physical_layer==7){ // deformable returning information vesicle
		color=mix(vec3(.006,.020,.033),vec3(.025,.075,.105),coarse*.52);
		color+=rim*vec3(.035,.085,.12)+activity*vec3(.005,.018,.038);
		rough=.72; spec=.045; sss=.13; depth=.08;
	}
	// Illumination changes which structures answer; it never applies a global tint.
	if(physical_layer==2) {
		float deep_arrival=exp(-abs(flicker_phase-(.80+optical_lag*.12))/.13)*flicker_amplitude;
		color+=lamp_spectrum*lamp_intensity*.018*(1.0-coarse);
		color+=mix(vec3(.015,.04,.06),vec3(.055,.018,.075),ether_component)*(ether_component*.45+deep_arrival*.30);
	}
	if(optical_regime==0 && physical_layer!=1) color*=.62;
	if(optical_regime==1 && (physical_layer==3 || physical_layer==4)) color+=lamp_spectrum*lamp_intensity*pulse*.045;
	if(optical_regime==2) {
		if(physical_layer!=5) color*=.68;
		if(physical_layer==5) color+=mix(vec3(.025,.09,.10),vec3(.11,.035,.13),pulse)*(.28+.42*flicker_amplitude);
	}
	if(optical_regime==3) {
		if(physical_layer==3 || physical_layer==4) color*=.64;
		if(physical_layer==2) color+=vec3(.025,.055,.105)*(1.0-coarse)+vec3(.075,.022,.085)*rim;
		if(physical_layer==5) color+=vec3(.035,.075,.12)*rim;
	}
	if(physical_layer==3) color+=lamp_spectrum*lamp_intensity*activity*.055*pulse;
	if(physical_layer==4) color+=lamp_spectrum*lamp_intensity*.022*pulse;
	color+=rim*vec3(.025,.038,.032); // phase/contact halo in surrounding medium
	ALBEDO=color; ROUGHNESS=rough; SPECULAR=spec;
	SSS_STRENGTH=sss; SSS_TRANSMITTANCE_COLOR=vec4(mix(color,lamp_spectrum,.08),1.0);
	SSS_TRANSMITTANCE_DEPTH=depth; SSS_TRANSMITTANCE_BOOST=.20;
	BACKLIGHT=color*(.06+.16*lamp_intensity)*(1.0-coarse*.22);
}
