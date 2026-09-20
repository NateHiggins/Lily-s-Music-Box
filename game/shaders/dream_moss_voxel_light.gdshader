shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

// DREAM-VOXEL-V1A production microscopy volume. The box is only a bounded
// rasterization proxy; the visible organism is one integrated amoeboid medium.
uniform sampler2D room_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler3D exposure_tex : filter_linear, repeat_enable, hint_default_black;
uniform float exposure_extent = 48.0;
uniform float exposure_height = 4.0;
uniform vec3 lamp_origin_world = vec3(0.0, 2.0, 0.0);
uniform vec3 lamp_direction_world = vec3(0.0, -0.2, -1.0);
uniform float lamp_range_m = 9.0;
uniform float lamp_cos_outer = 0.82;
uniform vec3 lamp_spectrum = vec3(1.0, 0.78, 0.46);
uniform float lamp_intensity = 0.8;

instance uniform vec4 cellular_phenotype = vec4(.78,.48,.88,.42);
instance uniform vec4 cellular_state_a = vec4(.55,.45,.60,0.0);
instance uniform vec4 cellular_state_b = vec4(0.0,.5,0.0,0.0);
instance uniform vec4 cellular_state_c = vec4(0.0);
instance uniform float cellular_seed = 0.0;
instance uniform float cellular_time = 0.0;
instance uniform int voxel_response_mode = 0;

varying vec3 local_surface;
const int STEPS = 76;

float hash31(vec3 p) {
	p = fract(p * .1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),
		mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),
		mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

float fbm(vec3 p) {
	return noise3(p)*.56+noise3(p*2.07+7.3)*.29+noise3(p*4.11-3.8)*.15;
}

float sd_ellipsoid(vec3 p, vec3 c, vec3 r) {
	return (length((p-c)/r)-1.0)*min(r.x,min(r.y,r.z));
}

float sd_capsule(vec3 p, vec3 a, vec3 b, float r) {
	vec3 pa=p-a; vec3 ba=b-a;
	float h=clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
	return length(pa-ba*h)-r;
}

float organism_sdf(vec3 p) {
	vec3 q=p;
	q.x+=.035*sin(q.y*5.7+q.z*3.1+cellular_seed);
	q.y+=.026*sin(q.x*4.3-q.z*5.2);
	float az=atan(q.z,q.x); float polar=atan(q.y,length(q.xz));
	float folded=.042*sin(az*3.0+polar*2.0)
		+.025*sin(az*5.0-polar*4.0+1.7)+.014*sin(q.x*8.0+q.z*6.0);
	return length(q)-(0.89+folded);
}

float transport_network(vec3 p) {
	float d=sd_capsule(p,vec3(.69,.18,.20),vec3(.39,.09,.05),.035);
	d=min(d,sd_capsule(p,vec3(.39,.09,.05),vec3(.08,.20,-.08),.046));
	d=min(d,sd_capsule(p,vec3(.08,.20,-.08),vec3(-.20,.03,-.17),.052));
	d=min(d,sd_capsule(p,vec3(-.20,.03,-.17),vec3(-.50,-.13,-.04),.043));
	d=min(d,sd_capsule(p,vec3(-.50,-.13,-.04),vec3(-.70,.02,.18),.030));
	d=min(d,sd_capsule(p,vec3(-.48,.31,.04),vec3(-.16,.42,-.12),.027));
	d=min(d,sd_capsule(p,vec3(-.16,.42,-.12),vec3(.20,.35,.06),.031));
	d=min(d,sd_capsule(p,vec3(.20,.35,.06),vec3(.49,.19,.17),.024));
	d=min(d,sd_capsule(p,vec3(-.48,-.29,.10),vec3(-.15,-.40,-.04),.028));
	d=min(d,sd_capsule(p,vec3(-.15,-.40,-.04),vec3(.24,-.31,.11),.034));
	d=min(d,sd_capsule(p,vec3(.24,-.31,.11),vec3(.49,-.12,.02),.024));
	return d;
}

