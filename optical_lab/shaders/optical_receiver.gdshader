shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform int family=0;
uniform vec3 base_color : source_color = vec3(0.55,0.5,0.42);
uniform float thickness=0.08;
uniform float absorption=2.0;
uniform float surface_roughness=0.72;
varying vec3 optical_world;
varying vec3 fiber_direction;
void vertex(){fiber_direction=normalize((MODELVIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 ALBEDO=base_color;ROUGHNESS=family==5?0.12:family==1?0.22:surface_roughness;
 if(family==1)NORMAL_MAP=normalize(vec3(sin(UV.x*180.0)*0.06,cos(UV.y*170.0)*0.06,1.0))*0.5+0.5;
 METALLIC=family==5?1.0:0.0;
 if(family==3 || family==8){ALPHA=1.0-exp(-absorption*max(thickness,0.001));ALPHA_HASH_SCALE=1.0;}
 if(family==7)SSS_STRENGTH=0.35;
}
void light(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 float facing=max(dot(NORMAL,LIGHT),0.0);
 vec3 half_vector=normalize(LIGHT+VIEW);
 float gloss=pow(max(dot(NORMAL,half_vector),0.0),family==5?180.0:family==1?70.0:mix(100.0,8.0,surface_roughness));
 float transmission=exp(-absorption*max(thickness,0.001));
 vec3 diffuse=s.radiance*facing*ALBEDO/3.14159265;
 if(family==1)diffuse+=s.radiance*pow(1.0-max(dot(NORMAL,VIEW),0.0),4.0)*0.06;
 if(family==2)diffuse+=s.radiance*pow(max(0.0,1.0-pow(dot(normalize(fiber_direction),half_vector),2.0)),24.0)*0.10;
 if(family==3 || family==8)diffuse=diffuse*(1.0-transmission)+s.radiance*transmission*max(dot(-NORMAL,LIGHT),0.0)*0.4;
 if(family==4)diffuse=s.radiance*(1.0-transmission)*(0.05+0.1*pow(max(dot(-LIGHT,VIEW),0.0),6.0));
 if(family==6)diffuse=s.radiance*s.scattering*0.8;
 if(family==7)diffuse+=s.radiance*(1.0-transmission)*0.08;
 if(family==5){diffuse=vec3(0.0);SPECULAR_LIGHT+=s.radiance*vec3(1.0,0.72,0.25)*gloss;}
 else SPECULAR_LIGHT+=s.radiance*gloss*0.06;
 DIFFUSE_LIGHT+=diffuse;
}
