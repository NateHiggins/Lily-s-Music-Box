shader_type spatial;
render_mode cull_back, depth_draw_always, diffuse_burley, specular_schlick_ggx;

instance uniform int process_state = 0;
instance uniform float process_phase = 0.0;
instance uniform int illumination_mode = 0;
varying vec3 p_local;

float hash31(vec3 p) { p=fract(p*.1031); p+=dot(p,p.yzx+33.33); return fract((p.x+p.y)*p.z); }
float cloud(vec3 p) { float a=hash31(floor(p*5.0)); float b=hash31(floor(p*13.0+vec3(3,1,7))); return a*.68+b*.32; }

void vertex() { p_local=VERTEX; }
void fragment() {
	vec3 n=normalize(NORMAL); float facing=clamp(abs(dot(n,normalize(VIEW))),0.0,1.0); float density=cloud(p_local);
	float channel=pow(1.0-abs(sin(p_local.x*2.0+sin(p_local.z*1.4))),7.0);
	float suspended=pow(hash31(floor(p_local*24.0+process_phase*.03)),8.0);
	vec3 straw=mix(vec3(.20,.205,.125),vec3(.31,.29,.16),density*.52);
	if (illumination_mode==1) straw*=vec3(.93,1.02,1.03);
	if (illumination_mode==3) straw*=vec3(1.12,1.03,.76);
	if (process_state==2) straw=mix(straw,vec3(.48,.16,.018),channel*density*.38);
	if (process_state==3) density=mix(density,hash31(floor(p_local*3.0+process_phase)),.52);
	ALBEDO=straw+suspended*vec3(.035,.028,.012); ROUGHNESS=.78; SPECULAR=.05;
	ALPHA=clamp(.045+density*.16+(1.0-facing)*.055-channel*.045,.032,.26);
}
