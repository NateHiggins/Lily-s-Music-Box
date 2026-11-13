shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, sss_mode_skin;
// THE WAKING COLONY'S CILIA: jointed limbs, not hairs (Lily, 2026-11-09:
// "writhe like insect legs").
//
// The Blender cilium has three segments with knuckles and a curled rest pose;
// Anatomy R is the distance along it (0 root, 1 tip), G its segment (0, .5, 1).
// Each instance swings at the root and flexes at both knuckles about the
// joints' real rest positions, so the limb stays one connected body.
//
// Below the root (Lily, 2026-11-13) are a basal body and a rootlet: the limb
// starts inside the cell, at the CiliumRoots the build places just under the
// membrane, and leaves through it. They swing with the root as one lever.
//
// The gait is a stepping stroke, not a sine: a fast power stroke and a slower,
// lifted recovery. Its phase travels around the colony (INSTANCE_CUSTOM.x is
// the cilium's place around the skirt), so the fringe ripples like a
// millipede's legs. ~3.5 Hz keeps eight or more frames in a stride at 30 fps.

uniform float cell_time = 0.0;
uniform float gait_rate = 3.4;
uniform float gait_waves = 3.0;      // ripples around the skirt
uniform float stroke = 0.55;         // root swing, radians
uniform vec3 base_color : source_color = vec3(0.62, 0.42, 0.72);
uniform vec3 tip_color : source_color = vec3(0.95, 0.78, 1.0);
uniform float opal_gain = 0.7;
// The limb's cuticle is a registered recipe on the cilium's authored UVs
// (u around, v along): art/tools/build_waking_colony_maps.py, RUL-012.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_tile = vec2(1.0, 3.0);
uniform float normal_depth = 0.8;

// The Blender rest pose (build_waking_colony.py): segment lengths and the
// turn at each knuckle about local X. Blender X is Godot X; Blender's Z-up
// arrives as Godot Y-up, and its -Y as Godot +Z.
const float L0 = 0.050;
const float L1 = 0.044;
const float TURN1 = 0.55;

varying float v_along;
varying float v_flash;

vec3 rot_x(vec3 p, float a) {
	float c = cos(a), s = sin(a);
	return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

vec3 rot_y(vec3 p, float a) {
	float c = cos(a), s = sin(a);
	return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

vec3 about(vec3 p, vec3 pivot, float a) {
	return pivot + rot_x(p - pivot, a);
}

void vertex() {
	v_along = COLOR.r;
	int seg = int(COLOR.g * 2.0 + 0.5);
	float around = INSTANCE_CUSTOM.x;
	float jitter = INSTANCE_CUSTOM.y;
	float t = cell_time * gait_rate * (0.9 + 0.2 * jitter);
	float s = fract(t - around * gait_waves + jitter * 0.15);
	// Power stroke over the first third, recovery over the rest.
	float power = smoothstep(0.0, 0.33, s);
	float recover = smoothstep(0.33, 1.0, s);
	float root = s < 0.33 ? mix(-stroke, stroke, power) : mix(stroke, -stroke, recover);
	float lift = s < 0.33 ? 0.0 : sin(recover * 3.14159);
	// Knuckles fold on the recovery (the leg lifts) and snap straight on the
	// power stroke; a rare twitch rides the tarsus.
	float twitch = pow(max(0.0, sin(cell_time * 0.9 + jitter * 40.0)), 24.0);
	float k1 = 0.15 + 0.65 * lift;
	float k2 = 0.10 + 0.55 * lift + 0.7 * twitch * sin(cell_time * 31.0 + jitter * 9.0);
	// Joint pivots in the rest pose (Godot axes: up is +Y, the curl is about X).
	vec3 p1 = vec3(0.0, L0, 0.0);
	vec3 p2 = p1 + rot_x(vec3(0.0, L1, 0.0), TURN1);
	vec3 v = VERTEX;
	if (seg >= 2) { v = about(v, p2, k2); }
	if (seg >= 1) { v = about(v, p1, k1); }
	// The whole limb: lifted and swung at the root.
	v = rot_x(v, root * 0.35 + lift * 0.25);
	v = rot_y(v, root);
	VERTEX = v;
	v_flash = 1.0 - power;
}

void fragment() {
	float cos_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - cos_v, 2.0);
	vec3 opal = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + fres * 1.4 + v_along * 0.8));
	vec2 uv = UV * uv_tile;
	ALBEDO = mix(base_color, tip_color, smoothstep(0.4, 1.0, v_along)) * texture(albedo_tex, uv).rgb * 1.22;
	ROUGHNESS = clamp(texture(rough_tex, uv).r, 0.04, 1.0);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	SPECULAR = 0.75;
	SSS_STRENGTH = 0.5;
	BACKLIGHT = ALBEDO * 0.5;
	EMISSION = opal * fres * opal_gain * 0.35 + tip_color * 0.06 * smoothstep(0.85, 1.0, v_along);
}
