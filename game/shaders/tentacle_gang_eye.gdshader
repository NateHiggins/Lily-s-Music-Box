shader_type spatial;
render_mode depth_prepass_alpha;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
#include "res://shaders/tentacle_gang_deform.gdshaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
uniform float mineral=0.0;
void vertex(){organ_local=VERTEX;organ_height=VERTEX.y;VERTEX=gang_deform(VERTEX,1.0,MODEL_MATRIX);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 float pigment=clamp(length(s.radiance)*120.0,0.0,.7)*s.visibility;
 ALBEDO=texture(albedo_map,UV).rgb*(.32-pigment*.2);
 ROUGHNESS=.1+texture(roughness_map,UV).r*.12;
 NORMAL_MAP=texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH=.08;
 SPECULAR=.7;
 ALPHA=.25+pigment*.5;
 EMISSION=vec3(0.0);
}
void light(){
 float return_angle=pow(max(dot(LIGHT,VIEW),0.0),70.0);
 DIFFUSE_LIGHT+=LIGHT_COLOR*ATTENUATION*(ALBEDO*max(dot(NORMAL,LIGHT),0.0)/PI+vec3(.05,.035,.025)*return_angle);
 SPECULAR_LIGHT+=LIGHT_COLOR*ATTENUATION*pow(max(dot(NORMAL,normalize(LIGHT+VIEW)),0.0),140.0)*.35;
}
