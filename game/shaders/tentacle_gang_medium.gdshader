shader_type spatial;
render_mode cull_back,depth_draw_never;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
#include "res://shaders/tentacle_gang_deform.gdshaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
void vertex(){organ_local=VERTEX;organ_height=VERTEX.y;VERTEX=gang_deform(VERTEX,1.0,MODEL_MATRIX);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 vec3 p=organ_local*220.0;
 float cloud=.5+.25*sin(p.x+sin(p.y*.8))*sin(p.z+organ_time*.03);
 float depth=.012/max(abs(dot(NORMAL,VIEW)),.2);
 vec3 extinction=exp(-vec3(12.0,17.0,21.0)*cloud*depth);
 ALBEDO=texture(albedo_map,UV).rgb*extinction;
 NORMAL_MAP=texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH=.08;
 ROUGHNESS=texture(roughness_map,UV).r*.45;
 BACKLIGHT=s.radiance*s.transmittance*extinction*.3;
 ALPHA=clamp(1.0-exp(-cloud*depth*28.0),.08,.65);
 EMISSION=vec3(0.0);
}
