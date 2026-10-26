// Material transport only. The authoritative instantaneous sample is shared.
#include "res://shaders/lamp_optical_sample.gdshaderinc"
uniform int micro_diagnostic = 0; // 1 exterior, 2 interior, 3 gold/fibers, 4 field
uniform bool micro_pc_only = false;
uniform vec3 micro_pc_eye = vec3(0.0);
uniform sampler2D micro_scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D micro_membrane_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D micro_membrane_roughness : filter_linear_mipmap_anisotropic;
uniform sampler2D micro_membrane_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D micro_organ_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D micro_organ_roughness : filter_linear_mipmap_anisotropic;
uniform sampler2D micro_organ_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D micro_mineral_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D micro_mineral_roughness : filter_linear_mipmap_anisotropic;
uniform sampler2D micro_mineral_normal : hint_normal, filter_linear_mipmap_anisotropic;
varying vec3 micro_side;
varying vec3 micro_up;
varying vec3 micro_forward;
varying vec3 micro_dimensions;
varying flat float micro_species;
varying vec4 micro_meal;

vec3 micro_direction(vec3 world_direction) {
 return normalize(vec3(dot(world_direction,micro_side),dot(world_direction,micro_up),dot(world_direction,micro_forward))/micro_dimensions);
}
float micro_exit(vec3 point, vec3 direction) {
 // Authored trunk envelope, in organism coordinates; local to the posed body.
 vec3 r=micro_species>6.5 ? vec3(.48,.16,.52) : vec3(.46,.42,.51);
 vec3 p=point/r,d=direction/r;
 float b=dot(p,d),a=dot(d,d);
 return max(0.0,(-b+sqrt(max(0.0,b*b-a*(dot(p,p)-1.0))))/a);
}
float micro_density(vec3 p) {
 // Slow bounded advection in the organism frame; no world-space swimming.
 float cloud=.5+.5*sin(p.x*17.0+sin(p.z*11.0)+TIME*.11)*sin(p.y*14.0-p.z*9.0+TIME*.07);
 return .12+.85*cloud*cloud;
}
vec3 micro_transport(vec3 p, vec3 direction, float distance_local) {
 float tau=0.0;
 for(int i=0;i<8;i++) tau+=micro_density(p+direction*distance_local*(float(i)+.5)/8.0);
 return exp(-vec3(.65,1.1,1.8)*tau*distance_local/8.0);
}
vec3 micro_world_delta(vec3 p) {
 return micro_side*p.x*micro_dimensions.x+micro_up*p.y*micro_dimensions.y+micro_forward*p.z*micro_dimensions.z;
}
vec3 micro_entry_radiance(vec3 local_p, vec3 world_p, vec3 direction) {
 // Transmission is incident at the lamp-facing boundary, before traversing
 // tissue. Sampling inside an opaque organ's own shadow would erase it.
 float distance_local=micro_exit(local_p,direction);
 return sample_lamp_optics(world_p+micro_world_delta(direction*(distance_local+.006))).radiance;
}
float micro_wet_reflection(vec3 n, vec3 eye, vec3 light_dir, float roughness) {
 vec3 h=normalize(eye+light_dir);
 float nl=max(dot(n,light_dir),0.0),nv=max(dot(n,eye),0.0001),nh=max(dot(n,h),0.0);
 float a=roughness*roughness,a2=a*a;
 float denominator=nh*nh*(a2-1.0)+1.0;
 float distribution=a2/(PI*denominator*denominator);
 float k=(roughness+1.0)*(roughness+1.0)/8.0;
 float geometry=nl/(nl*(1.0-k)+k)*nv/(nv*(1.0-k)+k);
 float fresnel=.02+.98*pow(1.0-max(dot(eye,h),0.0),5.0);
 return distribution*geometry*fresnel/(4.0*nv);
}
