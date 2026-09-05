shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform vec3 probe_points[16];
void fragment(){
 int i=clamp(int(UV.x*16.0),0,15);
 LampOpticalSample s=sample_lamp_optics(probe_points[i]);
 COLOR=vec4(s.radiance.r,s.visibility,s.transmittance,1.0);
}
