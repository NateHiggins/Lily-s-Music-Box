extends Node3D
## Standalone entry into the same warehouse exhibit used by the F1 button.
## No campaign save is loaded or written by this debug scene.

func _ready() -> void:
	RealityState.persistence_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var world := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.055,0.06,0.075)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.75,0.82,1.0)
	settings.ambient_light_energy = 0.45
	world.environment = settings
	add_child(world)
	var exhibit := DreamEcologyWarehouse.new()
	exhibit.position = PropWarehouse.ORIGIN
	add_child(exhibit)
	exhibit.setup()
	exhibit.activate()
	exhibit.inspection_changed.connect(func(is_active: bool):
		if not is_active: get_tree().quit())

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_services"): get_tree().quit()
