shader_type spatial;
render_mode cull_back,depth_draw_opaque,diffuse_burley,specular_schlick_ggx;
#include "res://shaders/orison_surface.gdshaderinc"

void vertex() {
	float impact=clamp(INSTANCE_CUSTOM.w,0.0,1.0);
	vec3 shape=vec3(1.0+impact*.55,1.0-impact*.55,1.0+impact*.55);
	float handed=dot(cross(NORMAL,TANGENT),BINORMAL)<0.0 ? -1.0 : 1.0;
	VERTEX*=shape*(1.0-smoothstep(5.4,6.0,INSTANCE_CUSTOM.y));
	NORMAL=normalize(NORMAL/shape);
	TANGENT=normalize(TANGENT*shape-NORMAL*dot(NORMAL,TANGENT*shape));
	BINORMAL=normalize(cross(NORMAL,TANGENT))*handed;
	v_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	v_wnormal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment() {
	OrisonSurface s=orison_surface(UV,VERTEX,NORMAL,TANGENT,BINORMAL,EYE_OFFSET,VIEW_MATRIX,TIME);
	ALBEDO=s.albedo;NORMAL=s.normal;ROUGHNESS=min(s.rough,.24);
	SPECULAR=.65;METALLIC=s.metal;AO=s.ao;
	EMISSION=s.emission;CLEARCOAT=.3;CLEARCOAT_ROUGHNESS=.1;
}
