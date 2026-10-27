shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ORISON SURFACE, opaque. The layered surface system (TASKS.md §MX) with no
// alpha path at all: masonry, floors, trims, props. The work and every
// uniform live in orison_surface.gdshaderinc; this file owns the entry
// points and writes the built-ins from the struct. Cutouts (torn finishes,
// mesh, holes) use orison_surface_cutout.gdshader instead, so the discard
// path is paid only where the surface really has holes.

#include "res://shaders/orison_surface.gdshaderinc"
#include "res://shaders/queens_surface_wetness.gdshaderinc"
uniform float weather_exposure : hint_range(0.0,1.0) = 0.0;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	OrisonSurface s = orison_surface(UV, VERTEX, NORMAL, TANGENT, BINORMAL,
			EYE_OFFSET, VIEW_MATRIX, TIME);
	ALBEDO = s.albedo;
	NORMAL = s.normal;
	ROUGHNESS = s.rough;
	float wet_specular=0.5;
	float upward=smoothstep(.3,.9,normalize(v_wnormal).y);
	wx_apply_wetness(ALBEDO,ROUGHNESS,wet_specular,weather_exposure,upward);
	float ripple=wetness*weather_exposure*upward;
	if(ripple>.001) {
		vec3 perturb=vec3(sin(v_world.x*19.0+v_world.z*7.0+TIME*.8),0.0,cos(v_world.z*23.0-v_world.x*5.0+TIME*.65))*.045*ripple;
		NORMAL=normalize(NORMAL+(VIEW_MATRIX*vec4(perturb,0.0)).xyz);
	}
	SPECULAR=wet_specular;
	METALLIC = s.metal;
	AO = s.ao;
	AO_LIGHT_AFFECT = ao_light_affect;
	EMISSION = s.emission;
	BACKLIGHT = s.backlight;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	ANISOTROPY = anisotropy;
}
