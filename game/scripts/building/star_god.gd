extends RefCounted
## The Star God, 1 November 1929 (Lily's rulings sun_star_god, sun_eclipse_day,
## sun_two_events and sun_eclipse_moon_size, 2026-11-04). The real annular eclipse
## of that morning passed over West Africa at 12:05 UT and was never visible from
## New York. Over Queens it comes anyway, unannounced and total: the grown Moon
## (WeatherManager.moon_scale, about fifty-eight times real by then) slides its dark
## disc across the morning sky, faster than any Moon moves, and holds the Sun for
## ten minutes. In that dark something comes out of the Sun and leaves.
##
## A pure function of the campaign clock, like the Moon's size, so pausing and
## reverse travel show the same sky. phenomena.json dates the same window for the
## newspapers (sky_phenomena.gd checks that they agree).
##
## Minutes from the start (06:40 local):
##  0-20   the disc approaches; the sky beside the Sun dims where it passes
##  18-23  phase A: the granulation turns geometric and the spots gather into an eye;
##         the Sun rings with surface waves
##  ~23    second contact: Baily's beads from the measured lunar limb, the diamond ring
##  23-33  totality, the corona out
##  24-30  phase B: a prominence tears free and unfolds into the entity, leaving a rift
##  30-32  phase C: it climbs, bends the sky behind it, thins to a line and is gone in
##         one soundless chromatic ring
##  ~33    third contact; the Sun comes back scarred
##  33-60  the disc slides away
## The rift stays on the Sun for the rest of the day; that night the sky over Queens
## glows violet.

const DATE := "1929-11-01"
const START_LOCAL_MINUTE := 400.0 # 06:40
const MINUTES := 60.0
const CAMPAIGN_FIRST := "1928-11-10"
const SUN_RADIUS_DEG := 0.2666
## The approach track across the sky, in the Sun's disc frame (x across, y up):
## from lower right to upper left, like the real Moon's eastward drift.
const TRACK := Vector2(-0.94, 0.34)

static func start_campaign_minute() -> float:
	var days := (Time.get_unix_time_from_datetime_string(DATE + "T00:00:00") - Time.get_unix_time_from_datetime_string(CAMPAIGN_FIRST + "T00:00:00")) / 86400.0
	return days * 1440.0 + START_LOCAL_MINUTE

## Minutes since the event began (negative before).
static func minutes_in(campaign_minute: float) -> float:
	return campaign_minute - start_campaign_minute()

## Everything the sky and the light need at this moment. moon_radius_deg is the
## Moon's drawn radius (real radius times WeatherManager.moon_scale).
static func state(campaign_minute: float, moon_radius_deg: float) -> Dictionary:
	var t := minutes_in(campaign_minute)
	var result := {"active": false, "t": t, "visible": 1.0, "offset": Vector2.ZERO, "moon_radius": 0.0,
		"totality": 0.0, "beads": 0.0, "corona": 0.0, "eye": 0.0, "ripple": 0.0, "entity": 0.0,
		"ascent": 0.0, "line": 0.0, "shock": 0.0, "rift": 0.0, "afterglow": 0.0}
	# The rift and the violet night outlast the eclipse.
	if t >= 24.0 and t < 24.0 * 60.0:
		result.rift = clampf((t - 24.0) / 6.0, 0.0, 1.0)
	var dusk := 640.0 # about 17:20 on 1 November, sunset in Queens is 16:52
	if t > dusk and t < dusk + 14.0 * 60.0:
		result.afterglow = clampf((t - dusk) / 60.0, 0.0, 1.0) * clampf((dusk + 14.0 * 60.0 - t) / 90.0, 0.0, 1.0)
	if t < 0.0 or t > MINUTES: return result
	result.active = true
	var rm := moon_radius_deg / SUN_RADIUS_DEG # in Sun radii
	var outer := rm + 1.0                      # first and fourth contact
	var inner := maxf(rm - 1.0, 0.05)          # second and third contact
	# A grazing eclipse: the Sun passes just inside the giant disc's edge, so the
	# corona flares out over the limb and what leaves the Sun is seen leaving.
	var miss := maxf(inner - 0.6, 0.0)
	var chord_in := sqrt(maxf(inner * inner - miss * miss, 0.0))
	var chord_out := sqrt(maxf(outer * outer - miss * miss, 0.0))
	var s := 0.0
	if t < 20.0:
		s = lerpf(chord_out + 70.0, chord_out, 1.0 - pow(1.0 - t / 20.0, 2.0))
	elif t < 23.0:
		s = lerpf(chord_out, chord_in, (t - 20.0) / 3.0)
	elif t < 33.0:
		s = lerpf(chord_in, -chord_in, (t - 23.0) / 10.0)
	elif t < 36.0:
		s = lerpf(-chord_in, -chord_out, (t - 33.0) / 3.0)
	else:
		s = lerpf(-chord_out, -chord_out - 70.0, pow((t - 36.0) / 24.0, 2.0))
	var normal := Vector2(-TRACK.y, TRACK.x)
	result.offset = normal * miss + TRACK * s
	var d: float = (result.offset as Vector2).length()
	result.moon_radius = rm
	result.visible = _visible_fraction(d, rm)
	result.totality = 1.0 if result.visible <= 0.0 else 0.0
	# Beads and the diamond ring: the last and first seconds of sunlight.
	result.beads = maxf(_pulse(t, 23.0, 0.35), _pulse(t, 33.0, 0.35))
	result.corona = smoothstep(22.6, 23.2, t) * (1.0 - smoothstep(32.8, 33.4, t))
	result.eye = smoothstep(18.0, 21.0, t) * (1.0 - smoothstep(23.0, 23.5, t))
	result.ripple = smoothstep(19.0, 21.5, t) * (1.0 - smoothstep(22.5, 23.2, t))
	result.entity = smoothstep(24.0, 30.0, t) * (1.0 - smoothstep(31.4, 32.0, t))
	result.ascent = smoothstep(30.0, 31.6, t)
	result.line = _pulse(t, 31.75, 0.25)
	result.shock = clampf((t - 32.0) / 0.6, 0.0, 1.0) * (1.0 - smoothstep(32.4, 32.7, t))
	return result

## Fraction of the Sun's disc left uncovered by a disc of radius rm (Sun radius 1)
## whose centre is d away.
static func _visible_fraction(d: float, rm: float) -> float:
	if d >= rm + 1.0: return 1.0
	if d <= rm - 1.0: return 0.0
	var r1 := 1.0
	var a := r1 * r1 * acos(clampf((d * d + r1 * r1 - rm * rm) / (2.0 * d * r1), -1.0, 1.0))
	var b := rm * rm * acos(clampf((d * d + rm * rm - r1 * r1) / (2.0 * d * rm), -1.0, 1.0))
	var c := 0.5 * sqrt(maxf(0.0, (-d + r1 + rm) * (d + r1 - rm) * (d - r1 + rm) * (d + r1 + rm)))
	return clampf(1.0 - (a + b - c) / PI, 0.0, 1.0)

static func _pulse(x: float, centre: float, half: float) -> float:
	return clampf(1.0 - absf(x - centre) / half, 0.0, 1.0)
