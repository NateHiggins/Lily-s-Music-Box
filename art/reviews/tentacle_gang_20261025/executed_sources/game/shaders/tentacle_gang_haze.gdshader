shader_type fog;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform float haze_age=0.0;
uniform float lamp_rate=0.0;
void fog(){
 LampOpticalSample s=sample_lamp_optics(WORLD_POSITION);
 vec3 p=UVW*vec3(19.0,14.0,17.0);
 float curl=sin(p.x+sin(p.z+haze_age*.7)+haze_age*.31)*sin(p.y-haze_age*.5);
 float envelope=(1.0-smoothstep(0.6,5.5,haze_age))*(1.0-smoothstep(-.2,0.0,SDF));
 float visibility=s.visibility*s.transmittance*smoothstep(.00001,.003,dot(s.radiance,vec3(.333333)));
 DENSITY=.9*envelope*(.18+.82*smoothstep(-.5,.8,curl))*visibility*mix(.5,1.0,s.temporal_stability);
 DENSITY/=1.0+min(abs(lamp_rate)*.01,.35);
 ALBEDO=vec3(.38,.12,.58);
 EMISSION=vec3(0.0);
}
