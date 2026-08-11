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
// THE APERTURE. A hard rectangle reads as a quad with a texture on it - the
// straight edge is the single biggest tell that this is geometry and not light.
// Real condenser optics throw a round-ish pool with a soft, uneven edge, so the
// gate here is an oval whose rim wanders, and the light falls off toward it
// rather than stopping.
// Half-extents of the oval as a fraction of the quad. BOTH must be under 0.5
// or the mask never reaches its threshold on that axis and the quad's own edge
// does the cutting - which is how the first version kept a straight top and
// bottom while claiming to be an oval.
uniform vec2 aperture_half = vec2(0.40, 0.455);
uniform float aperture_soft : hint_range(0.01, 0.6) = 0.26;
uniform float aperture_wobble : hint_range(0.0, 0.4) = 0.10;

// EARLY OPTICS. A petzval-era projection lens is a good lens in the middle and
// gives up entirely at the rim: straight lines bow, the colours stop agreeing
// with each other, and the focus falls off long before the light does. All
// three are strongest at the edge of the field, which is what makes the pool
// feel like something thrown through glass rather than a picture pasted on.
uniform float barrel : hint_range(-0.4, 0.4) = 0.16;
uniform float chroma : hint_range(0.0, 0.05) = 0.010;
uniform float defocus : hint_range(0.0, 0.03) = 0.009;
// THE PLATE. Niepce 1826 and Cornelius 1839 as the reference, not 16 mm. What
// makes those read as ghosts is exposure time, not grain: an eight-hour plate
// records only what held still, and the plate's own tarnish sits IN FRONT of
// the picture rather than tinted into it. Damage occludes; it does not colour.
//
// plate = 0 is film. plate = 1 is a silvered plate somebody found in a drawer.
uniform float plate : hint_range(0.0, 1.0) = 0.0;
uniform float tarnish : hint_range(0.0, 2.0) = 1.0;
uniform float plate_lift : hint_range(0.0, 0.5) = 0.10;
uniform vec3 plate_warm : source_color = vec3(0.78, 0.735, 0.64);
uniform vec3 plate_cool : source_color = vec3(0.50, 0.555, 0.60);
// Per-reel character: a bias on the duotone, not a filter over it. Twelve
// plates in a drawer should feel like twelve afternoons.
uniform vec3 reel_tint : source_color = vec3(1.0, 1.0, 1.0);

// A fixed scorched hole in the print - somebody's cigarette, or a splice that
// cooked. It never moves, which is what makes it read as physical.
uniform float cigar_size : hint_range(0.0, 0.5) = 0.0;
uniform vec2 cigar_at = vec2(0.5, 0.5);

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

