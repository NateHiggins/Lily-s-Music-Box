class_name CeilingLightProp
extends FunctionalProp
## The main room's ceiling bowl fixture: warm, steady, and — when the
## conductor asks — surging with the accents like the desk lamp's louder
## sibling.

var light: OmniLight3D
var bounce: OmniLight3D
var _base_energy := 1.8
var _target_scale := 1.0
var _surge := 0.0
var _phase := 0.0
var _drift_depth := 0.012
var standby_scale := 0.0
var navigation_light := false


func _build_visual() -> void:
	var seed := absi(str(name).hash())
	_phase = float(seed & 4095) * 0.019
	_base_energy *= lerpf(0.82, 1.12,
			float((seed >> 9) & 1023) / 1023.0)
	_drift_depth = lerpf(0.006, 0.025,
			float((seed >> 19) & 255) / 255.0)
	var housing := make_box(Vector3(0.30, 0.10, 0.30),
			Vector3(0, -0.05, 0), Color(0.95, 0.93, 0.85))
	# The source sits inside this shallow housing. Letting the housing enter
	# its own cubemap projects a ceiling-sized rectangular self-shadow.
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light = OmniLight3D.new()
	var base_tone := Color(1.0, 0.86, 0.62)
	var hue_shift := (float((seed >> 5) & 255) / 255.0 - 0.5) * 0.04
	light.light_color = Color.from_hsv(
			fposmod(base_tone.h + hue_shift, 1.0),
			base_tone.s, base_tone.v)
	light.light_energy = 0.0
	light.omni_range = 6.5
	light.omni_attenuation = 2.25
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_bias = 0.012
	light.shadow_normal_bias = 0.08
	light.shadow_opacity = 1.0
	light.light_size = 0.12
	light.position = Vector3(0, -0.2, 0)
	add_child(light)
	add_to_group("light_fixtures")
	set_meta("light_personality", {
		"tone": light.light_color, "gain": _base_energy / 1.8,
		"flicker_profile": 3, "flicker_depth": _drift_depth,
		"flicker_speed": 0.83,
	})


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_surge = maxf(_surge, accent * 0.8)


func set_budget(scale: float, _with_bounce: bool, with_shadow: bool) -> void:
	_target_scale = scale
	light.visible = scale > 0.001
	light.shadow_enabled = with_shadow


func _process(delta: float) -> void:
	if light == null:
		return
	var t := Time.get_ticks_msec() * 0.001 + _phase
	var individual := 1.0 + sin(t * 0.83) * _drift_depth \
			+ sin(t * 2.41) * _drift_depth * 0.32
	var want := _base_energy * _target_scale * (1.0 + _surge) * individual
	light.light_energy = lerpf(light.light_energy, want, delta * 6.0)
	_surge = maxf(0.0, _surge - delta * 2.2)
