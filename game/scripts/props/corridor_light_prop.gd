class_name CorridorLightProp
extends FunctionalProp
## Dirty fluorescent corridor fixture. Normal: steady light, faint starter
## buzz, very rare flutter. Synced: brightness dips riding motif accents.

var _light: OmniLight3D
var _base_energy := 1.6


func _build_visual() -> void:
	make_box(Vector3(1.1, 0.08, 0.18), Vector3(0, -0.05, 0), Color(0.8, 0.8, 0.78))
	_light = OmniLight3D.new()
	_light.light_color = Color(0.9, 0.93, 0.86)
	_light.light_energy = _base_energy
	_light.omni_range = 7.0
	_light.position = Vector3(0, -0.2, 0)
	add_child(_light)
	make_emitter("buzz_loop", -26.0, true)


func _start_normal_function() -> void:
	state = PState.OPERATING
	_normal_flutter_loop()


func _normal_flutter_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(20.0, 45.0), false).timeout
		if is_inside_tree() and state == PState.OPERATING:
			_dip(0.5, 0.08)


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_dip(1.0 - accent * 0.7, 0.05 + accent * 0.06)


func _dip(level: float, dur: float) -> void:
	_light.light_energy = _base_energy * clampf(level, 0.1, 1.0)
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(_light, "light_energy", _base_energy, 0.12)
