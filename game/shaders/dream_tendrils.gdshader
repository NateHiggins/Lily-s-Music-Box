shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// SURFACE TENDRILS (DF-13). Many small limbs where the Dream Field's
// cross-section meets matter — the shelved procedural tentacle, reduced to
// what a swarm needs.
//
// One mesh, one draw. Every tendril is a run of rings in the same buffer;
// UV2.x is its index, UV.y its place along it, and the vertex stage bends
// it onto that tendril's six-joint spine. Nothing is instanced, nothing
// allocates.
//
// They wear the SAME material stack as the hero creature, because they are
// the same organism — that is the whole point of the ruling.
#include "res://shaders/dream_corruption_layers.gdshaderinc"
#include "res://shaders/dream_entity_surface.gdshaderinc"

const int MAX_TENDRILS = 24;
const int JOINTS = 6;

uniform vec3 tendril_spine[144];      // MAX_TENDRILS * JOINTS
uniform float tendril_grow[24];
uniform float tendril_seed[24];
uniform int tendril_count = 0;
uniform float base_radius = 0.019;
uniform float tip_radius = 0.0026;

varying vec2 v_uv;
varying vec3 v_world;
varying float v_thickness;
varying float v_seed;

vec3 spine_at(int t, float s) {
	float x = clamp(s, 0.0, 1.0) * float(JOINTS - 1);
	int i = int(floor(min(x, float(JOINTS - 1) - 0.001)));
	float f = x - float(i);
	int base = t * JOINTS;
	return mix(tendril_spine[base + i], tendril_spine[base + min(i + 1, JOINTS - 1)], f);
}

void vertex() {
	int t = int(UV2.x + 0.5);
	float v = UV.y;
	float u = UV.x;
	float grow = tendril_grow[t];
	// The part not yet through collapses onto the anchor, so it extrudes
	// from the surface rather than appearing.
	float s = min(v, grow);
	float alive = smoothstep(0.0, 0.06, grow - v * 0.9);
	vec3 p = spine_at(t, s);
	vec3 tng = normalize(spine_at(t, min(s + 0.08, 1.0)) - spine_at(t, max(s - 0.08, 0.0))
			+ vec3(0.0, 1e-5, 0.0));
	vec3 any = abs(tng.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 sd = normalize(cross(any, tng));
	vec3 bn = cross(tng, sd);
	float sd_seed = tendril_seed[t];
	// A taper with a small club at the tip, and a flare where it leaves the
	// surface — the same anatomy as the hero, at a tenth the size.
	float taper = mix(base_radius, tip_radius, pow(v, 1.25));
	float flare = 1.0 + 0.62 * exp(-v * 6.0);
	float club = 1.0 + 0.5 * smoothstep(0.86, 0.97, v) * (1.0 - smoothstep(0.97, 1.0, v));
	float breathe = 1.0 + 0.05 * sin(TIME * 2.1 + sd_seed);
	float r = taper * flare * club * breathe * alive;
	float a = u * 6.2831853 + sd_seed;
	vec3 radial = sd * cos(a) + bn * sin(a);
	VERTEX = p + radial * r;
	NORMAL = radial;
	TANGENT = tng;
	BINORMAL = cross(radial, tng);
	v_uv = vec2(u, v);
	v_world = VERTEX;
	// Thin at the tip, thick at the root: the same thickness rule that
	// drives the hero's scatter.
	v_thickness = clamp(0.85 - 0.75 * v, 0.0, 1.0);
	v_seed = sd_seed;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	DeCtx ctx;
	ctx.thickness = v_thickness;
	ctx.vein = 0.0;
	ctx.contact = 0.0;
	ctx.gold_root = 0.0;
	ctx.socket = 0.0;
	ctx.stretch = 0.3;
	ctx.lod = 1.0 - smoothstep(1.5, 5.0, length(VERTEX));
	DeMasks m = de_masks(v_world, v_uv, n, view_dir, TIME, v_seed, ctx);
	DeOut o = de_shade(m, v_world, v_uv, n, view_dir, TIME, v_seed, ctx);
	ALBEDO = o.albedo;
	METALLIC = o.metallic;
	ROUGHNESS = o.roughness;
	SPECULAR = o.specular;
	EMISSION = o.emission * 2.4;
	BACKLIGHT = o.backlight;
	AO = o.ao;
	AO_LIGHT_AFFECT = 0.35;
	SSS_STRENGTH = o.sss;
	SSS_TRANSMITTANCE_COLOR = o.sss_transmit;
	SSS_TRANSMITTANCE_DEPTH = o.sss_depth;
	SSS_TRANSMITTANCE_BOOST = o.sss_boost;
	CLEARCOAT = o.clearcoat;
	CLEARCOAT_ROUGHNESS = o.clearcoat_roughness;
	vec3 nm = o.normal_map;
	NORMAL = normalize(NORMAL + TANGENT * nm.x * 0.6 + BINORMAL * nm.y * 0.6);
}
