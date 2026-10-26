shader_type spatial;
render_mode cull_back, depth_draw_never;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
#include "res://shaders/tentacle_gang_deform.gdshaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
uniform sampler2D scene_color : hint_screen_texture,filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture,filter_nearest;
uniform float mineral=0.0;
void vertex(){organ_local=VERTEX;organ_height=VERTEX.y;VERTEX=gang_deform(VERTEX,0.0,MODEL_MATRIX);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 vec3 stock=texture(albedo_map,UV).rgb;
 float thickness=.014+.045*(.5+.5*sin(organ_height*29.0));
 float facing=abs(dot(NORMAL,VIEW));
 vec3 absorption=exp(-vec3(9.0,14.0,19.0)*thickness/max(.2,facing));
 vec2 displaced=clamp(SCREEN_UV+NORMAL.xy*thickness*.025,vec2(.001),vec2(.999));
 float behind=texture(scene_depth,displaced).r;
 // Reversed-Z: a nearer foreground surface must not be pulled through tissue.
 if(behind>FRAGCOORD.z)displaced=SCREEN_UV;
 vec3 transmitted=textureLod(scene_color,displaced,thickness*35.0).rgb;
 ALBEDO=stock*(vec3(1.0)-absorption)*.55;
 ROUGHNESS=clamp(texture(roughness_map,UV).r*.55,.12,.6);
 NORMAL_MAP=texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH=.16;
 SPECULAR=.42;
 SSS_STRENGTH=.45;
 BACKLIGHT=absorption*s.radiance*s.transmittance*.35;
 // Full coverage, with thickness-filtered transport of the actual opaque
 // anatomy behind it. The renderer's emission channel carries scene radiance;
 // it is not an intrinsic light source and creates nothing in an unlit scene.
 ALPHA=1.0;
 EMISSION=transmitted*absorption;
}
