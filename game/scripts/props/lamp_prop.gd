class_name LampProp
extends FunctionalProp
## The 4B desk lamp: warm pool of light over the workstation. Normal:
## steady. Synced: filament surges tracing motif accents.

var light: OmniLight3D
var _base_energy := 1.1
var _target_scale := 1.0
var _phase := 0.0
var _drift_depth := 0.015
var _drift_speed := 0.71


func _build_visual() -> void:
	var seed := absi(str(name).hash())
	_phase = float(seed & 4095) * 0.013
	_base_energy *= lerpf(0.82, 1.12,
			float((seed >> 8) & 1023) / 1023.0)
	_drift_depth = lerpf(0.006, 0.025,
			float((seed >> 18) & 255) / 255.0)
	## Articulated task lamp: stepped weighted base, two sprung arms at
	## working angles, spun-steel dome shade tipped toward the desk.
	var paint := Color(0.15, 0.16, 0.14)
	make_cyl(0.075, 0.085, 0.02, Vector3(0, 0.01, 0), paint, 0.35)
	make_cyl(0.055, 0.070, 0.02, Vector3(0, 0.03, 0), paint, 0.35)
	var arm1 := make_cyl(0.007, 0.007, 0.26, Vector3.ZERO, paint, 0.3, 0.3)
	arm1.position = Vector3(0.055, 0.15, 0)
	arm1.rotation_degrees = Vector3(0, 0, -28)
	var elbow := make_cyl(0.014, 0.014, 0.03, Vector3(0.115, 0.265, 0),
			paint, 0.3, 0.3)
	elbow.rotation_degrees = Vector3(90, 0, 0)
	var arm2 := make_cyl(0.007, 0.007, 0.24, Vector3.ZERO, paint, 0.3, 0.3)
	arm2.position = Vector3(0.065, 0.36, 0)
	arm2.rotation_degrees = Vector3(0, 0, 26)
	var shade := make_cyl(0.028, 0.085, 0.13, Vector3(0.03, 0.475, 0),
			paint, 0.30, 0.2)
	shade.rotation_degrees = Vector3(0, 0, 132)
	make_cyl(0.020, 0.020, 0.012, Vector3(0.065, 0.445, 0),
			Color(1.0, 0.9, 0.7), 0.2)                   # the bulb glow
	retexture(self, [
		[Color(0.15, 0.16, 0.14), "enamel", Color(0.34, 0.37, 0.32), 0.4],
	])
	light = OmniLight3D.new()
	var base := Color(1.0, 0.82, 0.55)
	var hue := (float((seed >> 4) & 255) / 255.0 - 0.5) * 0.035
	light.light_color = Color.from_hsv(
			fposmod(base.h + hue, 1.0), base.s, base.v)
	light.light_energy = _base_energy
	light.omni_range = 4.5
	light.position = Vector3(0.07, 0.42, 0)
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.shadow_bias = 0.012
	light.shadow_normal_bias = 0.08
	add_child(light)
	add_to_group("floor_lights")
	set_meta("light_personality", {
		"tone": light.light_color, "gain": _base_energy / 1.1,
		"flicker_profile": 1, "flicker_depth": _drift_depth,
		"flicker_speed": 0.71,
	})


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if _target_scale <= 0.0:
		return
	light.light_energy = _base_energy * (1.0 + accent * 0.9)
	create_tween().tween_property(light, "light_energy", _base_energy, 0.25)


func set_budget(scale: float, _with_bounce: bool, with_shadow: bool) -> void:
	_target_scale = scale
	light.visible = scale > 0.001
	light.shadow_enabled = with_shadow
	light.light_energy = _base_energy * scale


func _process(_delta: float) -> void:
	if light == null or _target_scale <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001 + _phase
	var filament := 1.0 + sin(t * _drift_speed) * _drift_depth \
			+ sin(t * _drift_speed * 3.0) * _drift_depth * 0.35
	light.light_energy = _base_energy * _target_scale * filament