float fiber_bundle(vec3 p) {
	float d=sd_capsule(p,vec3(-.72,-.28,.24),vec3(.67,.31,-.22),.009);
	d=min(d,sd_capsule(p,vec3(-.69,-.23,.19),vec3(.70,.36,-.27),.007));
	d=min(d,sd_capsule(p,vec3(-.61,.39,-.24),vec3(.58,-.37,.20),.008));
	d=min(d,sd_capsule(p,vec3(-.56,.44,-.18),vec3(.63,-.31,.14),.006));
	return d;
}

vec3 cargo_position(float phase) {
	float x=fract(phase)*5.0; int i=int(floor(x));
	float f=smoothstep(0.0,1.0,fract(x));
	vec3 a=vec3(.69,.18,.20); vec3 b=vec3(.39,.09,.05);
	if(i==1){a=b;b=vec3(.08,.20,-.08);}
	else if(i==2){a=vec3(.08,.20,-.08);b=vec3(-.20,.03,-.17);}
	else if(i==3){a=vec3(-.20,.03,-.17);b=vec3(-.50,-.13,-.04);}
	else if(i>=4){a=vec3(-.50,-.13,-.04);b=vec3(-.70,.02,.18);}
	return mix(a,b,f);
}

vec2 exposure_at(vec3 world_p) {
	// Same authoritative axis order as dream_klimt and DreamExposureField.
	// CPU Y addressing clamps above 4 m into layer 7. Sampling at 0.9999 on a
	// repeating 3D texture blended that top layer back toward layer 0, erasing
	// the production specimen's G response at this floor height. Use texel
	// centres for the bounded eight-layer axis so GPU and authority agree.
	return textureLod(exposure_tex,vec3(world_p.x/exposure_extent,
		world_p.z/exposure_extent,
		clamp(world_p.y/exposure_height,.0625,.9375)),0.0).rg;
}

vec3 heatmap_rg(vec2 rg) {
	// Ignore the room's low durable stamp in the diagnostic. Cyan is the live
	// cone and magenta/orange is converted history, so bounded occupancy reads
	// immediately instead of turning the entire specimen purple.
	vec3 current=vec3(.01,.96,.72)*smoothstep(.012,.26,rg.g);
	vec3 history=mix(vec3(.72,.015,.62),vec3(.96,.10,.50),
		clamp(rg.r*2.1,0.0,1.0))*smoothstep(.045,.24,rg.r);
	return current+history;
}

void vertex(){ local_surface=VERTEX; }

