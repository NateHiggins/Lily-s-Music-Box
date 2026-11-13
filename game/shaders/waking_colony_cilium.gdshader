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
// One mind (Lily, 2026-11-13: "make the cilia movements more deliberate like
// a hive mind"). The cilia work in companies: every limb in a company moves
// as one, and the order to step passes from the company at the front of the
// cell to the one at the back. A step is planted, pulled, lifted and carried;
// each limb sweeps or folds so that its tip pushes against the way the cell
// is going. When the cell is not going anywhere they stand planted and the
// whole fringe rises and settles together. No limb twitches on its own.
uniform float gait_rate = 1.5;       // steps a second
uniform float gait_waves = 1.0;      // how far behind the back company steps
uniform float cohorts = 12.0;        // companies around the cell
uniform vec2 heading = vec2(0.0);    // the way the cell is going, in its own frame (x, z); zero at rest
uniform float effort = 0.0;          // 0 standing .. 1 surging
uniform float stroke = 0.55;         // root swing, radians
uniform vec3 base_color : source_color = vec3(0.62, 0.42, 0.72);
uniform vec3 tip_color : source_color = vec3(0.95, 0.78, 1.0);
uniform float opal_gain = 0.7;
// Tied to the cytoskeleton (Lily, 2026-11-13): a fibre ends on every basal
// body, and the pull that travels the canopy (the tubule shader's own beat,
// at this cilium's place) is what the limb works with. Under load it strokes
// wider; colour follows the motion: the limb warms as it moves fastest and
// takes the pulled fibre's violet while its fibre is taut.
uniform float pull_rate = 0.42;
uniform float pull_waves = 2.0;
uniform vec3 work_color : source_color = vec3(0.72, 0.36, 0.92);
uniform vec3 strike_color : source_color = vec3(1.0, 0.62, 0.38);
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
const float TURN2 = 0.75;

varying float v_along;
varying float v_flash;
varying float v_speed;
varying float v_pull;

float beat_pull(float t) {
	float s = fract(t);
	return s < 0.2 ? smoothstep(0.0, 0.2, s) : 1.0 - smoothstep(0.2, 1.0, s);
}

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
	// Feeling something (INSTANCE_CUSTOM.z, eased by the owner): the limb
	// stops stepping, straightens out to the thing and presses it. The owner
	// aims and sizes the instance so the straightened tip lands on the spot.
	float touch = INSTANCE_CUSTOM.z;
	// This limb's place, and its company's: Blender's azimuth runs the other
	// way round Godot's Y, hence the sign.
	float angle = around * 6.2831853;
	vec2 out_way = vec2(cos(angle), -sin(angle));
	float company = (floor(around * cohorts) + 0.5) / cohorts * 6.2831853;
	float lead = dot(vec2(cos(company), -sin(company)), heading);   // 1 at the front .. -1 at the back
	float side = dot(vec2(-out_way.y, out_way.x), heading);          // how much of its sideways sweep lies along the way
	float radial = dot(out_way, heading);                            // 1 reaching ahead .. -1 trailing
	float s = fract(cell_time * gait_rate - (0.5 - 0.5 * lead) * gait_waves);
	// Planted, then a quick pull; lifted, then a slow carry back.
	float power = smoothstep(0.08, 0.36, s);
	float recover = smoothstep(0.44, 0.96, s);
	float swing = s < 0.40 ? mix(-1.0, 1.0, power) : mix(1.0, -1.0, recover);
	float lift = (s < 0.40 ? 0.0 : sin(recover * 3.14159)) * effort;
	// Its fibre's pull: the same beat the cytoskeleton shows at this place.
	float pull = beat_pull(cell_time * pull_rate - around * pull_waves);
	pull *= 0.5 + 0.5 * (0.5 + 0.5 * sin(cell_time * 0.17 + around * 11.0));
	float reach = stroke * (0.60 + 0.70 * pull) * effort;
	// A positive turn about the limb carries its tip against the counter-
	// clockwise way round the cell, so this sign always pushes backward.
	float root = swing * reach * side;
	// Standing, the fringe breathes as one.
	float breath = (1.0 - effort) * (0.5 + 0.5 * sin(cell_time * 0.9));
	// Limbs ahead fold in as they pull; limbs behind straighten as they push.
	float k1 = 0.15 + 0.65 * lift + 0.30 * radial * swing * effort - 0.10 * breath;
	float k2 = 0.10 + 0.55 * lift + 0.26 * radial * swing * effort - 0.08 * breath;
	// Feeling: one press passes along the limbs that hold the thing, in order.
	float beat = fract(cell_time * 0.8 - around * 2.5);
	float press = beat < 0.3 ? sin(beat * 10.4719755) : 0.0;
	root *= 1.0 - touch;
	lift *= 1.0 - touch;
	k1 = mix(k1, -TURN1 * 0.82 + 0.06 * press, touch);
	k2 = mix(k2, -TURN2 * 0.82 + 0.24 * press, touch);
	// Joint pivots in the rest pose (Godot axes: up is +Y, the curl is about X).
	vec3 p1 = vec3(0.0, L0, 0.0);
	vec3 p2 = p1 + rot_x(vec3(0.0, L1, 0.0), TURN1);
	vec3 v = VERTEX;
	if (seg >= 2) { v = about(v, p2, k2); }
	if (seg >= 1) { v = about(v, p1, k1); }
	// The whole limb: lifted and swung at the root.
	v = rot_x(v, abs(root) * 0.35 + lift * 0.25 + touch * 0.04 * press);
	v = rot_y(v, root);
	VERTEX = v;
	v_flash = 1.0 - power;
	// How fast the limb is moving: the power stroke peaks mid-swing, the
	// recovery is a slow return. Wider strokes move faster.
	v_speed = (s < 0.40 ? sin(power * 3.14159265) : 0.22 * sin(recover * 3.14159265)) * (0.55 + 0.75 * pull) * effort;
	// A feeling limb warms with each press instead of each step.
	v_speed = mix(v_speed, 0.20 + 0.80 * press, touch);
	v_pull = pull;
}

void fragment() {
	float cos_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - cos_v, 2.0);
	vec3 opal = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + fres * 1.4 + v_along * 0.8));
	vec2 uv = UV * uv_tile;
	// Colour by motion: the resting violet, the pulled fibre's colour while
	// its fibre is taut (strongest at the root, where the fibre joins), and a
	// warm flush that rides out along the limb with its speed.
	vec3 limb = mix(base_color, tip_color, smoothstep(0.4, 1.0, v_along));
	limb = mix(limb, work_color, clamp(v_pull * 0.90 * (1.0 - 0.5 * v_along), 0.0, 1.0));
	limb = mix(limb, strike_color, clamp(v_speed, 0.0, 1.0) * (0.50 + 0.50 * v_along));
	ALBEDO = limb * texture(albedo_tex, uv).rgb * 1.22;
	ROUGHNESS = clamp(texture(rough_tex, uv).r, 0.04, 1.0);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	SPECULAR = 0.75;
	SSS_STRENGTH = 0.5;
	BACKLIGHT = ALBEDO * 0.5;
	EMISSION = opal * fres * opal_gain * 0.35 + tip_color * 0.06 * smoothstep(0.85, 1.0, v_along)
			+ strike_color * 0.26 * clamp(v_speed, 0.0, 1.0) * (0.3 + 0.7 * v_along);
}
