class_name CeilingLightProp
extends FunctionalProp
## The main room's ceiling bowl fixture: warm, steady, and — when the
## conductor asks — surging with the accents like the desk lamp's louder
## sibling.

var light: OmniLight3D
var bounce: OmniLight3D
var _base_energy := 1.3
var _target_scale := 1.0
var _surge := 0.0


func _build_visual() -> void:
	make_box(Vector3(0.30, 0.10, 0.30), Vector3(0, -0.05, 0),
			Color(0.95, 0.93, 0.85))
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.62)
	light.light_energy = 0.0
	light.omni_range = 6.5
	light.omni_attenuation = 1.6
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_bias = 0.035
	light.shadow_normal_bias = 0.42
	light.shadow_opacity = 0.82
	light.light_size = 0.12
	light.position = Vector3(0, -0.2, 0)
	add_child(light)
	add_to_group("light_fixtures")


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_surge = maxf(_surge, accent * 0.8)


func set_budget(scale: float, _with_bounce: bool, with_shadow: bool) -> void:
	_target_scale = scale
	light.shadow_enabled = with_shadow


func _process(delta: float) -> void:
	if light == null:
		return
	var want := _base_energy * _target_scale * (1.0 + _surge)
	light.light_energy = lerpf(light.light_energy, want, delta * 6.0)
	_surge = maxf(0.0, _surge - delta * 2.2)
