shader_type spatial;
// Soft body of a shower cone: camera-facing puffs with no texture at all.
// Lit by the room, so a dark bathroom keeps a dark spray.
render_mode blend_mix,depth_draw_never,cull_disabled,diffuse_lambert_wrap,specular_disabled,shadows_disabled;
uniform vec3 tint : source_color=vec3(0.80,0.88,0.92);
uniform float strength=0.16;
void vertex() {
	// Billboard that keeps the particle's own size.
	mat4 facing=mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	float size=length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX=VIEW_MATRIX*facing*mat4(vec4(size,0.0,0.0,0.0),vec4(0.0,size,0.0,0.0),vec4(0.0,0.0,size,0.0),vec4(0.0,0.0,0.0,1.0));
	MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float away=length(UV-0.5)*2.0;
	float soft=smoothstep(1.0,0.15,away);
	// Fade where the puff would cut the lens of a player standing in the cone.
	float near=smoothstep(0.18,0.55,-VERTEX.z);
	ALBEDO=tint;
	ROUGHNESS=1.0;
	ALPHA=soft*soft*strength*COLOR.a*near;
}
