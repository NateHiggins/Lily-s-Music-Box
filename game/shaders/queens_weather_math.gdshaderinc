// Proposal: kilometres for cloud positions; metres only in wx_height_tau().
// Include after the existing cloud_noise, sun_direction and wind uniforms.
global uniform float wetness;
uniform float severe_storm_threat = 0.0;
uniform float vortex_intensity = 0.0;
uniform float wx_cyclone = 0.0;
uniform float wx_hail = 0.0;
uniform float wx_whiteout = 0.0;
uniform float wx_blood_rain = 0.0;
uniform int wx_formation = 0; // 1 asperitas, 2 fluctus, 3 lenticular, 4 iridescent
uniform float wx_formation_strength = 0.0;
uniform float wx_phase = 0.0;
uniform float wx_cyclone_phase = 0.0;
uniform float wx_texture_phase = 0.0;
uniform float wx_fluctus_phase = 0.0;
uniform vec4 wx_cloud_drift = vec4(0.0);
uniform vec4 wx_asperitas_drift = vec4(0.0);
uniform vec4 wx_cirrus_drift = vec4(0.0);
uniform vec3 wx_camera_km = vec3(0.0);
uniform vec2 wx_cyclone_center = vec2(5.0, -8.0);
uniform vec2 wx_vortex_center = vec2(2.2, -3.5);
uniform vec3 wx_lens_center = vec3(-2.0, 3.0, -4.0);
uniform sampler2D wx_iridescence_ramp : source_color, filter_linear, repeat_enable;
// Three observed strata in the existing bounded march; no additional viewport.
uniform bool living_enabled = false;
uniform bool living_fluid_enabled = true;
uniform sampler3D cloud_macro : filter_linear_mipmap, repeat_enable;
uniform sampler3D cloud_curl : filter_linear_mipmap, repeat_enable;
uniform vec2 living_flow_0;
uniform vec2 living_flow_1;
uniform vec2 living_flow_2;
uniform float living_aerosol = .2;
uniform vec4 living_layer_0 = vec4(0.0,1.25,1.6,8.0);
uniform vec4 living_layer_1 = vec4(0.0,3.8,0.65,3.0);
uniform vec4 living_layer_2 = vec4(0.0,8.0,0.3,0.0);
uniform vec4 living_motion_0;
uniform vec4 living_motion_1;
uniform vec4 living_motion_2;
uniform vec4 living_drift_0;
uniform vec4 living_drift_1;
uniform vec4 living_drift_2;
uniform vec4 living_brush_0 = vec4(2.0,.9,1.0,0.0);
uniform vec4 living_brush_1 = vec4(1.2,.65,1.0,0.0);
uniform vec4 living_brush_2 = vec4(3.8,.22,9.0,0.0);