// MOULD. What actually happens to film left in a damp basement, which this
// building has one of. Fungus eats the emulsion in branching filaments, so the
// front is dendritic rather than round, and it BLOCKS the lamp - on a
// projection that means shadow, not fire. The wall shows through where the
// plate has rotted.
//
// This is the per-reel damage, and it is permanent: a reel arrives already
// spoiled to its own degree. The bright `burn` above is a separate event -
// the reel stopping in the gate - and stays for reel-end and for the Tenant.
uniform float mould : hint_range(0.0, 1.2) = 0.0;
uniform vec2 mould_origin = vec2(0.22, 0.18);


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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
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

	// Outside the gate there is no picture, only the wall. The sampling clamp
	// still has to be square - a texture has corners even when the light does
	// not - but what the audience sees is the oval below.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0;
	} else {
		// --- the lens ---------------------------------------------------
		vec2 lc = uv - 0.5;
		// Normalised distance across the FIELD, not the quad: 1.0 is the rim
		// of the oval, and everything optical below is driven by it.
		float rad = length(lc / aperture_half);

		// Barrel: early glass bows straight lines outward.
		vec2 buv = 0.5 + lc * (1.0 + barrel * dot(lc, lc));

		// Longitudinal chromatic aberration - blue comes to focus shorter than
		// red, so the channels are sampled at slightly different scales and the
		// disagreement grows toward the rim.
		float ca = chroma * rad * rad;
		vec2 ruv = clamp(0.5 + (buv - 0.5) * (1.0 + ca), vec2(0.0), vec2(1.0));
		vec2 buv2 = clamp(0.5 + (buv - 0.5) * (1.0 - ca), vec2(0.0), vec2(1.0));
		vec2 guv = clamp(buv, vec2(0.0), vec2(1.0));

		vec3 col = vec3(texture(frame, ruv).r, texture(frame, guv).g,
				texture(frame, buv2).b);

		// Field curvature: sharp on axis, mush at the edge. Four taps is
		// enough because by the time it is visible it is already soft.
		float soft = smoothstep(0.30, 1.05, rad) * defocus;
		if (soft > 0.0001) {
			vec3 blur = vec3(0.0);
			blur += texture(frame, clamp(guv + vec2(soft, 0.0), vec2(0.0), vec2(1.0))).rgb;
			blur += texture(frame, clamp(guv - vec2(soft, 0.0), vec2(0.0), vec2(1.0))).rgb;
			blur += texture(frame, clamp(guv + vec2(0.0, soft), vec2(0.0), vec2(1.0))).rgb;
			blur += texture(frame, clamp(guv - vec2(0.0, soft), vec2(0.0), vec2(1.0))).rgb;
			col = mix(col, blur * 0.25, smoothstep(0.30, 1.05, rad));
		}
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

		vec2 c = uv - 0.5;

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
			// Flecks were pure white off a hard step at a 420x700 grid, which
			// read as salt thrown at the screen - high contrast, uniform
			// spacing, and the ugliest thing in the frame. Emulsion pits are
			// SOFT, they are the plate's own colour, and there are not many.
			vec2 fcell = uv * vec2(150.0, 250.0);
			vec2 fid = floor(fcell);
			float fpick = hash(fid);
			float fdist = length(fract(fcell) - 0.5);
			float fleck = step(0.982, fpick)
					* smoothstep(0.42, 0.06, fdist) * tarnish;

			// The edge of a plate is where the emulsion gave up first.
			float edge = smoothstep(0.26, 0.52, max(abs(c.x), abs(c.y) * 0.60));
			float rot = edge * (0.70 + vnoise(uv * 5.5) * 1.15) * tarnish;

			vec3 plated = p * metal;
			plated = mix(plated, plate_warm * 1.05, clamp(bloom * 0.55, 0.0, 1.0));
			// Damage brightens toward the PLATE's tone, never toward white.
			plated += plate_warm * (streak * 0.22 + fleck * 0.30);
			plated = mix(plated, plate_cool * 0.10, clamp(rot, 0.0, 0.92));

			col = mix(col, plated * reel_tint, plate);
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

		if (mould > 0.001) {
			// A ragged front, plus filaments that run ahead of it. The two
			// octaves are the whole trick: the low one makes the blotch, the
			// high one makes it look alive.
			float mr = distance(uv, mould_origin);
			float ragged = (fbm(uv * 8.0) - 0.45) * 0.34;
			float front = mould * 0.62;
			float body = smoothstep(front + 0.05, front - 0.11, mr + ragged);
			float filament = smoothstep(0.60, 0.95, fbm(uv * 27.0))
					* smoothstep(front + 0.22, front - 0.02, mr);
			float m = clamp(body + filament * 0.75, 0.0, 1.0);

			// Foxing: a brown bloom in the halo, before the emulsion is gone.
			float halo = clamp(smoothstep(front + 0.18, front - 0.04, mr) - m, 0.0, 1.0);
			col = mix(col, col * vec3(0.62, 0.44, 0.26), halo * 0.75);
			// And where it has eaten through there is no plate, so no light.
			col *= 1.0 - m * 0.94;
		}

		if (cigar_size > 0.001) {
			float pr = distance(uv, cigar_at) + (vnoise(uv * 22.0) - 0.5) * 0.05;
			float phole = smoothstep(cigar_size, cigar_size * 0.70, pr);
			float pscorch = smoothstep(cigar_size * 1.55, cigar_size * 0.80, pr);
			col = mix(col, vec3(0.38, 0.17, 0.05) * col, pscorch * 0.9);
			col += vec3(1.0, 0.58, 0.20) * pscorch * (1.0 - phole) * 1.3;
			col = mix(col, vec3(1.0), phole);
		}

		if (cigar_size > 0.001) {
			float pr = distance(uv, cigar_at) + (vnoise(uv * 22.0) - 0.5) * 0.05;
			float phole = smoothstep(cigar_size, cigar_size * 0.70, pr);
			float pscorch = smoothstep(cigar_size * 1.55, cigar_size * 0.80, pr);
			col = mix(col, vec3(0.38, 0.17, 0.05) * col, pscorch * 0.9);
			col += vec3(1.0, 0.58, 0.20) * pscorch * (1.0 - phole) * 1.3;
			col = mix(col, vec3(1.0), phole);
		}

		// THE APERTURE, applied last so nothing - grain, mould, burn - escapes
		// past the edge of the light. Two noise scales on the rim: a slow one
		// that makes the oval lopsided, and a fine one that keeps the edge from
		// ever reading as a curve somebody drew.
		float rim = 1.0
				+ (fbm(uv * 2.6 + 5.0) - 0.5) * aperture_wobble * 2.0
				+ (vnoise(uv * 14.0) - 0.5) * aperture_wobble * 0.5;
		float ap = 1.0 - smoothstep(rim - aperture_soft, rim + aperture_soft * 0.30, rad);
		// Radial falloff inside the pool: brightest on axis, the way a
		// condenser actually behaves.
		ap *= 1.0 - falloff * clamp(rad / max(rim, 0.001), 0.0, 1.0) * 0.55;

		ALBEDO = col * f * gain * lamp_tint * ap;
		ALPHA = 1.0;
	}
}
