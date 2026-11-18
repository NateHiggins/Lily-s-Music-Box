extends LightFixtureProp
## Venue-local optics; the original fixture still owns circuit, hours and flicker.
## A shaded practical uses one shadow cone rather than a six-face shadow cube.
var optics: Dictionary = {}
var pool: SpotLight3D
var _unshaded_energy := 0.0

func _build_visual() -> void:
	super._build_visual()
	if optics.has("tone"):
		var rgb: Array = optics.tone
		light.light_color = Color(rgb[0], rgb[1], rgb[2])
		_bulb_mat.emission = light.light_color
	if not optics.has("target"): return
	pool = SpotLight3D.new()
	pool.name = "ShadedPool"
	pool.position = light.position
	pool.light_color = light.light_color
	pool.light_energy = 0.0
	pool.spot_range = float(optics.get("range", range_clamp))
	pool.spot_angle = float(optics.get("angle", 65.0))
	pool.spot_angle_attenuation = 1.2
	pool.spot_attenuation = 1.3
	pool.shadow_bias = light.shadow_bias
	pool.shadow_normal_bias = light.shadow_normal_bias
	pool.light_size = 0.14
	_swing_node.add_child(pool)
	# Source coordinates belong to the same actor frame as the retained marker.
	pool.look_at(get_parent().to_global(GameBoot.b2g(optics.target)), Vector3.FORWARD)
	light.shadow_enabled = false

func set_budget(scale: float, with_bounce: bool, with_shadow: bool) -> void:
	super.set_budget(scale, with_bounce, with_shadow and pool == null)
	if pool != null:
		pool.visible = light.visible
		pool.shadow_enabled = with_shadow and powered and scale > 0.001

func _process(delta: float) -> void:
	if pool != null: light.light_energy = _unshaded_energy
	super._process(delta)
	if pool != null:
		_unshaded_energy = light.light_energy
		# Existing live rig controls remain useful for the actual useful beam.
		pool.spot_range = light.omni_range
		pool.spot_attenuation = light.omni_attenuation
		pool.light_color = light.light_color
		pool.light_size = light.light_size
		pool.shadow_opacity = light.shadow_opacity
		pool.light_energy = _unshaded_energy * float(optics.get("beam_gain", 1.0))
		light.light_energy = _unshaded_energy * float(optics.get("spill", 0.12))
