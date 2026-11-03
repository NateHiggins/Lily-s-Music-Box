shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform int kind = 0;
uniform float intensity = .4;
uniform float blood_amount = 0.0;
uniform vec3 wind_mps = vec3(0.0);
uniform float pixel_angle = .001;
uniform vec3 precipitation_light : source_color = vec3(0.55,0.62,0.70);
varying float view_depth;
varying float flake_seed;
void vertex() {
	// World-space simulation, view-facing quad. Camera rotation never rotates the rain volume.
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	view_depth=abs((VIEW_MATRIX*MODEL_MATRIX[3]).z);
	flake_seed=INSTANCE_CUSTOM.z;
	if(kind==0) {
		// Resolve at least a pixel at native resolution instead of vanishing in TAA.
		float depth=abs((VIEW_MATRIX*MODEL_MATRIX[3]).z);
		scale.x*=max(1.0,depth*pixel_angle*1.2/.018);
		vec2 fall=(VIEW_MATRIX*vec4(wind_mps*.55+vec3(0.0,-mix(7.0,32.0,intensity),0.0),0.0)).xy;
		fall=length(fall)>.001 ? normalize(fall) : vec2(0.0,-1.0);
		vec2 across=vec2(-fall.y,fall.x);
		MODELVIEW_MATRIX=mat4(vec4(across*scale.x,0.0,0.0),vec4(-fall*scale.y,0.0,0.0),vec4(0.0,0.0,scale.z,0.0),VIEW_MATRIX*MODEL_MATRIX[3]);
	} else if(kind!=3) {
		if(kind==2) scale*=mix(.75,1.35,INSTANCE_CUSTOM.z);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
		vec4(INV_VIEW_MATRIX[0].xyz*scale.x,0.0),
		vec4(INV_VIEW_MATRIX[1].xyz*scale.y,0.0),
		vec4(INV_VIEW_MATRIX[2].xyz*scale.z,0.0),MODEL_MATRIX[3]);
	}
}
void fragment() {
	vec2 q=UV*2.0-1.0;
	float mask=(1.0-smoothstep(0.12,0.85,abs(q.x)))*(1.0-smoothstep(0.55,1.0,abs(q.y)));
	float opacity=mix(.30,.70,intensity);
	if(kind==1) {
		float jag=abs(q.x+0.25*(fract(UV.y*5.0)-0.5));
		mask=(1.0-smoothstep(0.10,0.65,jag))*(1.0-smoothstep(0.7,1.0,abs(q.y)));
		opacity=0.78;
	}
	if(kind==2) {
		// A flake is a loose ragged clump, not a disc. Flakes a hand's reach from
		// the eye are out of focus: larger, fainter and softer, never a white ball.
		float a=atan(q.y,q.x)+flake_seed*6.2832;
		float rim=.82+.10*sin(a*3.0+flake_seed*11.0)+.06*sin(a*5.0-flake_seed*7.0);
		float near=1.0-smoothstep(.6,3.5,view_depth);
		mask=1.0-smoothstep(rim*mix(.35,.05,near),rim,length(q));
		opacity=mix(.88,.45,near);
	}
	if(kind==3) {mask=1.0;opacity=1.0;}
	ALBEDO=(kind>=2 ? vec3(0.95) : vec3(0.64,0.73,0.82))*precipitation_light;
	ALBEDO=mix(ALBEDO,vec3(.38,.008,.018),blood_amount);
	opacity=mix(opacity,.94,blood_amount);
	ALPHA=mask*opacity*COLOR.a;
}
