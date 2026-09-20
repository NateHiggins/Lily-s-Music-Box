shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

uniform vec3 tissue_color : source_color = vec3(.34,.09,.15);
uniform vec3 secondary_color : source_color = vec3(.22,.07,.12);
uniform vec3 absorption_color : source_color = vec3(.18,.025,.05);
uniform float absorption_density : hint_range(0.,4.) = .65;
uniform float transmission_strength : hint_range(0.,.75) = .20;
uniform float subsurface_strength : hint_range(0.,.35) = .16;
uniform float surface_roughness : hint_range(.1,1.) = .68;
uniform float surface_specular : hint_range(0.,.5) = .16;
uniform float thickness_hint : hint_range(.01,2.) = .32;
uniform float micro_scale = 4.8;
uniform float variation_strength : hint_range(0.,.5) = .16;
uniform float vascular_strength : hint_range(0.,.25) = .0;
uniform float flow_strength : hint_range(0.,.25) = .0;
uniform float halo_strength : hint_range(0.,.2) = .045;
instance uniform vec4 presentation_state = vec4(.5,.5,.5,0.);
instance uniform float presentation_time = 0.0;
instance uniform float examination_mode = 0.0;
instance uniform float low_lod_response = 0.0;
instance uniform float process_stage : hint_range(0.,1.) = 0.0;
instance uniform float senescence : hint_range(0.,1.) = 0.0;
instance uniform int illumination_mode = 1; // 0 filament, 1 daylight, 2 electrical/dream

varying vec3 local_position;
varying float vascular_ridge;

float hash31(vec3 p) {
	p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z);
}

void vertex() {
	local_position=VERTEX;
	float branch=sin(VERTEX.x*1.35+sin(VERTEX.z*.83)*1.7+VERTEX.y*.35);
	vascular_ridge=pow(1.0-abs(branch),9.0);
	float living_wave=sin(VERTEX.x*1.7+VERTEX.y*1.1+presentation_time*1.15)*.0012;
	VERTEX+=NORMAL*(living_wave*presentation_state.y+vascular_ridge*vascular_strength*.018);
}

void fragment() {
	float facing=max(abs(dot(normalize(NORMAL),normalize(VIEW))),.28);
	float optical_thickness=clamp(thickness_hint/facing,.02,2.5);
	float transmission=transmission_strength*exp(-optical_thickness*absorption_density);
	float mottle=sin(local_position.x*3.7+sin(local_position.z*2.1))+sin(local_position.y*4.3-local_position.z*1.4);
	mottle=mottle*.25+.5;
	float flow=sin(local_position.x*2.0+local_position.z*.9-presentation_time*.42+sin(local_position.y*2.6))*.5+.5;
	vec3 local_tissue=mix(tissue_color,secondary_color,clamp(mottle*variation_strength+flow*flow_strength,0.0,.65));
	float route=pow(1.0-abs(sin(local_position.x*1.65+sin(local_position.z*.72)*1.8-presentation_time*.28)),6.0);
	float route_pulse=route*smoothstep(.18,.95,sin(local_position.x*2.2-presentation_time*.65)*.5+.5)*process_stage;
	vec3 energy_color=vec3(.58,.205,.045);
	vec3 info_color=vec3(.035,.075,.105);
	vec3 growth_color=vec3(.20,.27,.16);
	local_tissue=mix(local_tissue,energy_color,route_pulse*.52*(1.0-smoothstep(.58,.82,process_stage)));
	local_tissue=mix(local_tissue,info_color,route_pulse*.56*smoothstep(.28,.72,process_stage));
	local_tissue=mix(local_tissue,growth_color,vascular_ridge*process_stage*(1.0-process_stage)*.28);
	if (illumination_mode == 0) local_tissue*=vec3(1.08,1.01,.84);
	else if (illumination_mode == 1) local_tissue*=vec3(.92,1.02,1.06);
	else local_tissue=mix(local_tissue,local_tissue*vec3(.76,1.04,1.16),route*.20);
	vec3 milky=vec3(.48,.46,.38);
	vec3 residue=vec3(.11,.085,.05);
	local_tissue=mix(local_tissue,milky,smoothstep(.18,.62,senescence)*.72);
	local_tissue=mix(local_tissue,residue,smoothstep(.55,.92,senescence));
	vec3 absorbed=local_tissue*exp(-absorption_color*optical_thickness*3.0);
	float micro=(hash31(floor(local_position*micro_scale*9.0))-.5)*mix(.025,.012,low_lod_response);
	float buried_density=sin(local_position.x*2.1+local_position.z*.7)*sin(local_position.y*2.7-local_position.z*1.3);
	float internal_shadow=(1.0-examination_mode)*smoothstep(.2,.82,buried_density*.5+.5)*(.055+transmission*.20);
	vec3 base=local_tissue*(.92+micro)+secondary_color*vascular_ridge*vascular_strength*.32;
	ALBEDO=mix(base,absorbed,transmission*.48)*(1.0-internal_shadow);
	ROUGHNESS=clamp(surface_roughness+(mottle-.5)*.11+low_lod_response*.08-vascular_ridge*vascular_strength*.22,.0,1.0);
	SPECULAR=surface_specular;
	SSS_STRENGTH=subsurface_strength;
	SSS_TRANSMITTANCE_COLOR=vec4(mix(tissue_color,absorption_color,.45),1.0);
	SSS_TRANSMITTANCE_DEPTH=max(thickness_hint,.02);
	SSS_TRANSMITTANCE_BOOST=.18+transmission*.32;
	BACKLIGHT=absorption_color*(.06+.20*transmission)*(1.0-smoothstep(.1,2.1,optical_thickness));
	vec3 selective_fluorescence=vec3(.16,.34,.42)*route_pulse*(illumination_mode==2 ? .16 : .015)*(1.0-senescence);
	EMISSION=mix(secondary_color,absorption_color,.5)*pow(1.0-facing,3.5)*halo_strength+selective_fluorescence;
}
