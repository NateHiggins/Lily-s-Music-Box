shader_type fog;
uniform sampler3D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 wind_offset = vec3(0.0);
uniform float density_gain = 0.0;
void fog() {
	// Engine froxel light/shadow integration gives actual occluded light shafts.
	float field=textureLod(cloud_noise,WORLD_POSITION*.035-wind_offset*.10,2.0).r;
	float edge=clamp(-SDF*1.2,0.0,1.0);
	DENSITY=density_gain*(.5+field)*edge;
	ALBEDO=vec3(.77,.83,.92);
}
