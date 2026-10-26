shader_type spatial;
render_mode cull_back,depth_draw_never;
#include "res://shaders/lamp_optical_sample.gdshaderinc"
#include "res://shaders/guide_bell_deform.gdshaderinc"
uniform sampler2D albedo_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic;
uniform sampler2D scene_color : hint_screen_texture,filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture,filter_nearest;
void vertex(){cell_height=VERTEX.y;NORMAL=bell_normal(NORMAL,VERTEX);TANGENT=bell_normal(TANGENT,VERTEX);BINORMAL=bell_normal(BINORMAL,VERTEX);VERTEX=bell_deform(VERTEX,MODEL_MATRIX);optical_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 LampOpticalSample s=sample_lamp_optics(optical_world);
 float lip=exp(-pow((cell_height-.595)*100.0,2.0));
 vec3 pigment=texture(albedo_map,UV).rgb;
 float density=clamp((.45-dot(pigment,vec3(.2126,.7152,.0722)))*5.0+.75,.35,1.3);
 float thickness=.0035*density+.010*lip+.022*wilt;
 float grazing=1.0-abs(dot(NORMAL,VIEW));
 vec3 transport=exp(-vec3(14.0,19.0,13.0)*thickness/max(.2,1.0-grazing));
 vec2 uv=clamp(SCREEN_UV+NORMAL.xy*thickness*.02,vec2(.001),vec2(.999));
 if(texture(scene_depth,uv).r>FRAGCOORD.z)uv=SCREEN_UV;
 vec3 transmitted=textureLod(scene_color,uv,thickness*20.0).rgb;
 vec3 stock=mix(pigment*(.96+.04*sin(seed_phase)),vec3(.25,.18,.28),wilt*.8);
 ALBEDO=stock*(vec3(1.0)-transport)*.8;
 ROUGHNESS=clamp(texture(roughness_map,UV).r*.65+wilt*.3,.16,.75);
 NORMAL_MAP=texture(normal_map,UV).rgb; NORMAL_MAP_DEPTH=.18;
 SPECULAR=.4+grazing*.12*(1.0-wilt);
 BACKLIGHT=transport*s.radiance*s.transmittance*.28*(1.0-wilt);
 // Transport of scene light, no intrinsic emission or directional mask.
 EMISSION=transmitted*transport; ALPHA=1.0;
}
