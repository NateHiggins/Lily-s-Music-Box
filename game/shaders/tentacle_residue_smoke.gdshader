shader_type fog;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform float melt_age=0.0;
uniform float lamp_rate=0.0;
void fog(){
 float puff=smoothstep(4.2,4.65,melt_age);
 float fade=1.0-smoothstep(5.3,9.7,melt_age);
 // Broad lobes survive the production fog froxel grid; fine noise alone
 // integrates into a featureless coloured veil at this physical scale.
 vec3 p=(UVW-vec3(.5,.38,.5))*vec3(8.0,6.0,8.0);
 p.xz+=vec2(sin(p.y-melt_age*.8),cos(p.y*.8-melt_age*.6))*.65;
 float rolling=sin(p.x+sin(p.z+melt_age*.65))*sin(p.y-melt_age*1.4+sin(p.x*.7));
 float chambers=.5+.5*sin(length(p.xz)*3.2-p.y*1.5-melt_age*2.0);
 vec3 centre=vec3(.5,mix(.15,.52,puff),.5);
 float radius=mix(.27,.57,puff);
 float body=1.0-smoothstep(radius*.45,radius,length((UVW-centre)*vec3(1.0,.75,1.0)));
 float edge=1.0-smoothstep(-.12,0.0,SDF);
 LampOpticalSample s=sample_lamp_optics(WORLD_POSITION);
 float lit=s.visibility*s.transmittance*smoothstep(.00001,.003,length(s.radiance));
 float folded=smoothstep(-.3,.65,rolling)*mix(.2,1.0,chambers);
 DENSITY=mix(1.1,14.0,puff)*fade*body*edge*folded*lit*smoothstep(0.0,.4,melt_age);
 vec3 fringe=.5+.5*cos(vec3(0.0,2.094,4.189)+chambers*6.283+melt_age*.7);
 vec3 purple=mix(vec3(.32,.025,.82),fringe,.16*chambers);
 ALBEDO=mix(vec3(.065,.025,.08),purple,puff);
 EMISSION=vec3(0.0);
}
