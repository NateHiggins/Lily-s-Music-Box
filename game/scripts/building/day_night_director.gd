class_name DayNightDirector
extends Node
## One storm seen at four hours. This node is the sole absolute writer for the
## Environment and the one exterior directional key. LightRig supplies only
## owner-facing gains; WeatherFX receives the resolved presentation profile.

const SKY_DIR := "res://assets/building/textures/sky/"
const CelestialEphemerisScript := preload(
		"res://scripts/building/celestial_ephemeris.gd")
const SKY_PATHS := {
	"morning": SKY_DIR + "orison_clear_twilight_half_dome_4k.png",
	"day": SKY_DIR + "orison_clear_day_half_dome_4k.png",
	"evening": SKY_DIR + "orison_clear_twilight_half_dome_4k.png",
	"night": SKY_DIR + "eso_gigagalaxy_galactic_half_dome_4k.jpg",
}
const STATE_MINUTES := {
	"night": 180,
	"morning": 420,
	"dawn": 420,
	"day": 750,
	"evening": 1050,
	"twilight": 1050,
}
## J2000 catalog RA/declination degrees. Proper motion since 1928 is below the
## visual radius used here; sidereal rotation and observer geometry are live.
const BRIGHT_STARS := [
	Vector2(101.287, -16.716), # Sirius
	Vector2(95.988, -52.696),  # Canopus
	Vector2(213.915, 19.182),  # Arcturus
	Vector2(279.235, 38.784),  # Vega
	Vector2(79.172, 45.998),   # Capella
	Vector2(78.634, -8.202),   # Rigel
	Vector2(114.825, 5.225),   # Procyon
	Vector2(88.793, 7.407),    # Betelgeuse
	Vector2(297.696, 8.868),   # Altair
	Vector2(68.980, 16.509),   # Aldebaran
	Vector2(201.298, -11.161), # Spica
	Vector2(247.352, -26.432), # Antares
]

