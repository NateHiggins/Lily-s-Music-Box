global uniform float wetness;
global uniform float weather_blood;
// Call after the existing material's PBR maps have been sampled.
// exposure is supplied by the existing surface/cover owner, not a global indoor guess.
void wx_apply_wetness(inout vec3 albedo,inout float roughness,inout float specular,float exposure,float upward) {
	float w=clamp(wetness*exposure,0.0,1.0);
	albedo*=mix(1.0,0.68,w);
	roughness=mix(roughness,mix(max(.18,roughness*.65),.035,upward),w);
	specular=mix(specular,0.65,w);
	float crimson=clamp(weather_blood*exposure,0.0,1.0);
	albedo=mix(albedo,albedo*vec3(.38,.035,.025)+vec3(.045,0.0,0.0),crimson);
	roughness=mix(roughness,mix(.15,.025,upward),crimson*w);
}
