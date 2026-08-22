shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, blend_mix;
// THE MEMBRANE (DREAM_TENTACLE_DIRECTION §11): the Dream encroachment on the
// wall becomes a soft violet membrane the limb comes through — not a hole.
// A disc on the wall (UV centred, radius 1 = `radius_m`), displaced along
// its normal: tension bulges it, the emerging tip presses it outward and
// stretches it thin (translucent, gold-backlit), and once the limb is
// through it clings as a ring around the root. Birth, portal, flower,
// bubble membrane and dimensional extrusion at once; no tearing.
#include "res://shaders/dream_corruption_layers.gdshaderinc"

uniform float radius_m = 0.38;
uniform float tension : hint_range(0.0, 1.0) = 0.0;
// The tip's progress through: 0 behind the wall, 1 through; and its
// radius at the plane (the ring it clings to).
uniform float through : hint_range(0.0, 1.0) = 0.0;
uniform float root_radius_m = 0.08;
uniform vec3 membrane_tint : source_color = vec3(0.33, 0.09, 0.34);
uniform vec3 gold_hot : source_color = vec3(1.0, 0.62, 0.18);
uniform float seed = 0.0;
uniform bool debug_gray = false;

varying vec2 v_uv;
varying float v_stretch;
varying vec3 v_world;

float mb_bulge(vec2 c) {
	float r = length(c) * radius_m;
	// The bulge: a dome under tension, and the tip's own press — a rounder,
	// narrower dome that grows and then passes through.
	float dome = tension * 0.06 * exp(-r * r / 0.06);
	float press = tension * (0.05 + 0.1 * through) * exp(-r * r / (0.004 + 0.01 * through));
	// Through: the membrane clings to the root as a ring, the centre
	// sitting on the body.
	float cling = through * 0.035 * exp(-pow(r - root_radius_m, 2.0) / 0.002);
	return dome + press * (1.0 - through * 0.7) + cling;
}

void vertex() {
	v_uv = UV;
	vec2 c = (UV - 0.5) * 2.0;
	float h = mb_bulge(c);
	float h_x = mb_bulge(c + vec2(0.02, 0.0)) - h;
	float h_y = mb_bulge(c + vec2(0.0, 0.02)) - h;
	v_stretch = clamp(length(vec2(h_x, h_y)) * 40.0 + tension * 0.3 * exp(-dot(c, c) * 6.0), 0.0, 1.0);
	VERTEX += NORMAL * h;
	// Animated normal: the slope of the displacement, and a slow ripple.
	float rip = 0.004 * sin(length(c) * 30.0 - TIME * 1.7 + seed) * tension;
	NORMAL = normalize(NORMAL - TANGENT * (h_x * 30.0 + rip) - BINORMAL * (h_y * 30.0 + rip));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = (v_uv - 0.5) * 2.0;
	float r = length(c);
	float edge = 1.0 - smoothstep(0.72, 1.0, r);
	// The membrane's own tissue: violet, a little mottled, wet.
	float mott = dream_corruption_fbm3(v_world * 12.0 + seed);
	vec3 tissue = membrane_tint * (0.7 + 0.6 * mott);
	// Where it stretches thin it goes translucent and the gold behind
	// shows through — the light of the thing inside before the thing.
	float thin = smoothstep(0.25, 0.9, v_stretch);
	float behind = tension * exp(-r * r * radius_m * radius_m / (0.01 + 0.02 * through));
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float hole = through * (1.0 - smoothstep(root_radius_m * 0.85, root_radius_m * 1.15, r * radius_m));
	ALBEDO = mix(tissue, tissue * 0.6 + gold_hot * 0.2, thin);
	ROUGHNESS = mix(0.32, 0.06, 0.5 + 0.5 * thin);
	SPECULAR = 0.7;
	METALLIC = 0.0;
	EMISSION = gold_hot * min(0.6, behind * (0.15 + 0.35 * thin)) * (0.8 + 0.2 * sin(TIME * 2.3 + seed))
			+ membrane_tint * 0.05 * tension;
	BACKLIGHT = tissue * 0.9;
	// Strongest at the root, fading out over the disc: a cling, not a patch.
	float cling_fade = 1.0 - smoothstep(0.18, 0.95, r);
	ALPHA = edge * cling_fade * mix(0.92, 0.5, thin) * (1.0 - hole) * (0.35 + 0.65 * max(tension, through));
	if (debug_gray) {
		ALBEDO = vec3(0.5);
		EMISSION = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 0.6;
	}
}
