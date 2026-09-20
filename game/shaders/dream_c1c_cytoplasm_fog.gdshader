shader_type fog;

uniform float density_gain : hint_range(0.0, 0.20) = 0.060;
uniform float optical_time = 0.0;
uniform float lamp_intensity = 0.0;
uniform vec3 lamp_spectrum = vec3(1.0,.82,.58);
uniform float flicker_amplitude = 0.0;
uniform float optical_lag = 0.0;
uniform float ether_component = 0.0;
uniform float flicker_phase = 0.0;
uniform int optical_regime = 1;
uniform vec3 packet_world = vec3(1000.0);

float hash31(vec3 p){ p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float value_noise(vec3 p){
	vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void fog(){
	vec3 p=WORLD_POSITION;
	vec3 advected=p*vec3(1.55,2.35,1.75)+vec3(-optical_time*.045,optical_time*.026,optical_time*.018);
	float low=value_noise(advected)+.48*value_noise(advected*2.03+7.2);
	float current=.5+.5*sin(p.x*2.5+sin(p.z*2.1)-optical_time*.14-optical_lag*2.0);
	float particulate=pow(value_noise(advected*5.7+2.0),7.0);
	float packet_wake=exp(-distance(p,packet_world)*4.2);
	float edge=1.0-smoothstep(-.16,0.0,SDF);
	float lagged_flicker=flicker_amplitude*exp(-abs(flicker_phase-(.25+optical_lag*.25+p.x*.025))/.14);
	float density=density_gain*edge*(.34+low*.52+current*.16+particulate*.22+packet_wake*.20);
	density*=1.0+lagged_flicker*.12;
	if(optical_regime==0) density*=.82;
	if(optical_regime==2) density*=1.0+lagged_flicker*.34;
	DENSITY=density;
	vec3 tissue=mix(vec3(.30,.35,.22),vec3(.20,.30,.31),low*.44);
	tissue=mix(tissue,tissue*lamp_spectrum,.16*lamp_intensity);
	tissue+=vec3(.055,.025,.075)*ether_component*current*.22;
	ALBEDO=tissue;
	EMISSION=vec3(0.0);
}
