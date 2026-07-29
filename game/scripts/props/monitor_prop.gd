class_name MonitorProp
extends FunctionalProp
## The 4B workstation's two monitors. Normal: steady pale glow. Synced:
## brightness flickers tracing the motif; at high infection the color
## temperature slides toward the interface teal.

var _screen_mats: Array[StandardMaterial3D] = []


func _build_visual() -> void:
	for i in 2:
		var off := Vector3(0, 0.24, -0.19 + i * 0.38)
		make_box(Vector3(0.03, 0.34, 0.55), off, Color(0.1, 0.1, 0.11))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.06, 0.07)
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.62, 0.66)
		mat.emission_energy_multiplier = 0.7
		var screen := make_box(Vector3(0.005, 0.30, 0.51),
				off + Vector3(0.018, 0, 0), Color.BLACK)
		screen.material_override = mat
		_screen_mats.append(mat)
		# fork stand, cable drop and a power pip: desk hardware, not a slab
		make_cyl(0.022, 0.030, 0.055, off + Vector3(0, -0.265, 0),
				Color(0.14, 0.14, 0.15), 0.4, 0.3)
		make_box(Vector3(0.05, 0.16, 0.035),
				off + Vector3(-0.005, -0.16, 0), Color(0.12, 0.12, 0.13))
		make_cyl(0.004, 0.004, 0.20, off + Vector3(-0.04, -0.20, 0.10),
				Color(0.08, 0.08, 0.08), 0.5)
		make_box(Vector3(0.006, 0.008, 0.008),
				off + Vector3(0.017, -0.145, 0.22), Color(0.3, 0.9, 0.5))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.68, 0.72)
	light.light_energy = 0.5
	light.omni_range = 2.2
	light.position = Vector3(0.3, 0.3, 0)
	add_child(light)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	for mat in _screen_mats:
		mat.emission_energy_multiplier = 0.7 + accent * 1.1
		if Conductor.infection > 0.7:
			mat.emission = Color(0.34, 0.9, 0.83)  # the interface teal
		create_tween().tween_property(mat, "emission_energy_multiplier",
				0.7, 0.2)
