shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture,filter_linear,repeat_disable;
uniform float lens_amount=0.0;
uniform float blood_amount=0.0;
uniform float lens_scroll=0.0;

float seed(vec2 p) {
	p.y=mod(p.y,64.0); // Match the bounded scroll wrap without replacing the pattern.
	vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
void fragment() {
	vec2 grid=UV*vec2(17.0,9.0)-vec2(0.0,lens_scroll);
	vec2 cell=floor(grid);float variation=seed(cell);
	vec2 centre=.22+.56*vec2(seed(cell+vec2(7.0,3.0)),seed(cell+vec2(2.0,13.0)));
	vec2 q=fract(grid)-centre;
	q.x*=mix(3.2,2.0,smoothstep(-.22,.08,q.y));
	q.y*=mix(1.1,1.8,variation);
	float radius=length(q);
	float enabled=step(.48,variation)*lens_amount;
	float drop=(1.0-smoothstep(.10,mix(.24,.34,variation),radius))*enabled;
	float tail=(1.0-smoothstep(.012,.032,abs(q.x)))*smoothstep(-.4,-.3,q.y)*(1.0-smoothstep(-.1,.02,q.y));
	drop=max(drop,tail*enabled*.3);
	vec2 normal=q/max(.08,radius)*drop;
	vec2 offset=normal*vec2(.0025,.004);
	vec3 refracted=texture(screen_texture,clamp(SCREEN_UV+offset,vec2(.001),vec2(.999))).rgb;
	vec3 stained=refracted*vec3(.45,.045,.055)+vec3(.015,0.0,0.0);
	COLOR=vec4(mix(refracted,stained,blood_amount*drop*.65),1.0);
}