## Profiles repeat at the shoulders so the settled parts of each state hold
## before a long clock-driven blend to the next. Angles are degrees: azimuth 0
## is north, 90 east, 180 south, and elevation is above the horizon.
const KEYS := [
	{"minute": 0, "state": "night",
		"ambient": Color(0.17, 0.23, 0.42), "ambient_e": 0.08,
		"fog": Color(0.050, 0.060, 0.100), "fog_d": 1.00,
		"fog_begin": 13.0, "fog_end": 58.0, "fog_curve": 1.00,
		"key": Color(0.65, 0.70, 0.90), "key_e": 0.052,
		"elevation": 35.0, "azimuth": 210.0,
		"sky_e": 0.78, "source": Color(0.58, 0.66, 0.88),
		"source_e": 0.34, "rays": 0.0, "fill": 1.0,
		"rain": Color(0.52, 0.63, 0.82, 0.68),
		"mist": Color(0.060, 0.078, 0.120, 0.34),
		"atrium": Color(0.055, 0.062, 0.082), "atrium_e": 1.0},
	{"minute": 330, "state": "night",
		"ambient": Color(0.17, 0.23, 0.42), "ambient_e": 0.08,
		"fog": Color(0.050, 0.060, 0.100), "fog_d": 1.00,
		"fog_begin": 13.0, "fog_end": 58.0, "fog_curve": 1.00,
		"key": Color(0.65, 0.70, 0.90), "key_e": 0.052,
		"elevation": 35.0, "azimuth": 210.0,
		"sky_e": 0.78, "source": Color(0.58, 0.66, 0.88),
		"source_e": 0.34, "rays": 0.0, "fill": 1.0,
		"rain": Color(0.52, 0.63, 0.82, 0.68),
		"mist": Color(0.060, 0.078, 0.120, 0.34),
		"atrium": Color(0.055, 0.062, 0.082), "atrium_e": 1.0},
	{"minute": 420, "state": "morning",
		"ambient": Color(0.39, 0.41, 0.45), "ambient_e": 0.135,
		"fog": Color(0.19, 0.20, 0.22), "fog_d": 1.00,
		"fog_begin": 13.5, "fog_end": 58.0, "fog_curve": 1.00,
		"key": Color(0.91, 0.78, 0.66), "key_e": 0.090,
		"elevation": 13.0, "azimuth": 105.0,
		"sky_e": 0.88, "source": Color(1.0, 0.72, 0.49),
		"source_e": 0.48, "rays": 0.11, "fill": 0.58,
		"rain": Color(0.69, 0.72, 0.76, 0.72),
		"mist": Color(0.18, 0.19, 0.21, 0.37),
		"atrium": Color(0.070, 0.067, 0.071), "atrium_e": 1.05},
	{"minute": 750, "state": "day",
		"ambient": Color(0.45, 0.47, 0.49), "ambient_e": 0.17,
		"fog": Color(0.28, 0.29, 0.30), "fog_d": 1.00,
		"fog_begin": 14.0, "fog_end": 58.0, "fog_curve": 1.05,
		"key": Color(0.82, 0.84, 0.86), "key_e": 0.115,
		"elevation": 53.0, "azimuth": 180.0,
		"sky_e": 0.94, "source": Color(0.93, 0.94, 0.91),
		"source_e": 0.42, "rays": 0.0, "fill": 0.34,
		"rain": Color(0.73, 0.76, 0.78, 0.67),
		"mist": Color(0.25, 0.26, 0.27, 0.35),
		"atrium": Color(0.073, 0.076, 0.080), "atrium_e": 1.10},
	{"minute": 960, "state": "day",
		"ambient": Color(0.45, 0.47, 0.49), "ambient_e": 0.17,
		"fog": Color(0.28, 0.29, 0.30), "fog_d": 1.00,
		"fog_begin": 14.0, "fog_end": 58.0, "fog_curve": 1.05,
		"key": Color(0.82, 0.84, 0.86), "key_e": 0.115,
		"elevation": 53.0, "azimuth": 180.0,
		"sky_e": 0.94, "source": Color(0.93, 0.94, 0.91),
		"source_e": 0.42, "rays": 0.0, "fill": 0.34,
		"rain": Color(0.73, 0.76, 0.78, 0.67),
		"mist": Color(0.25, 0.26, 0.27, 0.35),
		"atrium": Color(0.073, 0.076, 0.080), "atrium_e": 1.10},
	{"minute": 1050, "state": "evening",
		"ambient": Color(0.31, 0.27, 0.35), "ambient_e": 0.125,
		"fog": Color(0.15, 0.11, 0.16), "fog_d": 1.00,
		"fog_begin": 13.0, "fog_end": 58.0, "fog_curve": 1.00,
		"key": Color(0.96, 0.62, 0.45), "key_e": 0.074,
		"elevation": 11.0, "azimuth": 255.0,
		"sky_e": 0.84, "source": Color(1.0, 0.57, 0.35),
		"source_e": 0.52, "rays": 0.12, "fill": 0.55,
		"rain": Color(0.65, 0.57, 0.69, 0.71),
		"mist": Color(0.14, 0.10, 0.16, 0.37),
		"atrium": Color(0.069, 0.054, 0.071), "atrium_e": 1.04},
	{"minute": 1140, "state": "night",
		"ambient": Color(0.17, 0.23, 0.42), "ambient_e": 0.08,
		"fog": Color(0.050, 0.060, 0.100), "fog_d": 1.00,
		"fog_begin": 13.0, "fog_end": 58.0, "fog_curve": 1.00,
		"key": Color(0.65, 0.70, 0.90), "key_e": 0.052,
		"elevation": 35.0, "azimuth": 210.0,
		"sky_e": 0.78, "source": Color(0.58, 0.66, 0.88),
		"source_e": 0.34, "rays": 0.0, "fill": 1.0,
		"rain": Color(0.52, 0.63, 0.82, 0.68),
		"mist": Color(0.060, 0.078, 0.120, 0.34),
		"atrium": Color(0.055, 0.062, 0.082), "atrium_e": 1.0},
	{"minute": 1440, "state": "night",
		"ambient": Color(0.17, 0.23, 0.42), "ambient_e": 0.08,
		"fog": Color(0.050, 0.060, 0.100), "fog_d": 1.00,
		"fog_begin": 13.0, "fog_end": 58.0, "fog_curve": 1.00,
		"key": Color(0.65, 0.70, 0.90), "key_e": 0.052,
		"elevation": 35.0, "azimuth": 210.0,
		"sky_e": 0.78, "source": Color(0.58, 0.66, 0.88),
		"source_e": 0.34, "rays": 0.0, "fill": 1.0,
		"rain": Color(0.52, 0.63, 0.82, 0.68),
		"mist": Color(0.060, 0.078, 0.120, 0.34),
		"atrium": Color(0.055, 0.062, 0.082), "atrium_e": 1.0},
]

