shader_type fog;
uniform sampler3D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 wind_offset = vec3(0.0);
uniform float density_gain = 0.0;
// The ash wall off the Corona dumps: a 2D noise front advancing downwind.
uniform float dust_gain = 0.0;
uniform vec2 dust_direction = vec2(1.0, 0.0);
uniform float dust_front = -1000.0;
void fog() {
	// Engine froxel light/shadow integration gives actual occluded light shafts.
	float field=textureLod(cloud_noise,WORLD_POSITION*.035-wind_offset*.10,2.0).r;
	float edge=clamp(-SDF*1.2,0.0,1.0);
	DENSITY=density_gain*(.5+field)*edge;
	ALBEDO=vec3(.77,.83,.92);
	if (dust_gain>0.0) {
		vec2 ground=WORLD_POSITION.xz;
		float billow=textureLod(cloud_noise,vec3(ground*.02-wind_offset.xz*.6,WORLD_POSITION.y*.04),1.0).r;
		// Behind the front (upwind of it) the air is full of ash.
		float behind=1.0-smoothstep(dust_front-6.0,dust_front+8.0,dot(ground,dust_direction)-8.0*billow);
		float dust=dust_gain*behind*(.4+billow)*edge;
		ALBEDO=mix(ALBEDO,vec3(.62,.45,.26),clamp(dust/(DENSITY+dust+1e-5),0.0,1.0));
		DENSITY+=dust;
	}
}
