extends Node

const SoundscapeScript := preload("res://scripts/audio/ambient_soundscape.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	var clear := {"wet":false, "rain_intensity":0.0, "hailing":false}
	var rain := {"wet":true, "rain_intensity":0.7, "hailing":false}
	var hail := {"wet":true, "rain_intensity":1.0, "hailing":true}
	_check("no snapshot preserves the authored failure fallback",
			is_equal_approx(SoundscapeScript.roof_weather_db({}, true), -16.5))
	_check("known clear weather cannot play the storm roof bed",
			is_equal_approx(SoundscapeScript.roof_weather_db(clear, true), -60.0))
	_check("rain scales the storm bed without exceeding its authored ceiling",
			SoundscapeScript.roof_weather_db(rain, true) > -31.0
			and SoundscapeScript.roof_weather_db(rain, true) < -16.5)
	_check("indoors never hears the roof bed regardless of weather",
			is_equal_approx(SoundscapeScript.roof_weather_db(hail, false), -60.0))
	_check("clear exterior events contain no rain or hail recording",
			SoundscapeScript.outdoor_event_keys(clear) == ["creak"])
	_check("liquid and hail conditions select distinct honest families",
			SoundscapeScript.outdoor_event_keys(rain)
			== ["distant_rain_people", "rain_on_metal"]
			and SoundscapeScript.outdoor_event_keys(hail)
			== ["hail_window", "rain_on_metal"])
	print("[AMBIENT WEATHER AUDIO] RESULT: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[AMBIENT WEATHER AUDIO] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
