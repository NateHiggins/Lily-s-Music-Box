shader_type fog;
uniform sampler3D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float density_gain=0.0;
void fog() {
	float field=textureLod(cloud_noise,WORLD_POSITION*0.7-vec3(0.0,TIME*0.025,0.0),1.0).r;
	DENSITY=density_gain*(0.35+field)*clamp(-SDF*3.0,0.0,1.0);
	ALBEDO=vec3(0.82,0.85,0.82);
}
