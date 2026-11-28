shader_type fog;
// Steam from a hot shower. It is born as a plume over the falling water,
// climbs, banks under the ceiling and then deepens downward as the room fills.
// When the water stops the bank thins and lifts instead of blinking out.
uniform sampler3D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float density_gain=0.0;   // owner's humidity, already scaled
uniform float fill=0.0;           // room humidity, 0..1
uniform float source_heat=0.0;    // live hot flow at the source, 0..1
uniform vec3 source_at=vec3(0.0); // world position the hot water falls from
uniform float floor_y=0.0;
uniform float ceiling_y=2.7;
// Steam is pale even in a dim room; scattered lamp light alone left it unseen.
uniform float glow=0.15;
void fog() {
	vec3 p=WORLD_POSITION;
	float h=clamp((p.y-floor_y)/max(0.1,ceiling_y-floor_y),0.0,1.0);
	// Two drifting octaves: slow rolling masses and finer rising curls.
	float broad=textureLod(cloud_noise,p*0.42+vec3(TIME*0.016,-TIME*0.035,TIME*0.011),0.0).r;
	float fine=textureLod(cloud_noise,p*1.35+vec3(-TIME*0.02,-TIME*0.10,TIME*0.03),0.0).r;
	float billow=broad*0.68+fine*0.32;
	// The bank's ragged underside starts at the ceiling and descends with fill.
	float underside=1.02-fill*1.08+(billow-0.5)*0.42;
	float bank=smoothstep(underside-0.10,underside+0.30,h);
	// A thin haze reaches the whole room once it is properly wet.
	float haze=smoothstep(0.35,1.0,fill)*0.22;
	// The plume widens as it climbs away from the spray and leans with the noise.
	vec2 lean=(vec2(broad,fine)-0.5)*0.30*h;
	float away=length(p.xz-source_at.xz-lean);
	float width=0.20+0.62*h;
	float plume=source_heat*exp(-away*away/(width*width))*smoothstep(0.08,0.30,h)*(0.45+fine);
	DENSITY=(density_gain*(bank*(0.30+billow*1.1)+haze)+plume*0.55)*clamp(-SDF*3.0,0.0,1.0);
	ALBEDO=vec3(0.86,0.88,0.87);
	EMISSION=ALBEDO*glow;
}
