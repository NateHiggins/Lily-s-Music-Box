// Metres on the actual pane. Fixed beads coalesce into slow falling trails.
// Derivative-sized edges keep subpixel droplets from sparkling during turns.
float glass_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec4 glass_moisture(vec2 p,float wet,float clock) {
	vec2 warped=p+vec2(sin(p.y*151.0+sin(p.x*91.0)),sin(p.x*131.0+p.y*71.0))*0.003;
	vec2 grid=warped/0.009;
	vec2 cell=floor(grid);
	vec2 jitter=vec2(glass_hash(cell),glass_hash(cell+17.0));
	vec2 d=fract(grid)-mix(vec2(0.28),vec2(0.72),jitter);
	float radius=mix(0.06,0.26,jitter.x)*smoothstep(0.02,0.4,wet);
	float aa=max(length(fwidth(grid)),0.035);
	float bead=1.0-smoothstep(radius-aa,radius+aa,length(d));
	bead*=smoothstep(jitter.y*0.65,jitter.y*0.65+0.15,wet);
	float column=floor(p.x/0.055);
	float seed=glass_hash(vec2(column,7.0));
	float centre=(column+0.25+seed*0.5)*0.055+sin(p.y*23.0+seed*19.0)*0.0015;
	float width=mix(0.0006,0.0015,seed);
	float line=1.0-smoothstep(width,width+max(fwidth(p.x),0.0003),abs(p.x-centre));
	float head=fract(p.y*1.8+clock*0.025+seed*5.0);
	float trail=line*smoothstep(0.0,0.08,head)*(1.0-smoothstep(0.45,0.8,head));
	trail*=smoothstep(0.25+seed*0.25,0.65,wet);
	float drops=max(bead,trail);
	float haze=wet*(0.72+0.28*glass_hash(cell*0.173))*(1.0-trail*0.75);
	return vec4(d*bead*0.8+vec2((p.x-centre)/max(width,0.0001),0.0)*trail*0.15,haze,drops);
}
