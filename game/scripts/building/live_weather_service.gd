class_name LiveWeatherService
extends Node
## Privacy-explicit real weather for the waking Orison.
##
## Default sends only the fixed Queens coordinates to Open-Meteo. If the
## player explicitly enables local weather and supplies a city/postal code,
## that text is first resolved by Open-Meteo's geocoder; no IP location,
## device sensor or hidden coordinate collection occurs.

signal weather_updated(snapshot: Dictionary)
signal weather_failed(reason: String)

const QUEENS := {
	"name": "Queens, New York",
	"latitude": 40.75,
	"longitude": -73.92,
	"timezone": "America/New_York",
}
const GEOCODE_ENDPOINT := "https://geocoding-api.open-meteo.com/v1/search"
const WEATHER_ENDPOINT := "https://api.open-meteo.com/v1/forecast"
const REFRESH_SECONDS := 15.0 * 60.0
const SIMULATION_PRESETS := {
	"clear": {"code": 0, "cloud": 0.0, "low": 0.0, "rain": 0.0, "snow": 0.0, "wind": 5.0},
	"scattered": {"code": 2, "cloud": 0.38, "low": 0.24, "rain": 0.0, "snow": 0.0, "wind": 10.0},
	"overcast": {"code": 3, "cloud": 1.0, "low": 0.92, "rain": 0.0, "snow": 0.0, "wind": 13.0},
	"rain": {"code": 61, "cloud": 0.92, "low": 0.84, "rain": 1.2, "snow": 0.0, "wind": 22.0},
	"storm": {"code": 95, "cloud": 1.0, "low": 1.0, "rain": 4.0, "snow": 0.0, "wind": 42.0},
	"snow": {"code": 73, "cloud": 0.96, "low": 0.90, "rain": 0.3, "snow": 1.4, "wind": 17.0},
	"fog": {"code": 45, "cloud": 0.76, "low": 1.0, "rain": 0.0, "snow": 0.0, "wind": 2.0},
}

var _request: HTTPRequest
var _location := QUEENS.duplicate(true)
var _snapshot: Dictionary = {}
var _refresh_left := 0.0
var _awaiting := ""


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.name = "LiveWeatherHTTPRequest"
	_request.timeout = 8.0
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	refresh()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0 and _awaiting == "":
		refresh()


func refresh() -> bool:
	if _request == null or _awaiting != "":
		return false
	_refresh_left = REFRESH_SECONDS
	var simulation := OS.get_environment("WEATHER_SIMULATE").to_lower()
	if SIMULATION_PRESETS.has(simulation):
		_location = QUEENS.duplicate(true)
		_snapshot = simulated_snapshot(simulation)
		weather_updated.emit(snapshot())
		return true
	var local_enabled := bool(GameBoot.settings.get("live_local_weather", false))
	var query := str(GameBoot.settings.get("weather_location_query", "")).strip_edges()
	if local_enabled and not query.is_empty():
		_awaiting = "geocode"
		return _request.request(geocode_url(query)) == OK
	_location = QUEENS.duplicate(true)
	_awaiting = "weather"
	return _request.request(weather_url(_location.latitude,
			_location.longitude)) == OK


func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func resolved_location() -> Dictionary:
	return _location.duplicate(true)


func is_using_player_location() -> bool:
	return bool(GameBoot.settings.get("live_local_weather", false)) \
			and not str(GameBoot.settings.get(
					"weather_location_query", "")).strip_edges().is_empty() \
			and str(_location.get("name", "")) != str(QUEENS.name)


static func geocode_url(query: String) -> String:
	return GEOCODE_ENDPOINT + "?name=" + query.uri_encode() \
			+ "&count=1&language=en&format=json"


static func weather_url(latitude: float, longitude: float) -> String:
	return WEATHER_ENDPOINT + "?latitude=%.5f&longitude=%.5f" % [
			latitude, longitude] \
			+ "&current=temperature_2m,relative_humidity_2m,precipitation," \
			+ "rain,showers,snowfall,weather_code,cloud_cover,cloud_cover_low," \
			+ "cloud_cover_mid,cloud_cover_high,wind_speed_10m," \
			+ "wind_direction_10m,wind_gusts_10m,is_day" \
			+ "&timezone=auto"