var _root: Node3D
var _env: Environment
var _sky_key: DirectionalLight3D
var _sky: ShaderMaterial
var _weather: WeatherFX
var _exterior: ExteriorDetailPass
var _accum := 9.0
var _last_minute := 180.0
var _ambient_gain := 1.0
var _fog_gain := 1.0
var _sky_key_gain := 1.0
var _pair_key := ""
var _texture_a: Texture2D
var _texture_b: Texture2D
var _last_profile: Dictionary = {}
var _live_conditions: Dictionary = {}


func setup(root: Node3D, env: Environment, sky_key: DirectionalLight3D,
		sky_mat: ShaderMaterial) -> void:
	_root = root
	_env = env
	_sky_key = sky_key
	_sky = sky_mat
	_env.set_meta("absolute_writer", "DayNightDirector")
	_sky_key.set_meta("absolute_writer", "DayNightDirector")
	_apply(_minute_now())


func bind_weather(weather: WeatherFX, exterior: ExteriorDetailPass) -> void:
	_weather = weather
	_exterior = exterior
	if not _weather.weather_flash_changed.is_connected(set_weather_flash):
		_weather.weather_flash_changed.connect(set_weather_flash)
	_apply(_last_minute)


func set_tuning_offsets(ambient_gain: float, fog_gain: float,
		sky_key_gain: float) -> void:
	_ambient_gain = clampf(ambient_gain, 0.0, 2.0)
	_fog_gain = clampf(fog_gain, 0.0, 2.0)
	_sky_key_gain = clampf(sky_key_gain, 0.0, 2.0)
	_apply(_last_minute)


func set_weather_flash(level: float) -> void:
	level = visible_weather_flash(level)
	if _sky:
		_sky.set_shader_parameter("weather_flash", clampf(level, 0.0, 1.0))
	if _exterior:
		_exterior.set_weather_flash(level)


func visible_weather_flash(level: float) -> float:
	if bool(GameBoot.settings.get("reduce_flashing", false)):
		return 0.0
	return clampf(level, 0.0, 1.0)


func resolved_profile() -> Dictionary:
	return _last_profile.duplicate(true)


func set_live_conditions(conditions: Dictionary) -> void:
	_live_conditions = conditions.duplicate(true)
	_apply(_last_minute)


func state_texture_paths() -> Dictionary:
	return SKY_PATHS.duplicate()


func _minute_now() -> float:
	var force := OS.get_environment("DAYNIGHT_FORCE").to_lower()
	if force != "":
		if STATE_MINUTES.has(force):
			return float(STATE_MINUTES[force])
		var bits := force.split(":")
		if bits.size() == 2 and bits[0].is_valid_int() \
				and bits[1].is_valid_int():
			return float(posmod(int(bits[0]) * 60 + int(bits[1]), 1440))
	if OS.get_environment("DAYNIGHT") == "0":
		return 180.0
	var now := Time.get_time_dict_from_system()
	return float(now.hour * 60 + now.minute) + float(now.second) / 60.0


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 8.0:
		return
	_accum = 0.0
	_apply(_minute_now())


