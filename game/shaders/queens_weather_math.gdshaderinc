// Proposal: kilometres for cloud positions; metres only in wx_height_tau().
// Include after the existing cloud_noise, sun_direction and wind uniforms.
global uniform float wetness;
uniform float severe_storm_threat = 0.0;
uniform float vortex_intensity = 0.0;
uniform float wx_cyclone = 0.0;
uniform float wx_hail = 0.0;
uniform float wx_whiteout = 0.0;
uniform int wx_formation = 0; // 1 asperitas, 2 fluctus, 3 lenticular, 4 iridescent
uniform float wx_formation_strength = 0.0;
uniform float wx_phase = 0.0;
uniform vec3 wx_camera_km = vec3(0.0);
uniform vec2 wx_cyclone_center = vec2(5.0, -8.0);
uniform vec2 wx_vortex_center = vec2(2.2, -3.5);
uniform vec3 wx_lens_center = vec3(-2.0, 3.0, -4.0);
uniform sampler2D wx_iridescence_ramp : source_color, filter_linear, repeat_enable;

mat2 wx_rotation(float a) {
	float s=sin(a), c=cos(a);
	return mat2(vec2(c,s),vec2(-s,c));
}
float wx_green_gate(vec3 to_sun) {
	// Low but ABOVE the horizon. This is cinematic grading, not a storm forecast.
	return clamp(severe_storm_threat,0.0,1.0)
		* smoothstep(0.005,0.045,to_sun.y)
		* (1.0-smoothstep(0.20,0.42,to_sun.y));
}
vec3 wx_mie_color(vec3 ordinary,vec3 to_sun) {
	return mix(ordinary,vec3(0.48,0.82,0.20),wx_green_gate(to_sun));
}
vec3 wx_cyclone_warp(vec3 p) {
	vec2 r=p.xz-wx_cyclone_center;
	float radius=length(r);
	float weight=wx_cyclone*(1.0-smoothstep(2.0,18.0,radius));
	// Differential angular velocity + logarithmic radial shear form spiral bands.
	float angle=weight*(wx_phase/(0.4+radius*0.12)+1.8*log(1.0+radius));
	p.xz=wx_cyclone_center+wx_rotation(angle)*r;
	return p;
}
float wx_cloud_base() {
	return mix(1.25,0.62,max(wx_hail,wx_cyclone));
}
float wx_asperitas_bottom(vec3 p,float base) {
	float waves=sin(p.x*1.35+wx_phase)*0.55
		+sin(p.z*1.75-p.x*0.60+wx_phase*0.5)*0.45;
	// G is the supplied Worley channel; filter at a coarse mip for smooth pouches.
	float voronoi=textureLod(cloud_noise,p*0.22,2.0).g;
	float pouch=pow(1.0-smoothstep(0.18,0.85,voronoi),2.0);
	return base+0.17*waves-0.26*pouch;
}
vec3 wx_fluctus_warp(vec3 p,float layer_bottom,float layer_top) {
	// Finite patch and vertical gate: do not turn the entire sky into a sawtooth.
	float patch=1.0-smoothstep(1.5,3.0,length(p.xz-vec2(-1.0,-4.0)));
	float h=clamp((p.y-layer_bottom)/max(layer_top-layer_bottom,0.01),0.0,1.0);
	float crest=smoothstep(0.35,1.0,h)*patch;
	float phase=p.x*2.6+wx_phase*0.25;
	float saw=fract(phase)-0.5;
	// Saw shear sets the repeating row; circular top displacement curls the crest.
	float turn=clamp(h*1.5-0.45,0.0,1.0)*PI*1.4;
	p.x-=crest*(0.34*saw+0.20*sin(turn));
	p.y+=crest*0.14*(1.0-cos(turn));
	return p;
}
float wx_ellipsoid(vec3 p,vec3 radii) {
	float k0=length(p/radii), k1=length(p/(radii*radii));
	return k0<0.00001 ? -min(radii.x,min(radii.y,radii.z)) : k0*(k0-1.0)/max(k1,0.00001);
}
float wx_lenticular_density(vec3 p) {
	float d=1000.0;
	for(int i=0;i<3;i++) {
		float f=float(i);
		vec3 center=wx_lens_center+vec3(0.09*f,0.18*f,0.035*f);
		// Strongly flattened, round lenses; no high-frequency erosion.
		d=min(d,wx_ellipsoid(p-center,vec3(0.70-0.12*f,0.045,0.43-0.065*f)));
	}
	return 1.0-smoothstep(-0.018,0.035,d);
}
float wx_fluctus_density(vec3 p) {
	vec3 q=wx_fluctus_warp(p,2.25,2.65);
	float cell=(fract(q.x*2.0)-0.5)*0.5;
	float billow=length(vec2(cell/0.205,(q.y-2.43)/0.18))-1.0;
	float side=abs(q.z+4.0)/0.30-1.0;
	float patch=1.0-smoothstep(1.5,2.2,abs(p.x+1.0));
	return (1.0-smoothstep(-0.12,0.15,max(billow,side)))*patch;
}
float wx_vortex_density(vec3 p,float base) {
	if(vortex_intensity<=0.001) return 0.0;
	float ground=0.005, top=base+0.22;
	float h=clamp((p.y-ground)/max(top-ground,0.1),0.0,1.0);
	vec2 bend=vec2(sin(h*7.0+wx_phase),cos(h*5.0-wx_phase))*0.055*h;
	vec2 q=p.xz-wx_vortex_center-bend;
	q=wx_rotation(wx_phase*2.0+h*13.0)*q;
	float radius=mix(0.035,0.31,pow(h,1.65));
	// Ellipticity matters: rotating a perfectly circular SDF alone does nothing.
	float radial=length(q*vec2(1.0,1.16))-radius;
	float capped=max(radial,max(ground-p.y,p.y-top));
	if(capped>0.025) return 0.0;
	vec3 twisted=vec3(q.x/(radius+0.03),h*3.0,q.y/(radius+0.03));
	float erosion=(textureLod(cloud_noise,twisted*0.7,1.0).g-0.5)*0.018;
	float funnel=1.0-smoothstep(-0.012,0.016,capped+erosion);
	float collar=1.0-smoothstep(-0.025,0.035,
		wx_ellipsoid(p-vec3(wx_vortex_center.x,base+0.14,wx_vortex_center.y),vec3(0.42,0.17,0.42)));
	// UNION density with the cloud deck, rather than subtracting an empty hole.
	return max(funnel,collar)*vortex_intensity*1.4;
}
vec2 wx_ray_box(vec3 ro,vec3 rd,vec3 low,vec3 high) {
	vec3 safe=(step(vec3(0.0),rd)*2.0-1.0)*max(abs(rd),vec3(0.000001));
	vec3 a=(low-ro)/safe, b=(high-ro)/safe;
	vec3 near_t=min(a,b), far_t=max(a,b);
	return vec2(max(max(near_t.x,near_t.y),near_t.z),min(min(far_t.x,far_t.y),far_t.z));
}
float wx_hg(float mu,float g) {
	return (1.0-g*g)/(4.0*PI*pow(max(1.0+g*g-2.0*g*mu,0.001),1.5));
}
vec3 wx_powder_light(float density_value,float sun_tau,float mu,float height01,
	vec3 ordinary_sun,vec3 ordinary_ambient,vec3 to_sun) {
	float sun_T=exp(-max(sun_tau,0.0));
	float powder=1.0-exp(-2.0*density_value*0.18*6.0);
	float phase=0.85*wx_hg(mu,0.68)+0.15*wx_hg(mu,-0.25);
	float twilight=(1.0-smoothstep(0.03,0.28,abs(to_sun.y)))
		*smoothstep(-0.12,0.02,to_sun.y);
	vec3 low_air=ordinary_ambient*vec3(1.18,0.80,0.52);
	vec3 high_air=ordinary_ambient*vec3(0.78,0.89,1.12);
	vec3 ambient=mix(low_air,high_air,height01)*(1.0-0.12*wetness);
	vec3 shadow_tint=mix(vec3(0.075,0.045,0.24),vec3(0.43,0.055,0.24),1.0-height01);
	ambient=mix(ambient,shadow_tint,twilight*(1.0-sun_T)*0.85);
	vec3 sun=mix(ordinary_sun,vec3(3.0,1.35,0.24),twilight);
	sun=wx_mie_color(sun,to_sun);
	vec3 cold=vec3(0.19,0.24,0.31);
	ambient=mix(ambient,cold,wx_cyclone*0.88);
	return ambient*(0.28+0.32*powder)
		+sun*sun_T*(phase*6.283185)*(1.0+1.6*powder)*(1.0-0.98*wx_cyclone);
}
vec3 wx_nacreous(vec3 view_dir,vec3 to_sun,float wisp_noise) {
	float twilight=smoothstep(-0.14,-0.055,to_sun.y)
		*(1.0-smoothstep(-0.015,0.025,to_sun.y));
	float angle=acos(clamp(dot(normalize(view_dir),normalize(to_sun)),-1.0,1.0));
	float ramp_u=fract(angle*2.8+wisp_noise*0.18);
	vec3 pearl=textureLod(wx_iridescence_ramp,vec2(ramp_u,0.5),0.0).rgb;
	return mix(vec3(1.0),pearl*2.2,twilight*wx_formation_strength);
}
vec3 wx_haze_color(vec3 to_sun) {
	float gold=(1.0-smoothstep(0.06,0.35,abs(to_sun.y)))*smoothstep(-0.12,0.03,to_sun.y);
	vec3 sepia=mix(vec3(0.24,0.19,0.14),vec3(0.92,0.39,0.095),gold);
	sepia=mix(sepia,vec3(0.17,0.20,0.24),max(wx_cyclone,severe_storm_threat)*0.88);
	return mix(sepia,vec3(0.78,0.83,0.88),wx_whiteout);
}
float wx_height_tau(float camera_y_m,float ray_y,float distance_m,float density_m_inv,float scale_height_m) {
	float a=ray_y*distance_m/max(scale_height_m,0.1);
	float integral=abs(a)<0.001 ? 1.0-a*0.5+a*a/6.0 : (1.0-exp(clamp(-a,-40.0,40.0)))/a;
	return max(0.0,density_m_inv*exp(clamp(-camera_y_m/scale_height_m,-40.0,20.0))*distance_m*integral);
}