static func parse_geocode(payload: Variant) -> Dictionary:
	if payload is not Dictionary:
		return {}
	var results: Array = payload.get("results", [])
	if results.is_empty() or results[0] is not Dictionary:
		return {}
	var row: Dictionary = results[0]
	if not row.has("latitude") or not row.has("longitude"):
		return {}
	var pieces: Array[String] = [str(row.get("name", "Local weather"))]
	var admin := str(row.get("admin1", ""))
	var country := str(row.get("country", ""))
	if not admin.is_empty() and admin not in pieces:
		pieces.append(admin)
	if not country.is_empty() and country not in pieces:
		pieces.append(country)
	return {
		"name": ", ".join(pieces),
		"latitude": float(row.latitude),
		"longitude": float(row.longitude),
		"timezone": str(row.get("timezone", "auto")),
	}


static func parse_weather(payload: Variant, location: Dictionary) -> Dictionary:
	if payload is not Dictionary or payload.get("current") is not Dictionary:
		return {}
	var current: Dictionary = payload.current
	var required := ["time", "weather_code", "cloud_cover",
			"cloud_cover_low", "cloud_cover_mid", "cloud_cover_high",
			"precipitation", "wind_speed_10m", "wind_direction_10m", "is_day"]
	for key in required:
		if not current.has(key):
			return {}
	return {
		"source": "open-meteo",
		"observed_at": str(current.time),
		"location": location.duplicate(true),
		"weather_code": int(current.weather_code),
		"temperature_c": float(current.get("temperature_2m", 0.0)),
		"relative_humidity": float(current.get("relative_humidity_2m", 0.0)),
		"precipitation_mm": maxf(0.0, float(current.precipitation)),
		"rain_mm": maxf(0.0, float(current.get("rain", 0.0))),
		"showers_mm": maxf(0.0, float(current.get("showers", 0.0))),
		"snowfall_cm": maxf(0.0, float(current.get("snowfall", 0.0))),
		"cloud_total": clampf(float(current.cloud_cover) / 100.0, 0.0, 1.0),
		"cloud_low": clampf(float(current.cloud_cover_low) / 100.0, 0.0, 1.0),
		"cloud_mid": clampf(float(current.cloud_cover_mid) / 100.0, 0.0, 1.0),
		"cloud_high": clampf(float(current.cloud_cover_high) / 100.0, 0.0, 1.0),
		"wind_speed_kmh": maxf(0.0, float(current.wind_speed_10m)),
		"wind_direction_degrees": fposmod(float(current.wind_direction_10m), 360.0),
		"wind_gusts_kmh": maxf(0.0, float(current.get("wind_gusts_10m", 0.0))),
		"is_day": int(current.is_day) == 1,
	}


static func presentation(snapshot: Dictionary) -> Dictionary:
	## The network never owns a material or particle node. It publishes a small,
	## normalized contract and the existing visual owners decide how it looks.
	if snapshot.is_empty():
		return {}
	var precipitation := maxf(float(snapshot.get("precipitation_mm", 0.0)),
			float(snapshot.get("rain_mm", 0.0))
			+ float(snapshot.get("showers_mm", 0.0)))
	var snowfall := maxf(0.0, float(snapshot.get("snowfall_cm", 0.0)))
	var location: Dictionary = snapshot.get("location", {})
	return {
		"latitude": float(location.get("latitude", QUEENS.latitude)),
		"longitude": float(location.get("longitude", QUEENS.longitude)),
		"weather_code": int(snapshot.get("weather_code", 0)),
		"temperature_c": clampf(float(snapshot.get("temperature_c", 12.0)),
				-50.0, 55.0),
		"relative_humidity": clampf(float(snapshot.get(
				"relative_humidity", 70.0)) / 100.0, 0.0, 1.0),
		"cloud_total": clampf(float(snapshot.get("cloud_total", 0.0)), 0.0, 1.0),
		"cloud_low": clampf(float(snapshot.get("cloud_low", 0.0)), 0.0, 1.0),
		"cloud_mid": clampf(float(snapshot.get("cloud_mid", 0.0)), 0.0, 1.0),
		"cloud_high": clampf(float(snapshot.get("cloud_high", 0.0)), 0.0, 1.0),
		"wet": precipitation > 0.02,
		"precipitation_intensity": clampf(precipitation / 2.5, 0.0, 1.0),
		"snowing": snowfall > 0.01,
		"wind_speed_kmh": maxf(0.0, float(snapshot.get("wind_speed_kmh", 0.0))),
		"wind_direction_degrees": fposmod(float(snapshot.get(
				"wind_direction_degrees", 0.0)), 360.0),
		"wind_gusts_kmh": maxf(0.0, float(snapshot.get("wind_gusts_kmh", 0.0))),
	}


