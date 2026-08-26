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

	print("[PERIOD REALITY LAYER] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