func _apply(minute: float) -> void:
	if _env == null:
		return
	_last_minute = minute
	var span := _span_at(minute)
	var a: Dictionary = span.a
	var b: Dictionary = span.b
	var t: float = span.t
	var profile := {
		"state_a": a.state,
		"state_b": b.state,
		"blend": t,
		"ambient": (a.ambient as Color).lerp(b.ambient, t),
		"ambient_e": lerpf(a.ambient_e, b.ambient_e, t),
		"fog": (a.fog as Color).lerp(b.fog, t),
		"fog_d": lerpf(a.fog_d, b.fog_d, t),
		"fog_begin": lerpf(a.fog_begin, b.fog_begin, t),
		"fog_end": lerpf(a.fog_end, b.fog_end, t),
		"fog_curve": lerpf(a.fog_curve, b.fog_curve, t),
		"key": (a.key as Color).lerp(b.key, t),
		"key_e": lerpf(a.key_e, b.key_e, t),
		"source": (a.source as Color).lerp(b.source, t),
		"source_e": lerpf(a.source_e, b.source_e, t),
		"rays": lerpf(a.rays, b.rays, t),
		"cloud_depth": lerpf(_cloud_depth(str(a.state)),
				_cloud_depth(str(b.state)), t),
		"fill": lerpf(a.fill, b.fill, t),
		"rain": (a.rain as Color).lerp(b.rain, t),
		"mist": (a.mist as Color).lerp(b.mist, t),
		"atrium": (a.atrium as Color).lerp(b.atrium, t),
		"atrium_e": lerpf(a.atrium_e, b.atrium_e, t),
	}
	if not _live_conditions.is_empty():
		var clouds := clampf(float(_live_conditions.get("cloud_total", 0.0)), 0.0, 1.0)
		var low_clouds := clampf(float(_live_conditions.get("cloud_low", clouds)), 0.0, 1.0)
		var mid_clouds := clampf(float(_live_conditions.get("cloud_mid", 0.0)), 0.0, 1.0)
		var high_clouds := clampf(float(_live_conditions.get("cloud_high", 0.0)), 0.0, 1.0)
		var strata := _cloud_strata(low_clouds, mid_clouds, high_clouds)
		# Current conditions tune the authored panorama rather than replacing it
		# with another generic or procedural sky.
		profile.cloud_depth = strata.lower_strength
		profile["cloud_coverage"] = strata.lower_coverage
		profile["high_cloud_strength"] = strata.high_strength
		# Cloud cover changes illumination as well as the photograph. Preserve the
		# diffuse Environment fill, but attenuate the single exterior directional
		# key and its hard-ray term through one measured presentation coefficient.
		var direct_transmission := _cloud_direct_transmission_strata(
				low_clouds, mid_clouds, high_clouds)
		profile.key_e *= direct_transmission
		profile.rays *= direct_transmission
		profile["cloud_direct_transmission"] = direct_transmission
		var precipitation := clampf(float(_live_conditions.get(
				"precipitation_intensity", 0.0)), 0.0, 1.0)
		var humidity := clampf(float(_live_conditions.get(
				"relative_humidity", 0.70)), 0.0, 1.0)
		var weather_code := int(_live_conditions.get("weather_code", 0))
		profile.fog_d *= _weather_fog_multiplier(
				low_clouds, precipitation, weather_code, humidity)
		profile.mist.a *= lerpf(0.34, 1.0,
				maxf(low_clouds, precipitation))
		profile["live_weather"] = _live_conditions.duplicate(true)
	var source_a := _source_direction(a.elevation, a.azimuth)
	var source_b := _source_direction(b.elevation, b.azimuth)
	var source_dir := source_a.slerp(source_b, t).normalized()
	if OS.get_environment("DAYNIGHT") != "0" \
			and OS.get_environment("DAYNIGHT_FORCE").is_empty():
		var utc := Time.get_datetime_dict_from_system(true)
		var latitude := float(_live_conditions.get("latitude", 40.75))
		var longitude := float(_live_conditions.get("longitude", -73.92))
		var sun: Vector3 = CelestialEphemerisScript.sun_direction(
				utc, latitude, longitude)
		var moon: Vector3 = CelestialEphemerisScript.moon_direction(
				utc, latitude, longitude)
		source_dir = sun if sun.y > -0.035 else moon
		profile["sun_direction"] = sun
		profile["moon_direction"] = moon
		profile["moon_illumination"] = \
				CelestialEphemerisScript.moon_illuminated_fraction(
						utc, latitude, longitude)
		profile["moon_phase_enabled"] = sun.y <= -0.035
		profile["observer"] = Vector2(latitude, longitude)
		profile["equatorial_axes"] = CelestialEphemerisScript.equatorial_axes(
				utc, latitude, longitude)
		var stars := PackedVector3Array()
		for catalog_position: Vector2 in BRIGHT_STARS:
			stars.append(CelestialEphemerisScript.star_direction(
					catalog_position.x, catalog_position.y, utc,
					latitude, longitude))
		profile["bright_stars"] = stars
		profile["star_strength"] = clampf((-sun.y - 0.04) / 0.18, 0.0, 1.0)

	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_enabled = true
	_env.fog_height_density = 0.0
	_env.ambient_light_color = profile.ambient
	_env.ambient_light_energy = profile.ambient_e * _ambient_gain
	_env.background_color = profile.fog
	_env.fog_light_color = profile.fog
	_env.fog_density = clampf(profile.fog_d * _fog_gain, 0.0, 1.0)
	_env.fog_depth_begin = profile.fog_begin
	_env.fog_depth_end = profile.fog_end
	_env.fog_depth_curve = profile.fog_curve

	if _sky_key:
		_sky_key.light_color = profile.key
		_sky_key.light_energy = profile.key_e * _sky_key_gain
		_sky_key.look_at(_sky_key.global_position - source_dir, Vector3.UP)
	if _sky:
		_set_sky_pair(a.state, b.state)
		_sky.set_shader_parameter("sky_blend", t)
		_sky.set_shader_parameter("exposure", lerpf(a.sky_e, b.sky_e, t))
		_sky.set_shader_parameter("fog_horizon_color", profile.fog)
		_sky.set_shader_parameter("celestial_direction", source_dir)
		_sky.set_shader_parameter("sun_direction",
				profile.get("sun_direction", -source_dir))
		_sky.set_shader_parameter("celestial_color", profile.source)
		_sky.set_shader_parameter("celestial_strength", profile.source_e)
		var phase_enabled := bool(profile.get("moon_phase_enabled", false))
		_sky.set_shader_parameter("moon_phase_enabled", phase_enabled)
		_sky.set_shader_parameter("moon_illumination",
				float(profile.get("moon_illumination", 1.0)))
		# Sun and Moon both span roughly half a degree. Retain the old larger
		# authored core only for forced showcase states with no UTC ephemeris.
		_sky.set_shader_parameter("celestial_core_radius",
				deg_to_rad(0.27 if profile.has("sun_direction") else 2.2))
		_sky.set_shader_parameter("celestial_halo_radius", deg_to_rad(18.0))
		if profile.has("bright_stars"):
			var axes: PackedVector3Array = profile.equatorial_axes
			_sky.set_shader_parameter("equatorial_axis_x", axes[0])
			_sky.set_shader_parameter("equatorial_axis_y", axes[1])
			_sky.set_shader_parameter("equatorial_axis_z", axes[2])
			_sky.set_shader_parameter("bright_stars", profile.bright_stars)
			_sky.set_shader_parameter("star_strength", profile.star_strength)
		else:
			_sky.set_shader_parameter("star_strength", 0.0)
		_sky.set_shader_parameter("lower_cloud_strength", profile.cloud_depth)
		_sky.set_shader_parameter("cloud_coverage",
				float(profile.get("cloud_coverage", profile.cloud_depth)))
		_sky.set_shader_parameter("high_cloud_strength",
				float(profile.get("high_cloud_strength", 0.0)))
		var live_weather: Dictionary = profile.get("live_weather", {})
		_sky.set_shader_parameter("cloud_wind_direction",
				_wind_direction_vector(float(live_weather.get(
						"wind_direction_degrees", 270.0))))
		_sky.set_shader_parameter("cloud_wind_speed", clampf(float(
				live_weather.get("wind_speed_kmh", 8.0)), 0.0, 120.0))
		_sky.set_shader_parameter("urban_horizon_gain", lerpf(
				_urban_horizon_for_state(str(a.state)),
				_urban_horizon_for_state(str(b.state)), t))
		var rays_enabled := OS.get_environment("WEATHER_RAYS") != "0"
		_sky.set_shader_parameter("ray_strength",
				profile.rays if rays_enabled else 0.0)
	if _weather:
		_weather.apply_profile(profile)
	if _exterior:
		_exterior.set_weather_profile(profile.mist)
		_exterior.set_neighbour_occupancy_gain(lerpf(
				_neighbour_occupancy_for_state(str(a.state)),
				_neighbour_occupancy_for_state(str(b.state)), t))
		_exterior.set_neighbour_light_profile(lerpf(
				_neighbour_light_for_state(str(a.state)),
				_neighbour_light_for_state(str(b.state)), t), source_dir)
	if _root:
		if _root.get("moon_fill") != null and _root.moon_fill != null:
			_root.moon_fill.energy_scale = profile.fill
		_apply_atrium(profile.atrium, profile.atrium_e)
	_last_profile = profile
	_last_profile["source_direction"] = source_dir


