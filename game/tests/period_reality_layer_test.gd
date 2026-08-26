extends Node

const PeriodRealityScript := preload(
		"res://scripts/building/period_reality_layer.gd")

var fails := 0


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["period reality ok" if ok else "PERIOD REALITY FAIL", label])
	if not ok:
		fails += 1


func _ready() -> void:
	var layer: Node3D = PeriodRealityScript.new()
	add_child(layer)
	await get_tree().process_frame
	var state: Dictionary = layer.call("diagnostic_snapshot")
	_check(int(state.aircraft_draws) == 1
			and int(state.aircraft_collision_bodies) == 0
			and int(state.aircraft_shadow)
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"the complete aircraft is one shadowless, collisionless draw")
	_check(int(state.audio_streams) == 2 and not bool(state.persistent),
			"two original mono sound events add no persistence seam")
	_check(layer.call("start_airmail_pass")
			and not layer.call("start_airmail_pass"),
			"one mail flight cannot overlap or duplicate itself")
	layer.call("_process", PeriodRealityScript.AIR_DURATION + 0.1)
	_check(not bool((layer.call("diagnostic_snapshot") as Dictionary).aircraft_visible),
			"the aircraft retires completely after crossing the block")
	_check(layer.call("trigger_train_pass")
			and not layer.call("trigger_train_pass"),
			"the distant rail event refuses an overlapping replay")
	var clear := {
		"cloud_low": 0.0, "precipitation_intensity": 0.0,
		"wind_speed_kmh": 18.0, "wind_direction_deg": 90.0,
		"weather_code": 0,
	}
	layer.call("set_live_conditions", clear)
	var clear_state: Dictionary = layer.call("diagnostic_snapshot")
	_check(float(clear_state.aircraft_contrast) == 1.0
			and (clear_state.wind_mps as Vector3).length() > 4.9,
			"clear weather preserves the silhouette and supplies observed crosswind")
	var storm := {
		"cloud_low": 1.0, "precipitation_intensity": 3.0,
		"wind_speed_kmh": 40.0, "wind_direction_deg": 220.0,
		"weather_code": 95,
	}
	layer.call("set_live_conditions", storm)
	var storm_state: Dictionary = layer.call("diagnostic_snapshot")
	_check(float(storm_state.aircraft_contrast) < 0.10
			and float(storm_state.air_filter_hz) < float(clear_state.air_filter_hz)
			and float(storm_state.train_filter_hz) < float(clear_state.train_filter_hz),
			"closed storm weather suppresses the flyby and muffles distant events")

	print("[PERIOD REALITY LAYER] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
