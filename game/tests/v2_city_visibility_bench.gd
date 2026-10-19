extends Node
const CityDirector := preload("res://scripts/building/v2_city_day_night_director.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY VISIBILITY: " + label)

func _ready() -> void:
	var legacy := DayNightDirector.new()
	var city := CityDirector.new()
	legacy._env = Environment.new()
	city._env = Environment.new()
	# Exercise the actual writer, including subsequent clock/weather refreshes.
	for minute: float in [0.0, 420.0, 750.0, 1050.0]:
		legacy._apply(minute)
		city._apply(minute)
		check(is_equal_approx(legacy._env.fog_depth_end, 58.0), "retained V1 far distance")
		check(is_equal_approx(city._env.fog_depth_end, 400.0), "dry V2 outer blocks retain depth")
		check(is_equal_approx(city._env.fog_depth_begin, 70.0), "dry near field stays clear")
		check(city.resolved_profile().fog_end == city._env.fog_depth_end, "reported profile is the actual Environment")
		check(is_equal_approx(city._env.fog_density, 1.0), "far ground reaches actual extinction")
	for conditions: Dictionary in [
		{"cloud_cover_low": 1.0, "relative_humidity": 1.0, "weather_code": 3},
		{"precipitation_intensity": 1.0, "weather_code": 95},
		{"precipitation_intensity": 0.0, "weather_code": 45},
		{"precipitation_intensity": 0.0, "weather_code": 48},
	]:
		city.set_live_conditions(conditions)
		var expected := CityDirector.city_visibility(conditions)
		check(is_equal_approx(city._env.fog_depth_end, expected.y), "weather updates the same writer")
		check(is_equal_approx(city._env.fog_depth_begin, expected.x), "weather updates the same near field")
		check(city._env.fog_enabled and city._env.fog_mode == Environment.FOG_MODE_DEPTH, "depth fog remains enabled")
		if int(conditions.weather_code) in [45, 48, 95]:
			check(expected.is_equal_approx(Vector2(13, 58)), "fog and heavy storm retain extinction distance")
		else:
			check(expected.y >= 300.0, "dry overcast is not ground fog")
	var previous := 400.0
	for index in 101:
		var distance := CityDirector.city_visibility({"precipitation_intensity": index / 100.0}).y
		check(distance <= previous + 0.0001 and distance >= 58.0, "continuous monotone wet transition")
		previous = distance
	city.set_live_conditions({})
	check(is_equal_approx(city._env.fog_depth_end, 400.0), "clearing weather restores visibility")
	legacy.free()
	city.free()
	print("CITY VISIBILITY BENCH: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(failures.size())
