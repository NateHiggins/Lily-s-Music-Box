shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
#include "res://shaders/v2_condensation.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 water_uv_scale=vec2(1.0);
uniform vec2 glass_size=vec2(1.0);
uniform vec3 pane_center=vec3(0.0);
uniform bool along_z=false;
uniform float outside_sign=1.0;
uniform float inside_wet=0.0;
uniform float outside_wet=0.0;
uniform float edge_wear=0.08;
uniform bool mirror_surface=false;
varying vec2 pane_metres;
varying float face;
void vertex() {
	vec3 p=VERTEX-pane_center;
	pane_metres=vec2(along_z ? p.z : p.x,p.y);
	face=(along_z ? NORMAL.x : NORMAL.z)*outside_sign;
}
void fragment() {
	float wet=face>0.5 ? outside_wet : inside_wet;
	vec4 film=glass_moisture(pane_metres,wet,TIME);
	// Rain beads on the outer face without giving the whole window a steam veil.
	film.z*=mirror_surface || face< -0.5 ? 1.0 : 0.12;
	vec2 edge_distance=glass_size*0.5-abs(pane_metres);
	float edge=1.0-smoothstep(0.001,0.014,min(edge_distance.x,edge_distance.y));
	float scuff=edge*edge_wear*(0.35+0.65*glass_hash(floor(pane_metres/0.0018)));
	vec2 chart=UV*water_uv_scale;
	vec3 grain=texture(normal_tex,chart).rgb*2.0-1.0;
	vec2 bend=clamp(film.xy*0.45+grain.xy*0.04,vec2(-0.55),vec2(0.55));
	NORMAL_MAP=vec3(bend, sqrt(max(0.01,1.0-dot(bend,bend))))*0.5+0.5;
	NORMAL_MAP_DEPTH=1.0;
	ALBEDO=mix(texture(albedo_tex,chart).rgb,vec3(0.82,0.86,0.84),film.z);
	ROUGHNESS=mix(texture(rough_tex,chart).g,0.88,film.z);
	METALLIC=0.0;
	ALPHA=clamp(film.z*0.42+film.w*0.17+scuff,0.0,0.62)*step(0.8,abs(face));
}
