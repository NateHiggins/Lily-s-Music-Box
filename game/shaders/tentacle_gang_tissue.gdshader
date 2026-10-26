shader_type spatial;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
#include "res://shaders/tentacle_gang_deform.gdshaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
uniform float mineral=0.0;
uniform float pigment_cup=0.0;
uniform float nerve_tissue=0.0;
void vertex(){organ_local=VERTEX;organ_height=VERTEX.y;VERTEX=gang_deform(VERTEX,1.0,MODEL_MATRIX);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 float stripe=mix(.82+.18*sin(UV.y*950.0),1.0,nerve_tissue);
 float impulse=alarm<0.0?0.0:exp(-pow((organ_height/.7-(1.0-alarm))*18.0,2.0));
 ALBEDO=texture(albedo_map,UV).rgb*stripe*mix(vec3(1.0),vec3(.8,.55,.19),mineral);
 ALBEDO*=mix(1.0,.035,pigment_cup);
 ALBEDO=mix(ALBEDO,vec3(.58,.54,.43),nerve_tissue*.65);
 ROUGHNESS=clamp(texture(roughness_map,UV).r-impulse*.10,.17,.8);
 NORMAL_MAP=texture(normal_map,UV).rgb;
 METALLIC=mineral;
 ANISOTROPY=.55;
 SSS_STRENGTH=.25*(1.0-mineral);
 BACKLIGHT=s.radiance*.08*(1.0-mineral);
 EMISSION=vec3(0.0);
}
