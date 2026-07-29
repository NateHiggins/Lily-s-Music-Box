class_name BoxFanProp
extends FunctionalProp
## Floor box fan. Normal: constant drone, blades spinning. Synced: motor
## speed wavers with the motif — pitch bends, never stops dead.

var _hum: AudioStreamPlayer3D
var _blades: MeshInstance3D
var _speed := 18.0


func _build_visual() -> void:
	## Mid-century floor fan: ring shroud, four real blades on a hub,
	## radial wire guard, cradle feet and a fat speed switch.
	var steel := Color(0.55, 0.57, 0.58)
	var ring := make_ring(0.225, 0.020, Vector3(0, 0.27, 0), steel,
			0.30, 0.8)
	ring.rotation_degrees = Vector3(90, 0, 0)
	make_cyl(0.035, 0.055, 0.12, Vector3(0, 0.27, -0.05),
			Color(0.30, 0.31, 0.33), 0.4, 0.5)           # motor can
	_blades = MeshInstance3D.new()
	_blades.position = Vector3(0, 0.27, 0.02)
	add_child(_blades)
	for i in 4:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.075, 0.185, 0.008)
		blade.mesh = bm
		blade.position = Vector3(0, 0.115, 0).rotated(Vector3.FORWARD,
				TAU * i / 4.0)
		blade.rotation_degrees = Vector3(0, 14, i * 90.0)
		blade.material_override = _pmat(Color(0.72, 0.73, 0.70), 0.35, 0.6)
		_blades.add_child(blade)
	make_cyl(0.030, 0.030, 0.03, Vector3(0, 0.27, 0.045),
			Color(0.62, 0.55, 0.30), 0.3, 0.7)           # hub nut
	for i in 6:
		var wire := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.44, 0.004, 0.004)
		wire.mesh = wm
		wire.position = Vector3(0, 0.27, 0.075)
		wire.rotation_degrees = Vector3(0, 0, i * 30.0)
		wire.material_override = _pmat(steel, 0.3, 0.7)
		add_child(wire)
	for fx in [-0.16, 0.16]:
		make_cyl(0.014, 0.014, 0.24, Vector3(fx, 0.012, 0),
				Color(0.30, 0.31, 0.33), 0.4, 0.5).rotation_degrees = \
				Vector3(90, 0, 0)
	make_box(Vector3(0.05, 0.035, 0.06), Vector3(0.10, 0.045, -0.10),
			Color(0.16, 0.12, 0.10))                     # speed switch
	_hum = make_emitter("buzz_loop", -24.0, true)
	_hum.pitch_scale = 0.6


func _start_normal_function() -> void:
	state = PState.OPERATING


func _process(delta: float) -> void:
	_blades.rotate_object_local(Vector3.UP, _speed * delta)
	_speed = lerpf(_speed, 18.0, delta * 0.8)
	_hum.pitch_scale = lerpf(_hum.pitch_scale, 0.6 + (_speed - 18.0) * 0.02,
			delta * 4.0)


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_speed = 18.0 + accent * 9.0 * signf(pitch + 0.5)
