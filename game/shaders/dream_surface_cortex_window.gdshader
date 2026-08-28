shader_type spatial;
render_mode cull_back, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

uniform vec3 tissue_color : source_color = vec3(.50,.49,.43);
uniform vec3 secondary_color : source_color = vec3(.31,.30,.24);
uniform vec3 absorption_color : source_color = vec3(.18,.15,.09);
uniform float absorption_density = .9;
uniform float transmission_strength = .20;
uniform float subsurface_strength = .19;
uniform float surface_roughness = .76;
uniform float surface_specular = .10;
uniform float thickness_hint = .22;
uniform float variation_strength = .18;
uniform float flow_strength = .055;
uniform float halo_strength = .055;
instance uniform vec3 object_center = vec3(0.0);
instance uniform vec3 object_extent = vec3(1.0);
instance uniform vec4 presentation_state = vec4(.5);
instance uniform float presentation_time = 0.0;
instance uniform float examination_mode = 0.0;
instance uniform float low_lod_response = 0.0;
instance uniform float process_stage = 0.0;
instance uniform float senescence = 0.0;
instance uniform int illumination_mode = 1;

varying vec3 local_position;

float hash31(vec3 p) {
	p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z);
}

float ellipsoid(vec3 p,vec3 center,vec3 radius) {
	return 1.0-smoothstep(.62,1.0,length((p-center)/radius));
}

void vertex() {
	local_position=VERTEX;
	float living_wave=sin(VERTEX.x*1.4+VERTEX.y*1.2+presentation_time*.8)*.0008;
	VERTEX+=NORMAL*living_wave*presentation_state.y;
}

void fragment() {
	vec3 p=(local_position-object_center)/max(object_extent,vec3(.001));
	float facing=max(abs(dot(normalize(NORMAL),normalize(VIEW))),.28);
	float optical_thickness=clamp(thickness_hint/facing,.02,2.5);
	float mottle=(sin(local_position.x*3.4+sin(local_position.z*1.8))+sin(local_position.y*4.1-local_position.z*1.2))*.25+.5;
	float flow=sin(local_position.x*1.8+local_position.z*.8-presentation_time*.34+sin(local_position.y*2.2))*.5+.5;
	vec3 local_tissue=mix(tissue_color,secondary_color,clamp(mottle*variation_strength+flow*flow_strength,0.0,.62));
	float route=pow(1.0-abs(sin(local_position.x*1.6+sin(local_position.z*.7)*1.7-presentation_time*.25)),10.0)*process_stage;
	local_tissue=mix(local_tissue,vec3(.54,.20,.045),route*.22*step(process_stage,.65));
	local_tissue=mix(local_tissue,vec3(.035,.07,.095),route*.28*step(.35,process_stage));
	if(illumination_mode==0)local_tissue*=vec3(1.08,1.01,.84);
	else if(illumination_mode==1)local_tissue*=vec3(.92,1.02,1.06);
	else local_tissue=mix(local_tissue,local_tissue*vec3(.75,1.05,1.15),route*.20);
	local_tissue=mix(local_tissue,vec3(.48,.46,.38),smoothstep(.2,.65,senescence)*.72);
	local_tissue=mix(local_tissue,vec3(.24,.20,.12),smoothstep(.6,1.0,senescence));
	float transmission=transmission_strength*exp(-optical_thickness*absorption_density);
	vec3 absorbed=local_tissue*exp(-absorption_color*optical_thickness*3.0);
	float micro=(hash31(floor(local_position*43.0))-.5)*.025;
	ALBEDO=mix(local_tissue*(.92+micro),absorbed,transmission*.48);
	ROUGHNESS=clamp(surface_roughness+(mottle-.5)*.12+low_lod_response*.06,.0,1.0);
	SPECULAR=surface_specular;
	SSS_STRENGTH=subsurface_strength;
	SSS_TRANSMITTANCE_COLOR=vec4(mix(tissue_color,absorption_color,.45),1.0);
	SSS_TRANSMITTANCE_DEPTH=thickness_hint;
	SSS_TRANSMITTANCE_BOOST=.18+transmission*.30;
	BACKLIGHT=absorption_color*(.07+.22*transmission)*(1.0-smoothstep(.1,2.1,optical_thickness));
	EMISSION=mix(secondary_color,absorption_color,.5)*pow(1.0-facing,3.5)*halo_strength;
	vec3 radial=normalize(p);
	float windows=smoothstep(.91,.975,dot(radial,normalize(vec3(-.18,.18,-1.0))));
	windows=max(windows,smoothstep(.93,.982,dot(radial,normalize(vec3(.95,.08,-.28)))));
	windows=max(windows,smoothstep(.94,.986,dot(radial,normalize(vec3(-.72,-.34,-.56)))));
	windows*=1.0-examination_mode;
	ALPHA=1.0-windows*.96;
	ALPHA_SCISSOR_THRESHOLD=.075;
}
