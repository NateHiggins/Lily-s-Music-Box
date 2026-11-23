extends Node
## Headless bench for the celestial key's shadow gate: off below the dim
## threshold, back on above the bright one, steady in between, and always on
## when the gate is switched off.

var failures := 0
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("KEY GATE CHECK: ", label, " = ", ok)


func _run() -> void:
	var director := DayNightDirector.new()
	var key := DirectionalLight3D.new()
	key.shadow_enabled = true
	add_child(key)
	director._sky_key = key
	var at := func(energy: float) -> bool:
		key.light_energy = energy
		director._gate_key_shadow()
		return key.shadow_enabled
	check(at.call(0.21), "a clear noon keeps the shadow")
	check(at.call(0.12), "between the thresholds a lit shadow stays lit")
	check(not at.call(0.052), "moonlight drops the shadow")
	check(not at.call(0.12), "between the thresholds a dropped shadow stays dropped")
	check(at.call(0.14), "brightening past the upper threshold brings it back")
	director.key_shadow_gate = false
	check(at.call(0.01), "with the gate off the shadow is always on")
	director.free()
	key.queue_free()
	await get_tree().process_frame
	print("KEY GATE RESULT: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
