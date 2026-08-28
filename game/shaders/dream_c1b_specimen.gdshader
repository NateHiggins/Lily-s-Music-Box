shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

// Shared opaque material proof. Layer identity is a material fact; process,
// age and illumination are bounded presentation inputs derived from existing state.
uniform int physical_layer = 0; // 0 membrane/cortex, 1 suspension, 2 fluid, 3 dense, 4 storage, 5 vessel/fiber, 6 ordered
uniform vec3 object_center = vec3(0.0);
uniform vec3 object_extent = vec3(1.0);
instance uniform int process_state = 0; // rest, information, metabolism, disturbance
instance uniform float age_state = 0.0;
instance uniform int illumination_mode = 1; // filament, daylight, dream
instance uniform float presentation_time = 0.0;

varying vec3 p_local;
varying vec3 n_local;

float hash31(vec3 p) {
	p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z);
}

float value_noise(vec3 p) {
	vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex() {
	p_local=VERTEX; n_local=NORMAL;
	float residue=smoothstep(.82,1.0,age_state);
	if (physical_layer==0) {
		VERTEX.y=mix(VERTEX.y,VERTEX.y*.36,residue);
		VERTEX.xz*=mix(vec2(1.0),vec2(1.04,.97),residue);
	}
	float stalled=process_state==3 ? .15 : 1.0;
	VERTEX+=NORMAL*sin(dot(VERTEX,vec3(2.1,1.3,.8))-presentation_time*.35)*.002*stalled*(1.0-age_state);
}

void fragment() {
	vec3 n=normalize(NORMAL); vec3 view=normalize(VIEW);
	float facing=clamp(abs(dot(n,view)),0.0,1.0); float rim=pow(1.0-facing,3.0);
	float density=value_noise(p_local*3.1)+.45*value_noise(p_local*8.7+vec3(2.4,.2,1.1));
	float fine=value_noise(p_local*31.0);
	float route=pow(1.0-abs(sin(p_local.x*1.55+sin(p_local.z*.85)*1.8)),7.0);
	float packet=pow(max(0.0,sin(p_local.x*2.7-presentation_time*1.15+sin(p_local.z))),4.0)*max(route,.42);
	float aggregate=smoothstep(.63,.88,value_noise(p_local*5.0+age_state*vec3(8.0,2.0,5.0)));
	vec3 color=vec3(.38,.37,.30); float rough=.60; float spec=.14; float sss=.18; float transmit=.20;
	if (physical_layer==0) {
		color=mix(vec3(.34,.34,.28),vec3(.22,.24,.19),density*.22);
		float film=.5+.5*sin(p_local.x*17.0+p_local.z*13.0+density*4.0);
		color+=rim*mix(vec3(.055,.06,.052),vec3(.025,.045,.05),film)*.72;
		rough=mix(.58,.24,rim)*(1.0-fine*.08); spec=.22; sss=.24; transmit=.28;
	} else if (physical_layer==1) {
		color=mix(vec3(.36,.36,.22),vec3(.21,.25,.16),density*.40); rough=.68; sss=.28; transmit=.19;
	} else if (physical_layer==2) {
		color=mix(vec3(.34,.39,.34),vec3(.22,.30,.27),density*.18)+rim*vec3(.07,.085,.075);
		rough=.24; spec=.20; sss=.12; transmit=.35;
	} else if (physical_layer==3) {
		color=mix(vec3(.009,.022,.032),vec3(.035,.070,.088),density*.34); rough=.73; spec=.08; sss=.05; transmit=.03;
	} else if (physical_layer==4) {
		color=mix(vec3(.52,.31,.075),vec3(.70,.48,.15),density*.30); rough=.42; spec=.12; sss=.15; transmit=.11;
	} else if (physical_layer==5) {
		color=mix(vec3(.25,.19,.065),vec3(.46,.34,.11),density*.34); rough=.53; spec=.12; sss=.17; transmit=.14;
	} else {
		float grazing=smoothstep(.45,.92,1.0-facing);
		float ordered=pow(.5+.5*sin(dot(n,vec3(9.0,5.0,7.0))+p_local.x*3.0),16.0)*grazing;
		vec3 flash=mix(vec3(.18,.23,.24),vec3(.34,.22,.12),smoothstep(.25,.8,ordered));
		color=mix(vec3(.20,.21,.19),flash,ordered*.72); rough=mix(.57,.25,ordered); spec=.20; sss=.08; transmit=.08;
	}

	// Process exists inside role geometry. The closed membrane gets only
	// secondary optical consequences, never an exterior painted route.
	if (process_state==1 && physical_layer==5)
		color=mix(color,vec3(.003,.025,.125),.58+packet*.40);
	if (process_state==1 && physical_layer==3)
		color=mix(color,vec3(.004,.018,.080),packet*.68);
	if (process_state==2 && (physical_layer==4 || physical_layer==5))
		color=mix(color,vec3(.68,.19,.018),max(packet,aggregate*.55)*.78);
	if (process_state==3) {
		float strain=pow(.5+.5*sin(dot(p_local,vec3(14.0,5.0,9.0))+density*3.0),14.0)*rim;
		color=mix(color,color*vec3(.72,.82,.88)+vec3(.08,.055,.025),strain*.62);
		rough+=aggregate*.16;
		if (physical_layer==5) color=mix(color,vec3(.16,.145,.105),.48+aggregate*.35);
		if (physical_layer==6) color=mix(color,vec3(.12,.14,.15),.38+strain*.34);
	}

	float milk=smoothstep(.28,.72,age_state); float residue=smoothstep(.72,1.0,age_state);
	color=mix(color,vec3(.56,.54,.45),milk*(.46+aggregate*.22));
	color=mix(color,mix(vec3(.19,.145,.085),vec3(.105,.11,.085),aggregate),residue);
	rough=clamp(rough+milk*.13+residue*.20,0.0,1.0); transmit*=1.0-milk*.80;
	if (physical_layer==5) color=mix(color,vec3(.13,.115,.07),residue*(.55+.35*route));

	// Metamerism is role selective. An invariant white key can therefore keep
	// the room stable while spectral fill reveals different anatomy.
	if (illumination_mode==0) {
		if (physical_layer==4 || physical_layer==5) color*=vec3(1.14,1.05,.78);
		if (physical_layer==3) color*=.62;
	} else if (illumination_mode==1) {
		if (physical_layer==0 || physical_layer==2) color*=vec3(.92,1.02,1.04);
	} else {
		if (physical_layer==6) color+=rim*vec3(.055,.085,.10);
		if (physical_layer==3 || physical_layer==5) color*=vec3(.82,.97,1.12);
	}

	ALBEDO=color; ROUGHNESS=clamp(rough,0.18,1.0); SPECULAR=spec;
	SSS_STRENGTH=sss*(1.0-residue); SSS_TRANSMITTANCE_COLOR=vec4(mix(color,vec3(.42,.33,.16),.28),1.0);
	SSS_TRANSMITTANCE_DEPTH=.12+.38*transmit; SSS_TRANSMITTANCE_BOOST=.16+.35*transmit;
	BACKLIGHT=mix(vec3(.04),color,.22)*transmit*(1.0-density*.20);
	EMISSION=vec3(.035,.065,.08)*packet*(process_state==1 && illumination_mode==2 ? .12 : .0)*(1.0-age_state);
}