func _neighbour_occupancy_for_state(state: String) -> float:
	match state:
		"day": return 0.0
		"morning": return 0.18
		"evening": return 0.72
		_: return 1.0


func _neighbour_light_for_state(state: String) -> float:
	match state:
		"day": return 3.25
		"morning": return 2.05
		"evening": return 1.38
		_: return 1.0


func _urban_horizon_for_state(state: String) -> float:
	match state:
		"night": return 1.0
		"evening": return 0.62
		"morning": return 0.28
		_: return 0.0


func _cloud_direct_transmission(coverage: float) -> float:
	## Bounded bulk transmission for the one world-space exterior key. The sky
	## shader still decides whether the actual Sun/Moon disc sits behind a local
	## cloud cell; this coefficient describes the average light reaching Queens.
	var optical_cover := smoothstep(0.08, 0.94, clampf(coverage, 0.0, 1.0))
	return lerpf(1.0, 0.12, optical_cover)


func _cloud_direct_transmission_strata(low: float, mid: float,
		high: float) -> float:
	## Equal total fractions do not imply equal optical depth. Treat low deck as
	## the scalar boundary, mid as 68%, and thin high veil as 32% effective cover.
	var effective_cover := maxf(clampf(low, 0.0, 1.0), maxf(
			clampf(mid, 0.0, 1.0) * 0.68,
			clampf(high, 0.0, 1.0) * 0.32))
	return _cloud_direct_transmission(effective_cover)


