shader_type fog;
// Assign only to authored OUTDOOR FogVolumes. This shader does not discover indoor cover.
uniform sampler2D low_fog_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 fog_offset = vec2(0.0);
uniform float cyclone_strength = 0.0;
uniform float whiteout_strength = 0.0;
uniform float coal_density = 0.00035;
uniform float datum_y_m = 0.0;
uniform float fog_band_height_m = 18.0;
uniform float fog_band_width_m = 9.0;
uniform vec3 coal_color : source_color = vec3(0.32,0.24,0.16);
uniform vec3 storm_color : source_color = vec3(0.19,0.24,0.31);
void fog() {
	float height=WORLD_POSITION.y-datum_y_m;
	float coal=coal_density*exp(clamp(-height/140.0,-20.0,3.0));
	vec2 uv=WORLD_POSITION.xz*0.003-fog_offset;
	float noise=textureLod(low_fog_noise,uv,1.0).r;
	float gaussian=exp(-0.5*pow((height-fog_band_height_m)/max(fog_band_width_m,0.1),2.0));
	float sheets=cyclone_strength*gaussian*noise*noise*0.035;
	DENSITY=coal+sheets+whiteout_strength*0.045;
	ALBEDO=mix(mix(coal_color,storm_color,cyclone_strength),vec3(0.82,0.87,0.92),whiteout_strength);
}
