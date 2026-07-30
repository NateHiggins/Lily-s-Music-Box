class_name LampProp
extends FunctionalProp
## The 4B desk lamp: warm pool of light over the workstation. Normal:
## steady. Synced: filament surges tracing motif accents.

var _light: OmniLight3D
var _base_energy := 1.1


func _build_visual() -> void:
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
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.82, 0.55)  # ~2700 K
	_light.light_energy = _base_energy
	_light.omni_range = 4.5
	_light.position = Vector3(0.07, 0.42, 0)
	add_child(_light)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_light.light_energy = _base_energy * (1.0 + accent * 0.9)
	create_tween().tween_property(_light, "light_energy", _base_energy, 0.25)