func _cloud_strata(low: float, mid: float, high: float) -> Dictionary:
	## Mid-level cloud contributes to both presentations but cannot close the
	## low deck by itself. High-only cover remains a translucent veil.
	return {
		"lower_strength": maxf(clampf(low, 0.0, 1.0),
				clampf(mid, 0.0, 1.0) * 0.48),
		"lower_coverage": maxf(clampf(low, 0.0, 1.0),
				clampf(mid, 0.0, 1.0) * 0.38),
		"high_strength": maxf(clampf(high, 0.0, 1.0),
				clampf(mid, 0.0, 1.0) * 0.55),
	}


func _weather_fog_multiplier(low_clouds: float, precipitation: float,
		weather_code: int, humidity: float = 0.70) -> float:
	## A dry ceiling is not ground fog. Low cloud supplies only modest aerial
	## perspective; precipitation and WMO fog codes may close the distance.
	var wet_or_fog := clampf(precipitation, 0.0, 1.0)
	if weather_code in [45, 48]:
		wet_or_fog = 1.0
	var humid_haze := smoothstep(0.72, 1.0, clampf(humidity, 0.0, 1.0)) * 0.08
	return lerpf(0.78, 0.84, clampf(low_clouds, 0.0, 1.0)) \
			+ wet_or_fog * 0.18 + humid_haze


func _wind_direction_vector(degrees_from_north: float) -> Vector3:
	## Meteorological direction is the bearing wind comes from. Cloud motion is
	## where it goes, so reverse the north/east bearing into Godot X/Z space.
	var bearing := deg_to_rad(fposmod(degrees_from_north, 360.0))
	return Vector3(-sin(bearing), 0.0, cos(bearing)).normalized()


func _span_at(minute: float) -> Dictionary:
	var a: Dictionary = KEYS[0]
	var b: Dictionary = KEYS[KEYS.size() - 1]
	for i in KEYS.size() - 1:
		if minute >= float(KEYS[i].minute) \
				and minute <= float(KEYS[i + 1].minute):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var width := float(b.minute) - float(a.minute)
	return {"a": a, "b": b,
		"t": 0.0 if width <= 0.0 else (minute - float(a.minute)) / width}


func _set_sky_pair(state_a: String, state_b: String) -> void:
	var key := state_a + ">" + state_b
	if key == _pair_key:
		return
	_pair_key = key
	_texture_a = load(SKY_PATHS[state_a]) as Texture2D
	_texture_b = load(SKY_PATHS[state_b]) as Texture2D
	_sky.set_shader_parameter("panorama_a", _texture_a)
	_sky.set_shader_parameter("panorama_b", _texture_b)
	_sky.set_shader_parameter("panorama_a_celestial", state_a == "night")
	_sky.set_shader_parameter("panorama_b_celestial", state_b == "night")


func _source_direction(elevation_degrees: float,
		azimuth_degrees: float) -> Vector3:
	var elevation := deg_to_rad(elevation_degrees)
	var azimuth := deg_to_rad(azimuth_degrees)
	var horizontal := cos(elevation)
	return Vector3(sin(azimuth) * horizontal, sin(elevation),
			-cos(azimuth) * horizontal)


func _cloud_depth(state: String) -> float:
	match state:
		"morning": return 0.34
		"day": return 0.24
		"evening": return 0.32
		_: return 0.29


func _apply_atrium(color: Color, strength: float) -> void:
	var shaft := _root.get_node_or_null("AtriumShaft") as MeshInstance3D
	if shaft and shaft.material_override is StandardMaterial3D:
		shaft.material_override.albedo_color = Color(
				color.r * strength, color.g * strength,
				color.b * strength, 1.0)
	var mouth := _root.get_node_or_null("AtriumSkylightPool") as MeshInstance3D
	if mouth and mouth.material_override is StandardMaterial3D:
		mouth.material_override.albedo_color = Color(
				color.r * strength * 1.4, color.g * strength * 1.4,
				color.b * strength * 1.4, 1.0)
