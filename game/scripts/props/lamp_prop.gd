class_name LampProp
extends FunctionalProp
## The 4B desk lamp: warm pool of light over the workstation. Normal:
## steady. Synced: filament surges tracing motif accents.

var _light: OmniLight3D
var _base_energy := 1.1


func _build_visual() -> void:
	make_box(Vector3(0.17, 0.02, 0.17), Vector3(0, 0.01, 0), Color(0.14, 0.12, 0.10))
	make_box(Vector3(0.03, 0.35, 0.03), Vector3(0, 0.19, 0), Color(0.2, 0.17, 0.14))
	make_box(Vector3(0.15, 0.10, 0.15), Vector3(0.06, 0.40, 0), Color(0.24, 0.2, 0.16))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.82, 0.55)  # ~2700 K
	_light.light_energy = _base_energy
	_light.omni_range = 4.5
	_light.position = Vector3(0.06, 0.36, 0)
	add_child(_light)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_light.light_energy = _base_energy * (1.0 + accent * 0.9)
	create_tween().tween_property(_light, "light_energy", _base_energy, 0.25)
