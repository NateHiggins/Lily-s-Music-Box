shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;

uniform vec3 tissue_color : source_color = vec3(.34,.09,.15);
uniform vec3 absorption_color : source_color = vec3(.18,.025,.05);
uniform float absorption_density : hint_range(0.,4.) = .65;
uniform float transmission_strength : hint_range(0.,.75) = .20;
uniform float subsurface_strength : hint_range(0.,.35) = .16;
uniform float surface_roughness : hint_range(.1,1.) = .68;
uniform float surface_specular : hint_range(0.,.5) = .16;
uniform float thickness_hint : hint_range(.01,2.) = .32;
uniform float micro_scale = 4.8;
uniform vec4 presentation_state = vec4(.5,.5,.5,0.);
uniform float presentation_time = 0.0;
uniform float examination_mode = 0.0;
uniform float low_lod_response = 0.0;
uniform float gold_response : hint_range(0.,1.) = 0.0;
uniform float internal_role : hint_range(0.,1.) = 0.0;

varying vec3 local_position;

float hash31(vec3 p) {
	p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z);
}

void vertex() {
	local_position=VERTEX;
	float living_wave=sin(VERTEX.x*1.7+VERTEX.y*1.1+presentation_time*1.15)*.0012;
	VERTEX+=NORMAL*living_wave*presentation_state.y;
}

void fragment() {
	float facing=max(abs(dot(normalize(NORMAL),normalize(VIEW))),.28);
	float optical_thickness=clamp(thickness_hint/facing,.02,2.5);
	float transmission=transmission_strength*exp(-optical_thickness*absorption_density);
	vec3 absorbed=tissue_color*exp(-absorption_color*optical_thickness*3.0);
	float micro=(hash31(floor(local_position*micro_scale*9.0))-.5)*mix(.025,.012,low_lod_response);
	float cloud_a=hash31(floor(local_position*7.0));
	float cloud_b=hash31(floor(local_position*15.0+vec3(3.1,7.2,1.8)));
	float cloudy=mix(cloud_a,cloud_b,.34)*internal_role;
	vec2 thickness_gradient=vec2(dFdx(optical_thickness),dFdy(optical_thickness));
	float phase_pair=dot(thickness_gradient,normalize(vec2(.82,.36)));
	vec3 base=tissue_color*(.92+micro);
	ALBEDO=mix(base,absorbed,transmission*.48);
	ALBEDO*=1.0+clamp(phase_pair*2.4,-.10,.10)*(1.0-internal_role);
	ALBEDO=mix(ALBEDO,ALBEDO*mix(.58,1.18,cloudy),internal_role*.48);
	ROUGHNESS=clamp(mix(surface_roughness,.24,gold_response)+low_lod_response*.08,.0,1.0);
	SPECULAR=mix(surface_specular,.68,gold_response);
	METALLIC=gold_response*.82;
	ANISOTROPY=gold_response*.72;
	SSS_STRENGTH=subsurface_strength;
	SSS_TRANSMITTANCE_COLOR=vec4(mix(tissue_color,absorption_color,.45),1.0);
	SSS_TRANSMITTANCE_DEPTH=max(thickness_hint,.02);
	SSS_TRANSMITTANCE_BOOST=.28+transmission*.58;
	BACKLIGHT=mix(absorption_color,tissue_color,.42)*(.18+.92*transmission)
		*(1.0-smoothstep(.1,2.1,optical_thickness));
	EMISSION=vec3(0.0);
}