float wx_remap(float value,float old_min,float old_max,float new_min,float new_max) {
	return mix(new_min,new_max,(value-old_min)/max(old_max-old_min,.0001));
}
vec3 curl_noise3d(vec3 p) {
	// Periodic curl of a 3D vector potential, differentiated offline. One tap
	// replaces twelve derivative taps inside every view and self-shadow march.
	return textureLod(cloud_curl,p,0.0).rgb*2.0-1.0;
}
float wx_height_erosion(float body,float detail,float h,float strength) {
	float top=smoothstep(.20,.90,h);
	float threshold=mix(1.0-detail,detail,top)*mix(.08,.26,top)*strength;
	// Preserve dense cores; spend erosion on boundaries and high shear.
	threshold*=1.0-smoothstep(.72,1.0,body);
	return clamp(wx_remap(body,threshold,1.0,0.0,1.0),0.0,1.0);
}
float cloud_ramp_integral(float x) {
	float u=clamp(x,0.0,1.0);
	return u*u*u*(1.0-.5*u)+max(x-1.0,0.0);
}
float cloud_filtered_ramp(float a,float b,float h,float width) {
	if(width<.0001) return smoothstep(a,b,h);
	float x=(h-a)/(b-a), w=width/(b-a);
	return clamp((cloud_ramp_integral(x+w*.5)-cloud_ramp_integral(x-w*.5))/w,0.0,1.0);
}
// The primary density uses zero footprint. Self-shadow taps integrate over the
// view step they illuminate: loaded mips and a box-filtered height ramp suppress
// undersampled lighting blocks without filtering the visible cloud silhouette.
float living_density(vec3 p,vec4 layer,vec4 motion,vec4 brush,vec4 drift,vec2 flow_state,vec3 footprint) {
	float coverage=layer.x;
	if(coverage<=0.0001 || p.y<layer.y || p.y>layer.y+layer.z) return 0.0;
	float h=(p.y-layer.y)/layer.z;
	float wind_c=cos(brush.w), wind_s=sin(brush.w);
	// Rotate around the observer's regional origin, not the year's accumulated
	// travel. A small wind turn must not rotate thousands of kilometres of UV.
	vec2 q=(mat2(vec2(wind_c,-wind_s),vec2(wind_s,wind_c))*p.xz)/max(brush.x,.1);
	q+=vec2(mod(motion.w,127.0),mod(motion.w,71.0));
	int genus=int(layer.w);
	float qwidth=length(footprint.xz)/max(brush.x,.1);
	float hwidth=living_fluid_enabled ? footprint.y/max(layer.z,.01) : 0.0;
	float body=0.0;
	float texture_detail=.6;
	bool sheet=(genus==2 || genus==4 || genus==5 || genus==7);
	bool rounded=(genus==3 || genus==6 || genus==8); // Ac, Sc, Cu; not the high ice plane.
	if(living_fluid_enabled && genus!=0) {
		// Wind-aligned leaning; cirrus retains its distinct ice-fibre brush.
		q.x-=h*h*flow_state.y*.55;
	}
	if(sheet) {
		vec2 sheet_noise=textureLod(cloud_noise,vec3(q*.125+motion.xy,motion.z*3.0),1.0).rg;
		float broad=sheet_noise.r;
		if(living_fluid_enabled) {
			vec3 roll=curl_noise3d(vec3(q*.043+drift.xy,h*.18+flow_state.x));
			h+=roll.z*.10*sin(h*3.14159265359);
		}
		texture_detail=sheet_noise.g;
		body=smoothstep(1.0-coverage-.10,1.0-coverage+.10,broad);
		if(coverage>.94) body=mix(body,1.0,smoothstep(.94,1.0,coverage));
		body*=.65+.35*broad;
		// A continuous ceiling still has a relief underside. Reuse this tap;
		// coverage must not flatten its bottom into a horizontal card.
		h-=(1.0-broad)*.22*(1.0-smoothstep(.20,.75,h));
	} else if(genus==0) {
		// Broad ice packets contain finer curved fibres. Stretching a thresholded
		// volume alone produced solid white blades tens of kilometres across.
		// The continuous packet has no binary edge; the existing stroke stock
		// only modulates its fibres, rather than drawing sharp white ribbons.
		vec2 uv=vec2(q.x*.08,q.y*.24+sin(q.x*.22+drift.z)*.025)+motion.xy;
		vec2 ice_noise=textureLod(cloud_noise,vec3(uv,.17+motion.z),1.0).rg;
		texture_detail=ice_noise.g;
		float packet=clamp((ice_noise.r-(.38-coverage*.25))/.45,0.0,1.0);
		vec2 fibre_uv=uv+(ice_noise-.5)*vec2(.60,.35);
		float strokes=texture(cirrus_tex,fibre_uv).r;
		body=packet*packet*mix(.5,1.0,ice_noise.g)*mix(.70,1.0,strokes);
		// Unresolved distant fibres become a faint veil instead of a repeating
		// fan of lines aimed at the horizon. This changes ice, not world fog.
		float distant_ice=smoothstep(25.0,60.0,length(p.xz-wx_camera_km.xz));
		body=mix(body,coverage*.05,distant_ice);
	} else {
		// Continuous warped masses avoid a visible grid of identical ellipsoids.
		// Reuse the existing two-channel volume; no new texture or march steps.
		vec2 warp;
		if(living_fluid_enabled) {
			// Ordinary families share a column-coherent footprint. Independent
			// height slices otherwise fill one another's holes into an overcast.
			vec3 roll=curl_noise3d(vec3(q*.043+drift.xy,(rounded ? 0.0 : h*.30)+flow_state.x));
			warp=roll.xy*.5;
			h+=roll.z*.13*sin(h*3.14159265359);
		} else warp=textureLod(cloud_noise,vec3(q*.043+drift.xy,motion.z),1.0).rg-.5;
		vec2 marks=q+warp*3.0;
		if(int(brush.z)==4 || int(brush.z)==9) marks.y*=genus==1 ? .70 : .32;
		// Keep in step with living_sky.gd, which transports the same coordinate.
		float mark_scale=genus==1 ? .30 : .40;
		// Match horizontal and vertical kilometres for ordinary billows. A fixed
		// .55 cycles per layer compressed Sc lobes almost fourfold into pancakes.
		float vertical_scale=rounded ? clamp(layer.z*mark_scale/max(brush.x,.1),.10,.65) : .55;
		vec3 lookup=vec3(marks*mark_scale+motion.xy,h*vertical_scale+motion.z*2.0);
		vec2 field;
		if(living_fluid_enabled) {
			// Nested Worley deformation is small enough to retain broad families.
			// A distant view ray covers many texels too: without this the far deck
			// aliases into fans converging on the horizon.
			float view_width=length(p.xz-wx_camera_km.xz)*.012/max(brush.x,.1);
			float width=max(qwidth,view_width)*mark_scale;
			float detail_lod=clamp(log2(max(1.0,64.0*3.0*max(width,hwidth*vertical_scale))),1.0,5.0);
			float macro_lod=clamp(log2(max(1.0,128.0*max(width,hwidth*vertical_scale))),1.0,6.0);
			vec2 detail=textureLod(cloud_noise,lookup*3.0,detail_lod).rg;
			lookup.xy+=(detail-.5)*.10;
			field=vec2(textureLod(cloud_macro,lookup,macro_lod).r,detail.g);
			// The tile repeats every few kilometres, and in perspective a repeating
			// grid reads as rays from the horizon. Far away, cross-fade to a slower
			// rotated copy so the deck has no axis left to show.
			float far_field=smoothstep(7.0,22.0,length(p.xz-wx_camera_km.xz));
			if(far_field>.001) {
				vec2 slow=mat2(vec2(.80,-.60),vec2(.60,.80))*lookup.xy*.31;
				field.x=mix(field.x,textureLod(cloud_macro,vec3(slow,lookup.z),macro_lod).r,far_field);
			}
		} else field=textureLod(cloud_noise,lookup,1.0).rg;
		texture_detail=field.y;
		// Sculpt both bearings with the existing volume sample. The former
		// shallow Z slice extruded flat islands through the whole cloud depth.
		h-=(1.0-field.x)*.35*(1.0-smoothstep(.20,.80,h));
		h+=(1.0-field.x)*.18*smoothstep(.40,.90,h);
		float mass=field.x; // Worley is erosion, never a second field of tiny bodies.
		float upper=genus==1 ? .43 : ((genus==3 || genus==6) ? .70 : .78);
		mass-=pow(max(h-.12,0.0)/upper,2.0)*.18;
		if(int(brush.z)==5) mass+=sin(q.y*2.2+drift.z+warp.x*4.0)*.08;
		if(int(brush.z)==6) mass+=sin(q.x*.16+drift.w)*.10;
		if(int(brush.z)==8) mass-=.07*(1.0-field.y);
		// Linear ordinary coverage avoids filling a long ray with many weak
		// sqrt-coverage hits. A graded interior retains light and shadow relief.
		float edge_width=(rounded || genus==1) ? .060 : .025;
		float edge_center=.725-.40*(rounded ? coverage : sqrt(coverage));
		body=smoothstep(edge_center-edge_width,edge_center+edge_width,mass);
		// Billowed edges on the view ray only: the lighting taps keep their
		// filtered footprint and spend nothing on detail they could not resolve.
		if(living_fluid_enabled && qwidth==0.0 && body>.001 && body<.999) {
			// Fine detail fades out before it is smaller than a pixel; unfiltered
			// it aliased into rays converging on the horizon.
			float distance_km=length(p.xz-wx_camera_km.xz);
			float near_detail=1.0-smoothstep(5.0,16.0,distance_km);
			if(near_detail>.001) {
				float billow=textureLod(cloud_noise,lookup*7.0,clamp(1.0+log2(1.0+distance_km*.6),1.0,5.0)).g;
				body=clamp(body-(1.0-billow)*(rounded ? .28 : .55)*near_detail*(1.0-body),0.0,1.0);
			}
		}
		body=mix(body,.7+.3*field.x,smoothstep(.88,1.0,coverage));
		// Small cells belong to broad families, with open sky between families.
		// Reuse the existing warp tap rather than adding another noise octave.
		float family=smoothstep(.36-.20*coverage,.60-.20*coverage,warp.x+.5);
		body*=mix(family,1.0,smoothstep(.70,.96,coverage));
		// The high plane reaches 100 km and more. Past what the eye could resolve
		// it is a thin even veil, not a pattern repeated thirty times over.
		float veil=smoothstep(26.0,60.0,length(p.xz-wx_camera_km.xz));
		body=mix(body,coverage*.7,veil);
		texture_detail=mix(texture_detail,.5,veil);
	}
	float envelope=cloud_filtered_ramp(0.0,.10,h,hwidth)*(1.0-cloud_filtered_ramp(.72,1.0,h,hwidth));
	float sculpted=genus==0 ? body*mix(.75,1.0,texture_detail)
		: (living_fluid_enabled ? wx_height_erosion(body,texture_detail,h,1.0) : max(0.0,body-(1.0-texture_detail)*.12));
	return sculpted*envelope*brush.y;
}

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
	// A persistent spiral with bounded, slow breathing shear. Accumulating
	// angle/radius for hours crushes the density field into radial streaks.
	float shear=1.25*sin(wx_cyclone_phase*0.15)/(0.8+radius*0.08);
	float angle=weight*(shear+1.8*log(1.0+radius));
	p.xz=wx_cyclone_center+wx_rotation(angle)*r;
	return p;
}
float wx_cloud_base() {
	return mix(1.25,0.62,max(wx_hail,wx_cyclone));
}
float wx_asperitas_bottom(vec3 p,float base) {
	float waves=sin(p.x*1.8+wx_phase+wx_asperitas_drift.z)*0.60
		+sin(p.z*2.3-p.x*.8+wx_phase*0.5+wx_asperitas_drift.w)*0.40;
	// G is the supplied Worley channel; filter at a coarse mip for smooth pouches.
	float voronoi=textureLod(cloud_noise,p*0.8+vec3(wx_asperitas_drift.x,0.0,wx_asperitas_drift.y),2.0).g;
	float pouch=pow(1.0-smoothstep(0.18,0.85,voronoi),2.0);
	return base+0.48*waves-0.24*pouch;
}
float wx_asperitas_relief(vec3 p,vec3 to_sun) {
	// Analytic slope of the same broad waves: no extra density/noise taps.
	float a=p.x*1.8+wx_phase+wx_asperitas_drift.z;
	float b=p.z*2.3-p.x*.8+wx_phase*0.5+wx_asperitas_drift.w;
	float dx=0.48*(0.60*1.8*cos(a)-0.40*.8*cos(b));
	float dz=0.48*0.40*2.3*cos(b);
	vec3 underside=normalize(vec3(dx,-1.0,dz));
	vec3 sky_fill=normalize(vec3(to_sun.x,.12,to_sun.z));
	float slope=smoothstep(-.65,.55,dot(underside,sky_fill));
	float hollow=.5+.5*(.6*sin(a)+.4*sin(b));
	return clamp(.15+.65*slope+.20*hollow,.0,1.0);
}
vec3 wx_fluctus_warp(vec3 p,float layer_bottom,float layer_top) {
	// Finite patch and vertical gate: do not turn the entire sky into a sawtooth.
	float patch=1.0-smoothstep(1.5,3.0,length(p.xz-vec2(-1.0,-4.0)));
	float h=clamp((p.y-layer_bottom)/max(layer_top-layer_bottom,0.01),0.0,1.0);
	float crest=smoothstep(0.35,1.0,h)*patch;
	float phase=p.x*2.6+wx_fluctus_phase;
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
	float ground=0.005, top=base+0.48;
	float h=clamp((p.y-ground)/max(top-ground,0.1),0.0,1.0);
	vec2 bend=vec2(sin(h*7.0+wx_phase),cos(h*5.0-wx_phase))*0.055*h;
	vec2 q=p.xz-wx_vortex_center-bend;
	q=wx_rotation(wx_phase*2.0+h*13.0)*q;
	// Continuous flaring root enters the opaque deck, rather than a separate
	// ellipsoid perched on a capped tube. Its cap stays buried inside cloud.
	float radius=0.035+0.18*pow(h,1.4)+0.48*pow(h,6.0);
	// Ellipticity matters: rotating a perfectly circular SDF alone does nothing.
	float radial=length(q*vec2(1.0,1.16))-radius;
	float capped=max(radial,max(ground-p.y,p.y-top));
	if(capped>0.5) return 0.0; // Skip noise taps far outside the tube/root.
	vec3 twisted=vec3(q.x/(radius+0.03),h*3.0,q.y/(radius+0.03));
	float erosion=(textureLod(cloud_noise,twisted*0.7,1.0).g-0.5)*0.018;
	float funnel=1.0-smoothstep(-0.012,0.016,capped+erosion);
	return funnel*vortex_intensity*1.4;
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
	// The warm bounce under a cloud belongs to a low Sun. At midday a cloud base
	// is cool grey; a fixed warm tint turned every low deck sand-coloured.
	vec3 low_air=ordinary_ambient*mix(vec3(1.18,0.80,0.52),vec3(.86,.90,.98),smoothstep(.12,.45,to_sun.y));
	vec3 high_air=ordinary_ambient*vec3(0.78,0.89,1.12);
	vec3 ambient=mix(low_air,high_air,height01)*(1.0-0.12*wetness);
	ambient=mix(ambient,ambient*vec3(1.25,.35,.85),wx_blood_rain*.75);
	vec3 shadow_tint=mix(vec3(0.075,0.045,0.24),vec3(0.43,0.055,0.24),1.0-height01);
	ambient=mix(ambient,shadow_tint,twilight*(1.0-sun_T)*0.85);
	vec3 sun=mix(ordinary_sun,vec3(3.0,1.35,0.24),twilight);
	sun=wx_mie_color(sun,to_sun);
	sun=mix(sun,sun*vec3(1.1,.25,.65),wx_blood_rain*.7);
	vec3 cold=vec3(0.19,0.24,0.31);
	ambient=mix(ambient,cold,wx_cyclone*0.88);
	// Dense ice/water cores absorb the exaggerated forward lobe. Thin sunlit
	// edges retain the powder bloom instead of washing the entire deck white.
	float core_transmission=exp(-1.4*density_value*density_value);
	return ambient*(0.28+0.32*powder)
		+sun*sun_T*core_transmission*(min(phase*3.141593,1.2))*(1.0+.65*powder)*(1.0-0.98*wx_cyclone);
}
float wx_nacreous_gate(vec3 to_sun) {
	return smoothstep(-0.14,-0.055,to_sun.y)
		*(1.0-smoothstep(-0.015,0.025,to_sun.y));
}
vec3 wx_nacreous(vec3 view_dir,vec3 to_sun,float wisp_noise) {
	float twilight=wx_nacreous_gate(to_sun);
	float angle=acos(clamp(dot(normalize(view_dir),normalize(to_sun)),-1.0,1.0));
	float ramp_u=fract(angle*2.8+wisp_noise*0.18);
	vec3 pearl=textureLod(wx_iridescence_ramp,vec2(ramp_u,0.5),0.0).rgb;
	return mix(vec3(1.0),pearl*2.2,twilight*wx_formation_strength);
}
vec3 wx_haze_color(vec3 to_sun) {
	float gold=(1.0-smoothstep(0.06,0.35,abs(to_sun.y)))*smoothstep(-0.12,0.03,to_sun.y);
	vec3 sepia=mix(vec3(0.24,0.19,0.14),vec3(0.92,0.39,0.095),gold);
	sepia=mix(sepia,vec3(0.17,0.20,0.24),max(wx_cyclone,severe_storm_threat)*0.88);
	vec3 haze=mix(mix(sepia,vec3(0.78,0.83,0.88),wx_whiteout),vec3(.28,.065,.17),wx_blood_rain*.8);
	// Extinction persists at night, but unlit coal haze cannot radiate daylight.
	return haze*mix(.035,1.0,smoothstep(-.18,.03,to_sun.y));
}
float wx_height_tau(float camera_y_m,float ray_y,float distance_m,float density_m_inv,float scale_height_m) {
	float a=ray_y*distance_m/max(scale_height_m,0.1);
	float integral=abs(a)<0.001 ? 1.0-a*0.5+a*a/6.0 : (1.0-exp(clamp(-a,-40.0,40.0)))/a;
	return max(0.0,density_m_inv*exp(clamp(-camera_y_m/scale_height_m,-40.0,20.0))*distance_m*integral);
}
