class_name BoxFanProp
extends FunctionalProp
## Floor box fan. Normal: constant drone, blades spinning. Synced: motor
## speed wavers with the motif — pitch bends, never stops dead.

var _hum: AudioStreamPlayer3D
var _blades: MeshInstance3D
var _speed := 18.0


func _build_visual() -> void:
	make_box(Vector3(0.5, 0.5, 0.12), Vector3(0, 0.25, 0),
			Color(0.25, 0.26, 0.28))
	_blades = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.19
	cyl.bottom_radius = 0.19
	cyl.height = 0.03
	_blades.mesh = cyl
	_blades.rotation_degrees = Vector3(90, 0, 0)
	_blades.position = Vector3(0, 0.25, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blades.material_override = mat
	add_child(_blades)
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
