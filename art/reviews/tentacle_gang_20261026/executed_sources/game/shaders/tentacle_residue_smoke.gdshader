shader_type fog;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform float melt_age=0.0;
uniform float lamp_rate=0.0;
void fog(){
 float puff=smoothstep(4.2,4.65,melt_age);
 float fade=1.0-smoothstep(5.3,9.7,melt_age);
 vec3 p=UVW*vec3(14.0,11.0,14.0);
 float rolling=sin(p.x+sin(p.z+melt_age*.65))*sin(p.y-melt_age*1.4+sin(p.x*.7));
 vec3 centre=vec3(.5,mix(.15,.52,puff),.5);
 float radius=mix(.27,.57,puff);
 float body=1.0-smoothstep(radius*.45,radius,length((UVW-centre)*vec3(1.0,.75,1.0)));
 float edge=1.0-smoothstep(-.12,0.0,SDF);
 LampOpticalSample s=sample_lamp_optics(WORLD_POSITION);
 float lit=s.visibility*s.transmittance*smoothstep(.00001,.003,length(s.radiance));
 DENSITY=mix(1.1,5.5,puff)*fade*body*edge*smoothstep(-.65,.75,rolling)*lit*smoothstep(0.0,.4,melt_age);
 ALBEDO=mix(vec3(.065,.025,.08),vec3(.48,.075,.69),puff);
 EMISSION=vec3(0.0);
}
