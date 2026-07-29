class_name CeilingLightProp
extends FunctionalProp
## The main room's ceiling bowl fixture: warm, steady, and — when the
## conductor asks — surging with the accents like the desk lamp's louder
## sibling.

var _light: OmniLight3D
var _base := 1.3


func _build_visual() -> void:
	make_box(Vector3(0.30, 0.10, 0.30), Vector3(0, -0.05, 0),
			Color(0.95, 0.93, 0.85))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.86, 0.62)
	_light.light_energy = _base
	_light.omni_range = 6.5
	_light.position = Vector3(0, -0.2, 0)
	add_child(_light)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_light.light_energy = _base * (1.0 + accent * 0.8)
	create_tween().tween_property(_light, "light_energy", _base, 0.22)
