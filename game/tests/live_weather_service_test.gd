extends Node

const WeatherServiceScript := preload(
		"res://scripts/building/live_weather_service.gd")

var fails := 0


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["weather service ok" if ok else "WEATHER SERVICE FAIL", label])
	if not ok:
		fails += 1


func _ready() -> void:
	var queens_url: String = WeatherServiceScript.weather_url(
			WeatherServiceScript.QUEENS.latitude,
			WeatherServiceScript.QUEENS.longitude)
	_check(queens_url.begins_with("https://api.open-meteo.com/")
			and queens_url.contains("latitude=40.75000")
			and queens_url.contains("longitude=-73.92000")
			and queens_url.contains("cloud_cover_low")
			and queens_url.contains("wind_gusts_10m"),
			"the fallback requests Queens and all sky-driving conditions over TLS")
	var geocode_url: String = WeatherServiceScript.geocode_url("Portland, Maine")
	_check(geocode_url.begins_with("https://geocoding-api.open-meteo.com/")
			and geocode_url.contains("Portland%2C%20Maine")
			and not geocode_url.contains("ip="),
			"opt-in geocodes only player-authored text, never an IP address")

	var location: Dictionary = WeatherServiceScript.parse_geocode({"results": [{
		"name": "Portland", "admin1": "Maine", "country": "United States",
		"latitude": 43.6591, "longitude": -70.2568,
		"timezone": "America/New_York"}]})
	_check(str(location.name) == "Portland, Maine, United States"
			and is_equal_approx(float(location.latitude), 43.6591),
			"a geocoder result becomes an explicit resolved observer")
	var weather: Dictionary = WeatherServiceScript.parse_weather({"current": {
		"time": "2026-08-25T22:15", "temperature_2m": 18.4,
		"relative_humidity_2m": 91, "precipitation": 1.2, "rain": 0.8,
		"showers": 0.4, "snowfall": 0.0, "weather_code": 61,
		"cloud_cover": 93, "cloud_cover_low": 75,
		"cloud_cover_mid": 42, "cloud_cover_high": 88,
		"wind_speed_10m": 24.0, "wind_direction_10m": 401.0,
		"wind_gusts_10m": 39.0, "is_day": 0}}, location)
	_check(not weather.is_empty()
			and is_equal_approx(float(weather.cloud_total), 0.93)
			and is_equal_approx(float(weather.cloud_low), 0.75)
			and is_equal_approx(float(weather.wind_direction_degrees), 41.0)
			and not bool(weather.is_day),
			"weather JSON normalizes cloud strata, precipitation, wind and daylight")
	var presentation: Dictionary = WeatherServiceScript.presentation(weather)
	_check(bool(presentation.wet)
			and int(presentation.weather_code) == 61
			and is_equal_approx(float(presentation.temperature_c), 18.4)
			and is_equal_approx(float(presentation.relative_humidity), 0.91)
			and is_equal_approx(float(presentation.precipitation_intensity), 0.48)
			and is_equal_approx(float(presentation.rain_intensity), 0.48)
			and is_zero_approx(float(presentation.snow_intensity))
			and is_equal_approx(float(presentation.cloud_high), 0.88)
			and is_equal_approx(float(presentation.wind_direction_degrees), 41.0)
			and is_equal_approx(float(presentation.latitude), 43.6591)
			and is_equal_approx(float(presentation.longitude), -70.2568),
			"the service publishes normalized facts without owning visual nodes")
	_check(WeatherServiceScript.presentation({}).is_empty(),
			"no observation leaves the authored Queens storm untouched")
	var clear := WeatherServiceScript.presentation(
			WeatherServiceScript.simulated_snapshot("clear"))
	var storm := WeatherServiceScript.presentation(
			WeatherServiceScript.simulated_snapshot("storm"))
	var snow := WeatherServiceScript.presentation(
			WeatherServiceScript.simulated_snapshot("snow"))
	_check(not bool(clear.wet) and is_zero_approx(float(clear.cloud_total)),
			"the clear simulator reaches true zero cloud and precipitation")
	_check(bool(storm.wet) and bool(storm.thunderstorm)
			and is_equal_approx(float(storm.cloud_total), 1.0)
			and is_equal_approx(float(storm.precipitation_intensity), 1.0),
			"the storm simulator alone carries thunder with closed cloud and maximum rain")
	_check(not bool(clear.thunderstorm) and not bool(snow.thunderstorm),
			"clear and frozen precipitation cannot invent lightning")
	_check(bool(snow.snowing) and not bool(snow.wet)
			and is_zero_approx(float(snow.rain_intensity))
			and float(snow.snow_intensity) > 0.0
			and float(snow.precipitation_intensity) > 0.0,
			"the snow simulator is a distinct frozen precipitation branch")
	OS.set_environment("WEATHER_SIMULATE_WIND_KMH", "37.5")
	OS.set_environment("WEATHER_SIMULATE_WIND_DEGREES", "450")
	var directed := WeatherServiceScript.simulated_snapshot("scattered")
	OS.set_environment("WEATHER_SIMULATE_WIND_KMH", "")
	OS.set_environment("WEATHER_SIMULATE_WIND_DEGREES", "")
	_check(is_equal_approx(float(directed.wind_speed_kmh), 37.5)
			and is_equal_approx(float(directed.wind_direction_degrees), 90.0),
			"simulation can exercise bounded speed and every wind bearing")
	OS.set_environment("WEATHER_SIMULATE_CLOUD_LOW", "0")
	OS.set_environment("WEATHER_SIMULATE_CLOUD_MID", "0")
	OS.set_environment("WEATHER_SIMULATE_CLOUD_HIGH", "1")
	var high_only := WeatherServiceScript.simulated_snapshot("clear")
	OS.set_environment("WEATHER_SIMULATE_CLOUD_LOW", "")
	OS.set_environment("WEATHER_SIMULATE_CLOUD_MID", "")
	OS.set_environment("WEATHER_SIMULATE_CLOUD_HIGH", "")
	_check(is_zero_approx(float(high_only.cloud_low))
			and is_zero_approx(float(high_only.cloud_mid))
			and is_equal_approx(float(high_only.cloud_high), 1.0)
			and is_equal_approx(float(high_only.cloud_total), 1.0),
			"strata simulation derives coherent total cover when not overridden")
	OS.set_environment("WEATHER_SIMULATE_TEMPERATURE_C", "-80")
	OS.set_environment("WEATHER_SIMULATE_HUMIDITY", "140")
	var bounded_air := WeatherServiceScript.simulated_snapshot("clear")
	OS.set_environment("WEATHER_SIMULATE_TEMPERATURE_C", "")
	OS.set_environment("WEATHER_SIMULATE_HUMIDITY", "")
	_check(is_equal_approx(float(bounded_air.temperature_c), -50.0)
			and is_equal_approx(float(bounded_air.relative_humidity), 100.0),
			"temperature and humidity simulation stay inside the public bounds")
	_check(WeatherServiceScript.simulated_snapshot("not_weather").is_empty(),
			"unknown simulation names cannot silently become weather")
	_check(WeatherServiceScript.parse_weather({"current": {"time": "bad"}},
			location).is_empty(),
			"an incomplete response cannot partially mutate the sky")

	print("[LIVE WEATHER SERVICE] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