void fragment(){
	vec3 ro=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
	vec3 rd=normalize(local_surface-ro);
	float b=dot(ro,rd); float c=dot(ro,ro)-1.0; float h=b*b-c;
	if(h<=0.0){discard;}
	float root_h=sqrt(h); float t0=max(-b-root_h,0.0); float t1=-b+root_h;
	float segment=max(t1-t0,.001); float step_len=segment/float(STEPS);
	vec3 accumulated=vec3(0.0); float transmission=1.0;
	float previous_density=0.0; float boundary_sum=0.0; float lens_sum=0.0;
	vec2 field_peak=vec2(0.0); vec2 field_sum=vec2(0.0);
	vec4 anatomy_sum=vec4(0.0); float fiber_sum=0.0; float gate_sum=0.0;
	vec3 cargo=cargo_position(cellular_time*.075+cellular_state_a.y*.27);
	vec3 lamp_local=normalize((inverse(MODEL_MATRIX)*vec4(-lamp_direction_world,0.0)).xyz);
	float polarization=.5+.5*sin(dot(lamp_local,normalize(vec3(1.2,.5,-.35)))*8.0
		+cellular_time*.21);

	for(int i=0;i<STEPS;i++){
		float t=t0+(float(i)+.5)*step_len; vec3 p=ro+rd*t;
		float body_sdf=organism_sdf(p); float body=smoothstep(.025,-.035,body_sdf);
		if(body>.001){
			float ray_depth=(t-t0)/segment; vec3 world_p=(MODEL_MATRIX*vec4(p,1.0)).xyz;
			vec2 rg=voxel_response_mode>0?exposure_at(world_p):vec2(0.0);
			field_peak=max(field_peak,rg*body); field_sum+=rg*body*step_len;
			float g=smoothstep(.006,.22,rg.g); float r=smoothstep(.003,.18,rg.r);
			float cloud=fbm(p*vec3(3.4,4.6,3.8)
				+vec3(cellular_time*.015,0.0,-cellular_time*.010));
			float stream=.5+.5*sin(p.x*9.0-p.z*6.0+cellular_time*.31+cloud*4.0);
			float membrane=exp(-abs(body_sdf)*96.0);
			float cytoplasm=body*(.13+cloud*.17+stream*.045);

			vec3 v0=vec3(.34,.19,.18); vec3 v1=vec3(.12,-.32,.27);
			vec3 v2=vec3(-.52,.25,.14);
			float vd0=length((p-v0)/vec3(.21,.18,.20));
			float vd1=length((p-v1)/vec3(.15,.13,.14));
			float vd2=length((p-v2)/vec3(.12,.10,.13));
			float vac0=1.0-smoothstep(.76,1.0,vd0);
			float vac1=1.0-smoothstep(.76,1.0,vd1);
			float vac2=1.0-smoothstep(.76,1.0,vd2);
			float vac=max(vac0,max(vac1,vac2));
			float vac_edge=exp(-abs(vd0-1.0)*22.0)+exp(-abs(vd1-1.0)*24.0)
				+exp(-abs(vd2-1.0)*25.0);
			vec3 lens_center=vac0>max(vac1,vac2)?v0:(vac1>vac2?v1:v2);
			vec3 q=p+(p-lens_center)*vac*.16;
			vec3 lensed_world=(MODEL_MATRIX*vec4(q,1.0)).xyz;
			vec2 lensed_rg=voxel_response_mode>0?exposure_at(lensed_world):vec2(0.0);
			g=max(g,smoothstep(.008,.20,lensed_rg.g)*vac*.84);
			lens_sum+=(vac*.70+vac_edge*.06)*step_len; cytoplasm*=mix(1.0,.13,vac);

			float ns=sd_ellipsoid(q+vec3(.018*sin(q.y*16.0),0,0),
				vec3(-.22,.04,-.15),vec3(.31,.27,.25));
			float nucleus=smoothstep(.035,-.045,ns);
			float nuclear_envelope=exp(-abs(ns)*72.0);
			float nuclear_fold=nucleus*(.45+.42*sin(length((q-vec3(-.22,.04,-.15))
				*vec3(1.0,1.17,.88))*39.0+q.y*18.0));
			float net_d=transport_network(q);
			float network=exp(-max(net_d,0.0)*48.0)*smoothstep(.078,-.012,net_d);
			float fiber_d=fiber_bundle(q);
			float fibers=exp(-max(fiber_d,0.0)*130.0)*smoothstep(.027,-.003,fiber_d);
			float cargo_d=length(q-cargo)-.068;
			float cargo_mass=smoothstep(.035,-.030,cargo_d);
			vec3 wake_axis=normalize(vec3(-.26,-.10,-.14));
			float wake=exp(-max(sd_capsule(q,cargo-wake_axis*.34,cargo,.030),0.0)*58.0);

			float gate_outer=sd_ellipsoid(q,vec3(.76,.02,.12),vec3(.15,.18,.14));
			float gate_inner=sd_capsule(q,vec3(.88,.02,.12),vec3(.58,.01,.06),.040);
			float gate_lobes=smoothstep(.040,-.030,gate_outer)
				*(1.0-smoothstep(.030,-.020,gate_inner));
			float gate_channel=smoothstep(.035,-.018,gate_inner);
			float granule_cells=noise3(floor((q+vec3(1.4))*34.0));
			float granules=smoothstep(.935,.992,granule_cells)*body*(1.0-vac);
			float residue_grain=smoothstep(.72,.94,noise3(q*18.0+cellular_seed));
			anatomy_sum+=vec4(nucleus,network,vac_edge,cargo_mass)*body*step_len;
			fiber_sum+=fibers*body*step_len;
			gate_sum+=(gate_lobes+gate_channel)*body*step_len;

			float density=cytoplasm+nucleus*.62+nuclear_envelope*.20
				+nuclear_fold*.22+network*.34+fibers*.085+cargo_mass*.38
				+wake*.055+gate_lobes*.28+gate_channel*.16+granules*.13
				+vac_edge*.020+membrane*.085;
			density*=1.0+g*(.32+cloud*.22)+r*residue_grain*.16;

			vec3 color=mix(vec3(.10,.30,.26),vec3(.34,.58,.43),cloud);
			color=mix(color,vec3(.48,.09,.58),nucleus*.92);
			color=mix(color,vec3(.78,.30,.74),nuclear_envelope*.78);
			color=mix(color,vec3(.02,.72,.62),network*.86);
			color=mix(color,vec3(.95,.56,.12),cargo_mass*.92+gate_lobes*.38);
			color=mix(color,vec3(.10,.78,.89),gate_channel*.72);
			vec3 birefringent=mix(vec3(.12,.76,.83),vec3(.92,.25,.66),
				clamp(polarization+.20*sin(q.x*32.0),0.0,1.0));
			color=mix(color,birefringent,fibers*.92);
			vec3 current_scatter=lamp_spectrum*vec3(1.05,.88,.68)*g
				*(.42+membrane*.85+network*.44+granules*1.20);
			vec3 durable_structure=mix(vec3(.85,.16,.54),vec3(1.0,.67,.15),
				residue_grain)*r*(.10+residue_grain*.62+fibers*.42+gate_lobes*.35);
			color+=current_scatter+durable_structure;

			float near_key=.34+.66*max(dot(normalize(-rd),normalize(lamp_local)),0.0);
			float accumulated_depth=exp(-ray_depth*(.62+cloud*.30+nucleus*.24));
			float physical=.68+lamp_intensity*.52*near_key*accumulated_depth;
			float phase_gradient=abs(density-previous_density);
			vec3 phase=vec3(.43,.66,.63)*min(phase_gradient*1.6,.30)
				+vec3(.76,.45,.68)*vac_edge*.055;
			float alpha_step=1.0-exp(-density*step_len*5.6);
			vec3 scattered=color*physical*(.70+stream*.22)+phase;
			accumulated+=transmission*alpha_step*scattered;
			transmission*=1.0-alpha_step; previous_density=density;
			boundary_sum+=membrane*step_len;
		}
	}

	vec2 lens_offset=vec2(.72,-.38)*lens_sum*.012
		+vec2(sin(local_surface.y*8.0),cos(local_surface.x*7.0))*boundary_sum*.003;
	vec3 background=textureLod(room_color,clamp(SCREEN_UV+lens_offset,
		vec2(.001),vec2(.999)),0.0).rgb;
	vec3 final_color=accumulated+background*transmission;
	if(voxel_response_mode==1){
		vec2 visible_rg=clamp(field_peak*.80+field_sum*.45,vec2(0.0),vec2(1.0));
		vec3 heat=heatmap_rg(visible_rg);
		float specimen=clamp(1.0-transmission,0.0,1.0);
		float signal=max(smoothstep(.012,.24,visible_rg.g),
			smoothstep(.045,.24,visible_rg.r));
		vec3 diagnostic_cell=mix(background,vec3(.018,.026,.030),
			smoothstep(.04,.42,specimen)*.94);
		final_color=mix(diagnostic_cell,heat,signal*.96);
	}
	float rim=pow(1.0-abs(dot(normalize(local_surface),-rd)),2.6);
	if(voxel_response_mode!=1){
		float specimen=clamp(1.0-transmission,0.0,1.0);
		float cell_mask=smoothstep(.035,.38,specimen);
		// Grade the integrated medium as a dark, wet transmitted specimen. The
		// room stays white, but the cell can no longer disappear into it.
		vec3 integrated=clamp(accumulated/max(.22,specimen*1.65),
			vec3(0.0),vec3(.72));
		vec3 tissue=mix(vec3(.018,.055,.052),vec3(.105,.265,.225),
			clamp(integrated.g*1.7,0.0,1.0));
		tissue=mix(tissue,integrated*.52+tissue*.48,.58);
		final_color=mix(background,tissue,cell_mask*.95);

		// Depth-integrated anatomy is present in the disabled specimen, but the
		// current field makes it optically legible rather than inventing it.
		float nucleus_read=smoothstep(.018,.22,anatomy_sum.x);
		float network_read=smoothstep(.004,.075,anatomy_sum.y);
		float vacuole_read=smoothstep(.010,.14,anatomy_sum.z);
		float cargo_read=smoothstep(.003,.070,anatomy_sum.w);
		float fiber_read=smoothstep(.002,.050,fiber_sum);
		float gate_read=smoothstep(.002,.060,gate_sum);
		final_color+=vec3(.34,.035,.46)*nucleus_read*.46*cell_mask;
		final_color+=vec3(.015,.48,.39)*network_read*.38*cell_mask;
		final_color+=vec3(.04,.23,.34)*vacuole_read*.19*cell_mask;
		final_color+=vec3(.72,.24,.035)*cargo_read*.40*cell_mask;
		final_color+=mix(vec3(.02,.48,.52),vec3(.58,.025,.42),polarization)
			*fiber_read*.30*cell_mask;
		final_color+=vec3(.04,.38,.42)*gate_read*.27*cell_mask;

		// G and R are evaluated per camera ray from the actual uploaded RG8
		// volume. G opens a warm, scattering observation band under the present
		// cone. R remains as a cooler structural interference stain after the
		// lamp moves or turns off. Their thresholds exclude the room stamp.
		float current_g=smoothstep(.018,.26,field_peak.g);
		float durable_r=smoothstep(.045,.235,field_peak.r);
		float current_path=smoothstep(.010,.22,field_sum.g);
		float durable_path=smoothstep(.035,.26,field_sum.r);
		vec3 revealed=vec3(.045,.11,.095)
			+vec3(.15,.050,.18)*nucleus_read
			+vec3(.015,.30,.23)*network_read
			+vec3(.36,.15,.025)*cargo_read
			+vec3(.02,.22,.28)*vacuole_read;
		final_color=mix(final_color,final_color*.72+revealed,
			current_g*.70*cell_mask);
		final_color+=vec3(1.0,.43,.07)*(current_g*.31+current_path*.18)
			*cell_mask;
		vec3 history_color=mix(vec3(.58,.012,.46),vec3(.92,.07,.52),
			clamp(field_peak.r*3.1+fbm(local_surface*7.0)*.28,0.0,1.0));
		final_color=mix(final_color,final_color*.72+history_color*.40,
			durable_r*.62*cell_mask);
		final_color+=history_color*durable_path*.22*cell_mask;

		// A restrained phase halo proves the membrane remains intact while the
		// interior keeps accumulated-depth occlusion.
		final_color*=1.0-rim*.22;
		final_color+=mix(vec3(.05,.40,.39),vec3(.48,.07,.38),rim)
			*rim*.15*cell_mask;
	}
	ALBEDO=clamp(final_color,vec3(0.0),vec3(1.0));
	ALPHA=1.0;
}
