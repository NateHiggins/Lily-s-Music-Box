shader_type spatial;
render_mode unshaded;
// The transmission, done live. Clips are stored clean; everything wrong
// with the picture happens here, driven by the director's uniforms, so the
// same clip can play pristine one night and possessed the next. All sets
// share this one material — the building receives exactly one signal.
//
// Nine faults, composable:
//   static_amount  aerial snow
//   roll_speed     vertical hold slipping, picture wraps
//   ghost_offset   a second station superimposed
//   dropout        signal collapsing to a dim band of noise
//   chroma         colour carrier failing: RGB fringes separate
//   tear           a horizontal band of the frame displaced sideways
//   flicker        brightness instability, mains-borne
//   warp           the glass breathing — possession's tell
//   scanline       constant CRT lining, always faintly present

uniform sampler2D feed: source_color, filter_linear;
uniform float static_amount: hint_range(0.0, 1.0) = 0.0;
uniform float roll_speed: hint_range(0.0, 4.0) = 0.0;
uniform float ghost_offset: hint_range(0.0, 0.2) = 0.0;
uniform float dropout: hint_range(0.0, 1.0) = 0.0;
uniform float chroma: hint_range(0.0, 1.0) = 0.0;
uniform float tear: hint_range(0.0, 1.0) = 0.0;
uniform float flicker: hint_range(0.0, 1.0) = 0.0;
uniform float warp: hint_range(0.0, 1.0) = 0.0;
uniform float scanline: hint_range(0.0, 1.0) = 0.22;

float hash(vec2 p, float t) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + t * 43.7) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// the glass breathing: a slow radial swell from centre
	if (warp > 0.001) {
		vec2 c = uv - 0.5;
		uv = 0.5 + c * (1.0 + warp * 0.06
				* sin(TIME * 1.7 + length(c) * 9.0));
	}
	// a band of the picture shoved sideways, jumping between lines
	if (tear > 0.001) {
		float band = step(0.5, fract(uv.y * 3.0 + floor(TIME * 7.0) * 0.37));
		uv.x = fract(uv.x + band * tear * 0.09
				* (hash(vec2(floor(TIME * 7.0)), 0.0) - 0.5) * 2.0);
	}
	uv.y = fract(uv.y + TIME * roll_speed);
	vec3 pic;
	// colour carrier failing: sample the channels a fringe apart
	if (chroma > 0.001) {
		float f = chroma * 0.012;
		pic.r = texture(feed, fract(uv + vec2(f, 0.0))).r;
		pic.g = texture(feed, uv).g;
		pic.b = texture(feed, fract(uv - vec2(f, 0.0))).b;
	} else {
		pic = texture(feed, uv).rgb;
	}
	if (ghost_offset > 0.001) {
		vec3 twin = texture(feed, fract(uv + vec2(ghost_offset,
				ghost_offset * 0.4))).rgb;
		pic = mix(pic, max(pic, twin * 0.9), 0.55);
	}
	float snow = hash(floor(uv * vec2(160.0, 288.0)), TIME);
	pic = mix(pic, vec3(snow), static_amount * 0.9);
	// a dying signal collapses toward a dim band of noise, never clean
	// black — a dead set is a different, quieter thing
	pic = mix(pic, vec3(snow * 0.12), dropout);
	// mains-borne flicker: whole frame breathes brightness
	pic *= 1.0 - flicker * 0.45 * (0.5 + 0.5
			* sin(TIME * 13.0 + sin(TIME * 47.0)));
	pic *= 1.0 - scanline * 0.5 * step(0.5, fract(uv.y * 96.0));
	ALBEDO = pic;
}
