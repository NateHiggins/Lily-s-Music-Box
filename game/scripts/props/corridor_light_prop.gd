class_name CorridorLightProp
extends FunctionalProp
## Dirty fluorescent corridor fixture. Normal: steady light, faint starter
## buzz, very rare flutter. Synced: brightness dips riding motif accents.

var _light: OmniLight3D
var _base_energy := 1.6


func _build_visual() -> void:
	## Enamel batten fixture: channel spine, exposed tube on end caps,
	## starter can and a hanging pull chain — corridor hardware with age.
	make_box(Vector3(1.1, 0.06, 0.14), Vector3(0, -0.03, 0),
			Color(0.80, 0.80, 0.78))
	var tube := make_cyl(0.019, 0.019, 0.90, Vector3.ZERO,
			Color(0.93, 0.95, 0.90), 0.2)
	tube.position = Vector3(0, -0.085, 0)
	tube.rotation_degrees = Vector3(0, 0, 90)
	for ex in [-0.47, 0.47]:
		make_box(Vector3(0.05, 0.075, 0.075), Vector3(ex, -0.075, 0),
				Color(0.55, 0.56, 0.55))
	make_cyl(0.016, 0.016, 0.05, Vector3(0.30, -0.045, 0.055),
			Color(0.72, 0.72, 0.70), 0.4, 0.3)           # starter can
	make_cyl(0.003, 0.003, 0.16, Vector3(-0.40, -0.16, 0.05),
			Color(0.60, 0.60, 0.62), 0.3, 0.6)           # pull chain
	retexture(self, [
		[Color(0.80, 0.80, 0.78), "enamel", Color.WHITE],
		[Color(0.55, 0.56, 0.55), "metal", Color(0.7, 0.7, 0.7)],
		[Color(0.72, 0.72, 0.70), "metal", Color.WHITE],
		[Color(0.60, 0.60, 0.62), "chrome", Color.WHITE],
	])
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
