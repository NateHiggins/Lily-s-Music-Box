class_name DayNightDirector
extends Node
## Real local time, expressed as weather.
##
## The building keeps four looks - drizzly NIGHT, a cold wet DAWN, a
## DAY that never gets brighter than a dark rainy afternoon, and a
## bruised TWILIGHT - and blends between them by the actual clock on
## the player's machine. Per the bible, no state is allowed to resolve
## the ambiguity: the day is still purgatorial, the rain never quite
## stops, and the palette stays liminal. This is one node driving the
## handles the night look already exposed: the Environment, the
## ExteriorMoon, the sky dome's tint, and the MoonFill's window pools.
##
## Determinism: WalkTest sets DAYNIGHT=0 and gets the canonical 03:00
## night, byte-identical to the pre-director look. DAYNIGHT_FORCE takes
## "HH:MM" or a state name for renders and debugging.

## minute-of-day keyframes; each row lerps to the next.
## [minute, ambient_col, ambient_e, bg_col, fog_col, fog_d,
##  sun_col, sun_e, sun_elev_deg, sun_az_deg, sky_tint, sky_exposure,
##  fill_scale]
const KEYS := [
	[0, Color(0.17, 0.23, 0.42), 0.08, Color(0.015, 0.02, 0.035),
	 Color(0.05, 0.06, 0.10), 0.014, Color(0.65, 0.70, 0.90), 0.052,
	 -38.0, 30.0, Color(1.0, 1.0, 1.0), 0.76, 1.0],
	[330, Color(0.17, 0.23, 0.42), 0.08, Color(0.015, 0.02, 0.035),
	 Color(0.05, 0.06, 0.10), 0.014, Color(0.65, 0.70, 0.90), 0.052,
	 -38.0, 30.0, Color(1.0, 1.0, 1.0), 0.76, 1.0],
	[405, Color(0.38, 0.36, 0.40), 0.13, Color(0.060, 0.065, 0.080),
	 Color(0.16, 0.15, 0.16), 0.016, Color(0.90, 0.75, 0.62), 0.090,
	 -12.0, 105.0, Color(1.35, 1.05, 0.90), 0.55, 0.6],
	[480, Color(0.42, 0.46, 0.50), 0.16, Color(0.100, 0.115, 0.130),
	 Color(0.22, 0.24, 0.26), 0.018, Color(0.75, 0.78, 0.82), 0.120,
	 -55.0, 180.0, Color(2.6, 2.7, 2.8), 0.42, 0.35],
	[960, Color(0.42, 0.46, 0.50), 0.16, Color(0.100, 0.115, 0.130),
	 Color(0.22, 0.24, 0.26), 0.018, Color(0.75, 0.78, 0.82), 0.120,
	 -55.0, 180.0, Color(2.6, 2.7, 2.8), 0.42, 0.35],
	[1050, Color(0.30, 0.26, 0.34), 0.12, Color(0.050, 0.045, 0.075),
	 Color(0.12, 0.09, 0.13), 0.016, Color(0.95, 0.60, 0.45), 0.070,
	 -10.0, 255.0, Color(1.50, 0.95, 1.05), 0.50, 0.55],
	[1140, Color(0.17, 0.23, 0.42), 0.08, Color(0.015, 0.02, 0.035),
	 Color(0.05, 0.06, 0.10), 0.014, Color(0.65, 0.70, 0.90), 0.052,
	 -38.0, 30.0, Color(1.0, 1.0, 1.0), 0.76, 1.0],
	[1440, Color(0.17, 0.23, 0.42), 0.08, Color(0.015, 0.02, 0.035),
	 Color(0.05, 0.06, 0.10), 0.014, Color(0.65, 0.70, 0.90), 0.052,
	 -38.0, 30.0, Color(1.0, 1.0, 1.0), 0.76, 1.0],
]
const STATE_MINUTES := {"night": 180, "dawn": 405, "day": 720,
	"twilight": 1050}

var _root: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _sky: ShaderMaterial
var _accum := 9.0               # apply on the first tick


func setup(root: Node3D, env: Environment, sun: DirectionalLight3D,
		sky_mat: ShaderMaterial) -> void:
	_root = root
	_env = env
	_sun = sun
	_sky = sky_mat


func _minute_now() -> float:
	var force := OS.get_environment("DAYNIGHT_FORCE")
	if force != "":
		if STATE_MINUTES.has(force):
			return float(STATE_MINUTES[force])
		var bits := force.split(":")
		if bits.size() == 2 and bits[0].is_valid_int():
			return float(int(bits[0]) * 60 + int(bits[1]))
	if OS.get_environment("DAYNIGHT") == "0":
		# The canonical hour. Tests live here; so did the whole game
		# until the sky learned to read a clock.
		return 180.0
	var t := Time.get_time_dict_from_system()
	return float(t.hour * 60 + t.minute) + float(t.second) / 60.0


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 8.0:            # a minute of day moves nothing in 8 s
		return
	_accum = 0.0
	_apply(_minute_now())


func _apply(m: float) -> void:
	if _env == null:
		return
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i in KEYS.size() - 1:
		if m >= float(KEYS[i][0]) and m <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var span := float(b[0]) - float(a[0])
	var t: float = 0.0 if span <= 0.0 else (m - float(a[0])) / span
	_env.ambient_light_color = (a[1] as Color).lerp(b[1], t)
	_env.ambient_light_energy = lerpf(a[2], b[2], t)
	_env.background_color = (a[3] as Color).lerp(b[3], t)
	_env.fog_light_color = (a[4] as Color).lerp(b[4], t)
	_env.fog_density = lerpf(a[5], b[5], t)
	if _sun:
		_sun.light_color = (a[6] as Color).lerp(b[6], t)
		_sun.light_energy = lerpf(a[7], b[7], t)
		_sun.rotation_degrees = Vector3(lerpf(a[8], b[8], t),
				lerpf(a[9], b[9], t), 0.0)
	if _sky:
		_sky.set_shader_parameter("tint", (a[10] as Color).lerp(b[10], t))
		_sky.set_shader_parameter("exposure", lerpf(a[11], b[11], t))
	if _root and _root.get("moon_fill") != null:
		_root.moon_fill.energy_scale = lerpf(a[12], b[12], t)