static func simulated_snapshot(preset: String) -> Dictionary:
	if not SIMULATION_PRESETS.has(preset):
		return {}
	var value: Dictionary = SIMULATION_PRESETS[preset]
	var wind_speed := float(value.wind)
	var wind_direction := 225.0
	var cloud_total := float(value.cloud)
	var cloud_low := float(value.low)
	var cloud_mid := float(value.cloud) * 0.72
	var cloud_high := float(value.cloud) * 0.48
	var temperature := 12.0
	var humidity := 70.0
	var temperature_override := OS.get_environment("WEATHER_SIMULATE_TEMPERATURE_C")
	var humidity_override := OS.get_environment("WEATHER_SIMULATE_HUMIDITY")
	if temperature_override.is_valid_float():
		temperature = clampf(float(temperature_override), -50.0, 55.0)
	if humidity_override.is_valid_float():
		humidity = clampf(float(humidity_override), 0.0, 100.0)
	var strata_overridden := false
	for field in [
			["WEATHER_SIMULATE_CLOUD_LOW", "low"],
			["WEATHER_SIMULATE_CLOUD_MID", "mid"],
			["WEATHER_SIMULATE_CLOUD_HIGH", "high"],
	]:
		var raw := OS.get_environment(field[0])
		if not raw.is_valid_float():
			continue
		var bounded := clampf(float(raw), 0.0, 1.0)
		match field[1]:
			"low": cloud_low = bounded
			"mid": cloud_mid = bounded
			"high": cloud_high = bounded
		strata_overridden = true
	var total_override := OS.get_environment("WEATHER_SIMULATE_CLOUD_TOTAL")
	if total_override.is_valid_float():
		cloud_total = clampf(float(total_override), 0.0, 1.0)
	elif strata_overridden:
		cloud_total = maxf(cloud_low, maxf(cloud_mid, cloud_high))
	var speed_override := OS.get_environment("WEATHER_SIMULATE_WIND_KMH")
	var direction_override := OS.get_environment("WEATHER_SIMULATE_WIND_DEGREES")
	if speed_override.is_valid_float():
		wind_speed = clampf(float(speed_override), 0.0, 120.0)
	if direction_override.is_valid_float():
		wind_direction = fposmod(float(direction_override), 360.0)
	return {
		"source": "simulation", "observed_at": "simulated",
		"location": QUEENS.duplicate(true), "weather_code": int(value.code),
		"temperature_c": temperature, "relative_humidity": humidity,
		"precipitation_mm": float(value.rain), "rain_mm": float(value.rain),
		"showers_mm": 0.0, "snowfall_cm": float(value.snow),
		"cloud_total": cloud_total, "cloud_low": cloud_low,
		"cloud_mid": cloud_mid, "cloud_high": cloud_high,
		"wind_speed_kmh": wind_speed, "wind_direction_degrees": wind_direction,
		"wind_gusts_kmh": wind_speed * 1.45, "is_day": true,
	}


func _on_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	var stage := _awaiting
	_awaiting = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail("%s request failed (%d/%d)" % [stage, result, response_code])
		return
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if stage == "geocode":
		var found := parse_geocode(payload)
		if found.is_empty():
			_fail("location was not found")
			return
		_location = found
		_awaiting = "weather"
		if _request.request(weather_url(_location.latitude,
				_location.longitude)) != OK:
			_awaiting = ""
			_fail("weather request could not start")
		return
	var parsed := parse_weather(payload, _location)
	if parsed.is_empty():
		_fail("weather response was incomplete")
		return
	_snapshot = parsed
	weather_updated.emit(snapshot())


func _fail(reason: String) -> void:
	# Failure never changes location policy and never turns on local lookup.
	# The existing authored Queens storm remains the visual fallback.
	weather_failed.emit(reason)
