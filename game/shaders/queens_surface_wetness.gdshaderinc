global uniform float wetness;
// Call after the existing material's PBR maps have been sampled.
// exposure is supplied by the existing surface/cover owner, not a global indoor guess.
void wx_apply_wetness(inout vec3 albedo,inout float roughness,inout float specular,float exposure) {
	float w=clamp(wetness*exposure,0.0,1.0);
	albedo*=mix(1.0,0.68,w);
	roughness=mix(roughness,max(0.055,roughness*0.32),w);
	specular=mix(specular,0.65,w);
}
