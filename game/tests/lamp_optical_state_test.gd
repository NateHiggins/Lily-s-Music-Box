extends Node

const LampState=preload("res://scripts/lamp/lamp_optical_state.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	print("[LAMP OPTICS L1] START")
	var a=LampState.new()
	var b=LampState.new()
	a.configure(1928, true)
	b.configure(1928, true)
	for i in 1800:
		var shock := 0.72 if i == 820 else 0.0
		a.advance(1.0 / 120.0, 110.0, shock)
		b.advance(1.0 / 120.0, 110.0, shock)
	_check("same seed and input reproduce electrical state",
			is_equal_approx(a.filament_temperature_k, b.filament_temperature_k)
			and is_equal_approx(a.contact_resistance, b.contact_resistance))
	var saved:Dictionary=a.save_state().duplicate(true)
	var restored=LampState.new()
	_check("warm/flicker state restores", restored.restore_state(saved))
	for i in 480:
		a.advance(1.0 / 120.0)
		restored.advance(1.0 / 120.0)
	_check("restored future remains deterministic",
			is_equal_approx(a.filament_temperature_k, restored.filament_temperature_k)
			and is_equal_approx(float(a.output().intensity),
					float(restored.output().intensity)))
	a.switched_on = false
	for i in 600:
		a.advance(1.0 / 120.0)
	_check("cool-down reaches darkness", float(a.output().intensity) < 0.01)
	var observation:Dictionary=restored.observation(Vector3.ZERO, Vector3.FORWARD, 0.35)
	_check("ecology contract is observation-only",
			observation.has("incident_intensity")
			and observation.has("temporal_stability")
			and observation.has("occlusion_confidence")
			and not observation.has("command"))
	_check("rapid contrast floor is bounded",
			LampState.RAPID_CONTRAST_FLOOR >= 0.60)
	print("[LAMP OPTICS L1] %s %d/6" % [
			"PASS" if failures == 0 and checks == 6 else "FAIL", checks])
	get_tree().quit(0 if failures == 0 and checks == 6 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[LAMP OPTICS L1] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
