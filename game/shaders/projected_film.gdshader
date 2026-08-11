shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// A 16 mm image thrown onto a wall by a machine that was never very good.
//
// blend_add because a projector ADDS light to a surface - it cannot make
// plaster darker than plaster. Anything black in the film is simply the wall.
// That single choice does more for believability than every effect below, and
// it is also why the room has to be dark for the image to read at all.
//
// Ordered by how much each one contributes, which is not the order you would
// guess: gate weave outranks grain, and grain outranks everything else.

uniform sampler2D frame : source_color, filter_linear;
uniform float weave_amount : hint_range(0.0, 0.02) = 0.0035;
uniform float flicker_depth : hint_range(0.0, 0.5) = 0.14;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.32;
uniform float dust_amount : hint_range(0.0, 1.0) = 0.30;
uniform float falloff : hint_range(0.0, 2.0) = 0.85;
uniform float mono : hint_range(0.0, 1.0) = 1.0;
uniform vec3 lamp_tint : source_color = vec3(1.0, 0.93, 0.78);
uniform float gain : hint_range(0.0, 4.0) = 1.35;

// THE BURN. Film stopping in the gate cooks from a point outward: a bright
// ring, a brown scorched edge, and a hole that is not a colour at all - it is
// the lamp, unobstructed, and therefore the brightest thing in the room.
//
// Authored, never automatic. It is what a reel does when it ends, and it is
// what the Tenant does when it wants the film to stop being the point. It was
// also proposed as a way to cover the watermark on the current clips, and that
// does not work: the mark is present in nearly every frame and wanders through
// the middle of the picture, so masking it means burning permanently, and a
// permanent burn is not an effect, it is a fault. The burn stays because it is
// worth having, not because it hides anything.
uniform float burn : hint_range(0.0, 1.5) = 0.0;
uniform vec2 burn_origin = vec2(0.42, 0.55);

// THE CIGAR BURN - the changeover cue, not damage.
//
// The projectionist's mark: a small circle scratched or punched into the top
// corner of a print, flashed for about four frames to say "the reel is ending,
// start the other machine". Two of them, eight seconds apart. Every audience
// has seen thousands and almost nobody has noticed one, which is exactly the
// register this whole shader is aiming at.
//
// It matters more here than as decoration. A cue means a JOIN, and a print
// with cues every few seconds is a print assembled out of scraps - which is
// what these reels are. The mark is the punctuation of a badly edited film,
// so it should fire often enough to imply the cuts, and never be explained.
uniform float cue_period : hint_range(0.0, 30.0) = 0.0;   // 0 = never
uniform vec2 cue_at = vec2(0.86, 0.12);
uniform float cue_radius : hint_range(0.0, 0.1) = 0.026;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// SILENT SPEED. Home projectors ran nearer 16-18 fps than 24, and the
	// quantised time step below is what makes the motion feel wrong in the
	// right way - it drives the weave and the grain, so both jump on frames
	// instead of sliding continuously.
	float fps = 17.0;
	float t = floor(TIME * fps) / fps;

	// GATE WEAVE. The film is held by sprockets and gravity, neither exactly.
	// Vertical drift is larger than horizontal because that is the direction
	// the film is being pulled.
	vec2 weave = vec2(
		(vnoise(vec2(t * 3.1, 0.0)) - 0.5) * 0.6,
		(vnoise(vec2(0.0, t * 2.3)) - 0.5)) * weave_amount;
	vec2 uv = UV + weave;

	// Outside the gate there is no picture, only the wall.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		vec3 col = texture(frame, uv).rgb;
		col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), mono);

		// Lamp flicker: a slow beat from the shutter, plus an occasional
		// deeper sag as the mechanism loads up.
		float f = 1.0 + (vnoise(vec2(t * 5.7, 1.7)) - 0.5) * flicker_depth;
		f -= smoothstep(0.86, 1.0, vnoise(vec2(t * 0.7, 4.2))) * 0.10;

		// Grain sits ON the light, so it is additive and brightest in the
		// midtones - not a grey veil laid over everything.
		float g = hash(uv * vec2(920.0, 1640.0) + t * 71.0) - 0.5;
		col += g * grain_amount * 0.16 * (0.4 + col);

		// Dust and hairs are bright: they block the gate, and what you see is
		// the lamp around them. Sparse, and new every frame.
		// Tuned down hard from the first pass, which snowed: at 0.012 this put
		// ~160 specks on every frame and read as a blizzard rather than as a
		// dirty gate. Dust is something you notice on the third viewing.
		float d = hash(floor(uv * vec2(260.0, 150.0)) + t * 37.0);
		col += step(1.0 - dust_amount * 0.0022, d) * 0.55;

		// The thrown rectangle is never even and never square to the wall.
		vec2 c = uv - 0.5;
		col *= 1.0 - falloff * dot(c, c) * 0.9;

		if (burn > 0.001) {
			// An irregular front travelling out from one point.
			float r = distance(uv, burn_origin)
					+ (vnoise(uv * 7.0) - 0.5) * 0.16;
			// The far corner is ~0.80 away in UV, so the front is scaled to
			// spend most of its travel visibly burning. At 0.9 the first pass
			// had eaten the whole frame by burn = 0.72 and the interesting
			// part - the ring - was over before anyone saw it.
			float front = burn * 0.60;
			float hole = smoothstep(front, front - 0.045, r);
			float scorch = smoothstep(front + 0.20, front - 0.02, r);
			// Scorched film goes brown and translucent before it goes away.
			col = mix(col, vec3(0.42, 0.20, 0.07) * col, scorch * 0.85);
			col += vec3(1.0, 0.62, 0.22) * scorch * (1.0 - hole) * 1.6;
			// Behind the front there is no film, so there is only the lamp.
			col = mix(col, vec3(1.0), hole);
		}

		if (cue_period > 0.01) {
			// Four frames on, at silent speed, twice per period - the second
			// cue lands a beat after the first, the way a real changeover pair
			// does. Aspect-corrected so the mark is a circle on a tall frame.
			float phase = mod(TIME, cue_period);
			float on = step(phase, 4.0 / fps)
					+ step(abs(phase - 0.55), 4.0 / fps * 0.5);
			if (on > 0.0) {
				vec2 dxy = (uv - cue_at) * vec2(1.0, 0.56);
				float cr = length(dxy) + (vnoise(uv * 40.0) - 0.5) * 0.004;
				float ring = smoothstep(cue_radius, cue_radius * 0.55, cr);
				col = mix(col, vec3(1.0, 0.94, 0.86), ring * 0.92);
			}
		}

		ALBEDO = col * f * gain * lamp_tint;
		ALPHA = 1.0;
	}
}
