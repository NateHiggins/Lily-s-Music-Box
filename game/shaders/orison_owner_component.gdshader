shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/orison_surface.gdshaderinc"

// Source-component coordinates keep wear attached to a travelling lift cab.
// These bounded optical marks neither displace stock nor simulate drainage.
uniform mat4 component_from_mesh;
uniform vec4 component_bands[4]; // lower/upper Y, strength, feather metres
uniform float component_tone = 1.0;
uniform bool component_bond_colors = false;
uniform bool component_polish = false;
uniform bool component_roof = false;
varying vec3 component_position;
varying vec4 component_color;

void vertex() {
	v_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	v_wnormal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
	component_position=(component_from_mesh*vec4(VERTEX,1.0)).xyz;
	component_color=COLOR;
}
void fragment() {
	OrisonSurface s=orison_surface(UV,VERTEX,NORMAL,TANGENT,BINORMAL,EYE_OFFSET,VIEW_MATRIX,TIME);
	float mark=0.0;
	for (int i=0;i<4;i++) {
		vec4 b=component_bands[i];
		float feather=max(b.w,.001);
		mark=max(mark,b.z*smoothstep(b.x-feather,b.x,component_position.y)*(1.0-smoothstep(b.y,b.y+feather,component_position.y)));
	}
	vec3 p=component_position;
	float streak=.35+.65*dream_corruption_fbm3(vec3(p.x*23.0,p.y*2.0,p.z*23.0));
	mark*=streak;
	float bond=component_bond_colors ? component_color.r : 1.0;
	if (component_roof) {
		// Authored physical laps provide the mask; modest roof-coordinate
		// patch variation is strongest on those sheltered seams.
		float patch=dream_corruption_fbm3(vec3(p.x*.48,0.0,p.z*.48));
		mark+=(1.0-bond)*(.06+.09*patch);
	}
	ALBEDO=s.albedo*bond*component_tone*(1.0-mark*.28);
	ROUGHNESS=clamp(s.rough+(component_polish ? -.18 : .14)*mark,0.05,1.0);
	NORMAL=s.normal;METALLIC=s.metal;AO=s.ao;AO_LIGHT_AFFECT=ao_light_affect;
	EMISSION=s.emission;BACKLIGHT=s.backlight;
	CLEARCOAT=clearcoat;CLEARCOAT_ROUGHNESS=clearcoat_roughness;ANISOTROPY=anisotropy;
}
