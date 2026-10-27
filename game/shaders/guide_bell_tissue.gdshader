shader_type spatial;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
#include "res://shaders/guide_bell_deform.gdshaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
void vertex(){cell_height=VERTEX.y;NORMAL=bell_normal(NORMAL,VERTEX);TANGENT=bell_normal(TANGENT,VERTEX);BINORMAL=bell_normal(BINORMAL,VERTEX);VERTEX=bell_deform(VERTEX,MODEL_MATRIX);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 ALBEDO=mix(texture(albedo_map,UV).rgb,vec3(.20,.16,.22),wilt*.75);
 ROUGHNESS=clamp(texture(roughness_map,UV).r+wilt*.30,.2,.85);
 NORMAL_MAP=texture(normal_map,UV).rgb; NORMAL_MAP_DEPTH=.35;
 ANISOTROPY=.55; SSS_STRENGTH=.3*(1.0-wilt);
 BACKLIGHT=s.radiance*s.transmittance*.12*(1.0-wilt);
}
