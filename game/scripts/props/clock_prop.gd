class_name ClockProp
extends FunctionalProp
## Analog wall clock. Normal: honest one-second tick. As infection rises
## the tick interval slides toward the conductor's beat — the apartment's
## own time quietly re-tuning itself. It never announces the change; the
## player just eventually notices the clock agreeing with the radiator.

var interval := 1.0

var _tick: AudioStreamPlayer3D
var _acc := 0.0


func _build_visual() -> void:
	var face := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = 0.035
	face.mesh = cyl
	face.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.90, 0.85)
	face.material_override = mat
	add_child(face)
	make_box(Vector3(0.02, 0.10, 0.012), Vector3(0, 0.045, 0.02),
			Color(0.1, 0.1, 0.1))   # minute hand
	make_box(Vector3(0.06, 0.02, 0.012), Vector3(0.025, 0, 0.02),
			Color(0.1, 0.1, 0.1))   # hour hand
	_tick = make_emitter("tick", -26.0)
	_tick.max_distance = 8.0


func _start_normal_function() -> void:
	state = PState.OPERATING


func _process(delta: float) -> void:
	# time keeps time — until the building offers a better tempo
	var target := 1.0 if Conductor.infection < 0.4 else 60.0 / Conductor.bpm
	interval = lerpf(interval, target, delta * 0.05)
	_acc += delta
	if _acc >= interval:
		_acc = fmod(_acc, interval)
		_tick.pitch_scale = 1.0 if int(Time.get_ticks_msec() / 1000.0) % 2 == 0 \
				else 1.06
		_tick.play()


func _perform_synced_event(_index: int, _accent: float, _pitch: float) -> void:
	pass  # the clock's corruption is its drift, not an accent response
