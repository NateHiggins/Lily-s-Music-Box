shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform int kind = 0;
uniform vec3 precipitation_light : source_color = vec3(0.55,0.62,0.70);
void vertex() {
	// World-space simulation, view-facing quad. Camera rotation never rotates the rain volume.
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
		vec4(INV_VIEW_MATRIX[0].xyz*scale.x,0.0),
		vec4(INV_VIEW_MATRIX[1].xyz*scale.y,0.0),
		vec4(INV_VIEW_MATRIX[2].xyz*scale.z,0.0),MODEL_MATRIX[3]);
}
void fragment() {
	vec2 q=UV*2.0-1.0;
	float mask=(1.0-smoothstep(0.12,0.85,abs(q.x)))*(1.0-smoothstep(0.55,1.0,abs(q.y)));
	float opacity=0.35;
	if(kind==1) {
		float jag=abs(q.x+0.25*(fract(UV.y*5.0)-0.5));
		mask=(1.0-smoothstep(0.10,0.65,jag))*(1.0-smoothstep(0.7,1.0,abs(q.y)));
		opacity=0.78;
	}
	if(kind==2) {mask=1.0-smoothstep(0.25,1.0,length(q));opacity=0.72;}
	if(kind==3) {mask=1.0-smoothstep(0.65,1.0,abs(q.x)+abs(q.y));opacity=0.94;}
	ALBEDO=(kind>=2 ? vec3(0.95) : vec3(0.64,0.73,0.82))*precipitation_light;
	ALPHA=mask*opacity;
}
