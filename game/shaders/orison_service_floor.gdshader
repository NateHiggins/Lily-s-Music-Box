shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/orison_surface.gdshaderinc"

// Small residue footprints at existing wet-work/firing owners. The complete
// floor and its catalogue projection remain; this creates no new geometry.
uniform vec4 service_patches[3]; // world XZ centre, radius, strength
uniform vec3 service_residue : source_color = vec3(.48,.45,.38);
uniform float service_roughness = .78;

void vertex() {
	v_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	v_wnormal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
}
void fragment() {
	OrisonSurface s=orison_surface(UV,VERTEX,NORMAL,TANGENT,BINORMAL,EYE_OFFSET,VIEW_MATRIX,TIME);
	float amount=0.0;
	for (int i=0;i<3;i++) {
		vec4 patch=service_patches[i];
		float distance_m=length(v_world.xz-patch.xy);
		float field=1.0-smoothstep(patch.z*.25,patch.z,distance_m);
		amount=max(amount,field*patch.w);
	}
	float irregular=.35+.65*dream_corruption_fbm3(v_world*17.0);
	amount*=irregular*smoothstep(.7,.95,v_wnormal.y);
	ALBEDO=mix(s.albedo,service_residue,amount);
	ROUGHNESS=mix(s.rough,service_roughness,amount);
	NORMAL=s.normal;METALLIC=s.metal;AO=s.ao;AO_LIGHT_AFFECT=ao_light_affect;
	EMISSION=s.emission;BACKLIGHT=s.backlight;
}
