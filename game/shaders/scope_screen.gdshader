shader_type spatial;
render_mode unshaded;
// A signal-parlour scope, not a television.
//
// The machines in the Harukiya's entrance corner are Vantry-descended receiving
// furniture (ORISON_BIBLE VIII.5.g). Their picture is a circular
// long-persistence tube, which is the period's actual display technology and
// does more dating work than any amount of distress: nothing places a picture
// like the shape of its frame.
//
// The trail is NOT faked here. Persistence is accumulated upstream in a 2D
// viewport that never clears, because a real phosphor decays over time and a
// shader has no memory of the frame before. What this file does is shape and
// colour what comes out of that:
//
//   circular aperture   everything outside the tube face is the bezel
//   monochrome + tint   one phosphor, one colour; the feed's own hue is gone
//   sweep               a rotating brightening arm, the way a PPI writes
//   graticule           etched rings and cross-hairs on the glass
//   bloom               bright traces spill into the phosphor around them
//   fault uniforms      shared vocabulary with tv_screen.gdshader

uniform sampler2D feed : source_color, filter_linear;

uniform vec3 phosphor : source_color = vec3(0.36, 1.0, 0.42);
// 1.0 = one phosphor, which is what a tube of this vintage has. Below 1.0 the
// signal's own colour survives, which no coating in 1927 could do. A few boxes
// on the row are like that. Their chassis plates are unmarked and nobody can say
// where they came from, which is the same answer the building gives about WORS
// 1610 and about most things.
uniform float mono : hint_range(0.0, 1.0) = 1.0;
uniform float sweep_speed : hint_range(0.0, 3.0) = 0.35;
uniform float sweep_strength : hint_range(0.0, 1.0) = 0.30;
uniform float graticule : hint_range(0.0, 1.0) = 0.22;
uniform float bloom : hint_range(0.0, 2.0) = 0.55;
uniform float gain : hint_range(0.0, 4.0) = 1.9;
// A scope is a bright trace on near-black, not a dim photograph. The feed is a
// lit 3D scene whose luma sits low, so it is lifted before it is tinted -
// without this a dark programme reads as a tube that is barely switched on.
uniform float lift : hint_range(0.2, 1.0) = 0.55;

// Same names and ranges as tv_screen.gdshader, so one infection curve drives
// either kind of glass without the caller knowing which it is looking at.
uniform float static_amount : hint_range(0.0, 1.0) = 0.0;
uniform float roll_speed : hint_range(0.0, 4.0) = 0.0;
uniform float dropout : hint_range(0.0, 1.0) = 0.0;
uniform float chroma : hint_range(0.0, 1.0) = 0.0;
uniform float tear : hint_range(0.0, 1.0) = 0.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float warp : hint_range(0.0, 1.0) = 0.0;
uniform float scanline : hint_range(0.0, 1.0) = 0.18;

float hash(vec2 p, float t) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + t * 43.7) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;

	// The tube face. Outside it is the inside of the cabinet, which is dark and
	// not a picture. Discarding rather than blackening keeps the bezel's own
	// geometry reading as the frontmost thing.
	float r = length(c * vec2(1.0, 1.0)) * 2.0;
	if (r > 1.0) {
		discard;
	}

	// Glass curvature: a real tube of this vintage is a section of a sphere and
	// the image bows outward toward the rim.
	uv = 0.5 + c * (1.0 - 0.10 * (1.0 - r * r));
	if (warp > 0.001) {
		uv = 0.5 + (uv - 0.5) * (1.0 + warp * 0.06
				* sin(TIME * 1.7 + r * 9.0));
	}
	if (tear > 0.001) {
		float band = step(0.5, fract(uv.y * 3.0 + floor(TIME * 7.0) * 0.37));
		uv.x = fract(uv.x + band * tear * 0.09
				* (hash(vec2(floor(TIME * 7.0)), 0.0) - 0.5) * 2.0);
	}
	uv.y = fract(uv.y + TIME * roll_speed);

	vec3 raw = texture(feed, uv).rgb;
	float signal = luma(raw);

	// Bloom: a bright trace spills into the phosphor around it. Four taps is
	// enough on a screen this size and this is running twelve times over.
	if (bloom > 0.001) {
		float around = 0.0;
		around += luma(texture(feed, uv + vec2(0.004, 0.0)).rgb);
		around += luma(texture(feed, uv - vec2(0.004, 0.0)).rgb);
		around += luma(texture(feed, uv + vec2(0.0, 0.004)).rgb);
		around += luma(texture(feed, uv - vec2(0.0, 0.004)).rgb);
		signal += around * 0.25 * bloom;
	}
	signal = pow(max(signal, 0.0), lift) * gain;

	// A colour carrier cannot fail on a set that never had one, so `chroma`
	// spends itself here as the trace tearing away from itself instead.
	if (chroma > 0.001) {
		float ghost = luma(texture(feed, uv + vec2(chroma * 0.012, 0.0)).rgb);
		signal = max(signal, ghost * 0.7);
	}

	// The sweep. A PPI writes with a rotating arm and the phosphor behind it is
	// always the freshest, so the arm reads as a moving brightening rather than
	// a drawn line.
	float angle = atan(c.y, c.x);
	float arm = fract((angle / 6.2831853) + TIME * sweep_speed);
	signal += pow(1.0 - arm, 18.0) * sweep_strength;

	// Etched on the glass, not drawn by the beam: rings and cross-hairs sit in
	// front of the picture and do not decay with it.
	float rings = smoothstep(0.012, 0.0, abs(fract(r * 3.0) - 0.5) - 0.47);
	float cross_hair = smoothstep(0.004, 0.0, min(abs(c.x), abs(c.y)));
	float etch = max(rings, cross_hair) * graticule;

	float snow = hash(floor(uv * vec2(160.0, 160.0)), TIME);
	signal = mix(signal, snow, static_amount * 0.9);
	signal = mix(signal, snow * 0.12, dropout);
	signal *= 1.0 - flicker * 0.45 * (0.5 + 0.5
			* sin(TIME * 13.0 + sin(TIME * 47.0)));
	signal *= 1.0 - scanline * 0.5 * step(0.5, fract(uv.y * 96.0));

	// One phosphor - or, on the unmarked boxes, whatever the signal already was.
	// Hue is carried separately from brightness so the lift and the sweep apply
	// the same either way and a colour tube is still plainly the same instrument.
	vec3 hue = raw / max(luma(raw), 0.0025);
	vec3 lit = mix(hue, phosphor, mono) * signal;
	lit += phosphor * etch * 0.5;
	// The unlit face is not black: a tube that is off is grey-green glass with
	// the room in it, and a dead set is a different, quieter thing than a dark one.
	lit += phosphor * 0.035 * (1.0 - r * 0.6);
	// Rim shadow where the glass meets the bezel.
	lit *= 1.0 - smoothstep(0.90, 1.0, r) * 0.6;

	ALBEDO = lit;
}
