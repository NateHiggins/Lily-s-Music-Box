shader_type spatial;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
uniform float melt_age = 0.0;
uniform float floor_height = 0.0;
varying vec3 residue_world;
varying vec3 residue_local;
void vertex(){
 residue_local=VERTEX;
 float spread=mix(.06,1.12,smoothstep(0.0,2.1,melt_age));
 float radius=length(VERTEX.xz);
 float curl=.045*sin(melt_age*1.7+radius*18.0);
 VERTEX.xz=mat2(vec2(cos(curl),-sin(curl)),vec2(sin(curl),cos(curl)))*VERTEX.xz*spread;
 VERTEX.y+=.004*sin(radius*48.0-melt_age*2.0)*(1.0-smoothstep(.2,.36,radius));
 VERTEX.y-=.06*smoothstep(2.8,4.2,melt_age);
 residue_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 if(residue_world.y<floor_height+.0003)discard;
 vec2 flow=UV+vec2(.035*sin(UV.y*.8+melt_age*.45),melt_age*.028);
 vec3 stock=texture(albedo_map,flow).rgb;
 float rough=texture(roughness_map,flow).r;
 float swirl=sin(residue_local.x*19.0+sin(residue_local.z*22.0-melt_age*.5)*1.8);
 float pigment=atan(residue_local.z,residue_local.x)*.45+sin(length(residue_local.xz)*13.0-melt_age*.32)*.35+swirl*.22+melt_age*.06;
 vec3 rainbow=.5+.5*cos(6.28318*(pigment+vec3(0.0,.333,.667)));
 float scab=sin(residue_local.x*23.0+cos(residue_local.z*15.0))*cos(residue_local.z*21.0-residue_local.x*6.0);
 float charred=smoothstep(.45,.78,scab)*smoothstep(.3,2.2,melt_age);
 ALBEDO=mix(stock*(.15+.85*rainbow),vec3(.012,.008,.016),charred);
 METALLIC=.62*(1.0-charred);
 ROUGHNESS=mix(max(.12,rough*.6),.92,charred);
 NORMAL_MAP=texture(normal_map,flow).rgb;
 NORMAL_MAP_DEPTH=.18;
 SPECULAR=.8;
 CLEARCOAT=1.0-charred;
 CLEARCOAT_ROUGHNESS=.12;
 LampOpticalSample s=sample_lamp_optics(residue_world);
 BACKLIGHT=s.radiance*.04*(1.0-charred);
 EMISSION=vec3(0.0);
}
