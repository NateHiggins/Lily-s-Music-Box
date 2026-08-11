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
// A fixed scorched hole in the print. Kept separate from the travelling burn
// because this one never moves - which is the point, and also the problem when
// it is asked to hide something that does.
uniform float cigar_size : hint_range(0.0, 0.5) = 0.0;
uniform vec2 cigar_at = vec2(0.5, 0.5);

// THE PLATE. Niepce 1826 and Cornelius 1839 as the reference, not 16 mm.
//
// What makes those images read as ghosts is EXPOSURE TIME, not grain. An
// eight-hour heliograph records only what held still, so people are absent or
// smeared, and the plate itself - tarnish, blotch, edge rot - sits IN FRONT of
// the picture rather than tinted into it. That distinction is the whole look:
// damage occludes, it does not colour.
//
// plate = 0 is film. plate = 1 is a silvered plate somebody found in a drawer.
uniform float plate : hint_range(0.0, 1.0) = 0.0;
uniform float tarnish : hint_range(0.0, 2.0) = 1.0;
uniform float plate_lift : hint_range(0.0, 0.5) = 0.10;
uniform vec3 plate_warm : source_color = vec3(0.78, 0.735, 0.64);
uniform vec3 plate_cool : source_color = vec3(0.50, 0.555, 0.60);

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

		if (plate > 0.001) {
			float lum = dot(col, vec3(0.299, 0.587, 0.114));
			// Tonal compression first. A daguerreotype has no midtones to
			// speak of - it is a mirror, so it is either bright metal or it is
			// nothing - and a heliograph is all midtone and no ends. Split the
			// difference by lifting the floor hard and rolling the top over.
			float p = smoothstep(0.04, 0.94, lum);
			p = mix(p, sqrt(p), 0.35);
			// Roll the top over instead of letting it clip. The first pass ran
			// straight to white and lost the highlight detail that makes a
			// plate look like metal rather than like paper.
			p = p / (1.0 + p * 0.55);
			p = plate_lift + p * (1.0 - plate_lift) * 1.28;

			// Silver reads warm where it is thick and cool where it is thin,
			// which is why these plates are never one colour.
			vec3 metal = mix(plate_cool, plate_warm, smoothstep(0.25, 0.85, p));

			// DAMAGE, IN FRONT. Big soft chemical blotches that lift the
			// image toward the plate's own tone, plus hard bright flecks and
			// vertical wipe streaks where it has been cleaned badly.
			float blot = vnoise(uv * 3.2 + 11.0) * 0.6 + vnoise(uv * 7.9) * 0.4;
			float bloom = smoothstep(0.52, 0.86, blot) * tarnish;
			// Wipe streaks: a handful, not a curtain. At 46 columns the first
			// pass read as rain on a window, which is a weather effect and not
			// a damaged plate. Cleaning marks are few, uneven and vertical.
			float streak = smoothstep(0.955, 1.0,
					vnoise(vec2(uv.x * 11.0, uv.y * 1.3 + 3.0))) * tarnish;
			float fleck = step(0.9965, hash(floor(uv * vec2(420.0, 700.0)))) * tarnish;

			// The edge of a plate is where the emulsion gave up first.
			float edge = smoothstep(0.26, 0.52, max(abs(c.x), abs(c.y) * 0.60));
			float rot = edge * (0.70 + vnoise(uv * 5.5) * 1.15) * tarnish;

			vec3 plated = p * metal;
			plated = mix(plated, plate_warm * 1.05, clamp(bloom * 0.55, 0.0, 1.0));
			plated += vec3(1.0, 0.98, 0.94) * (streak * 0.30 + fleck * 0.80);
			plated = mix(plated, plate_cool * 0.10, clamp(rot, 0.0, 0.92));

			col = mix(col, plated, plate);
		}

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

		if (cigar_size > 0.001) {
			float pr = distance(uv, cigar_at) + (vnoise(uv * 22.0) - 0.5) * 0.05;
			float phole = smoothstep(cigar_size, cigar_size * 0.70, pr);
			float pscorch = smoothstep(cigar_size * 1.55, cigar_size * 0.80, pr);
			col = mix(col, vec3(0.38, 0.17, 0.05) * col, pscorch * 0.9);
			col += vec3(1.0, 0.58, 0.20) * pscorch * (1.0 - phole) * 1.3;
			col = mix(col, vec3(1.0), phole);
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
