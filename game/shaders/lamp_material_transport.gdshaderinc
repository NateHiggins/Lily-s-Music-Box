// Beer-Lambert transfer, in metres. Illumination remains the native light or
// shared optical sample supplied by the consumer; this function creates none.
vec3 lamp_material_transmittance(vec3 extinction_per_m, float thickness_m, float cosine) {
 float path_m=max(thickness_m,0.0)/max(abs(cosine),0.2);
 return exp(-max(extinction_per_m,vec3(0.0))*path_m);
}
