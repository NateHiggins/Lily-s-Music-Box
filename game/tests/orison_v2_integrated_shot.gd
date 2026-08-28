extends Node
## ORISON-V2-M08 — concise human route-readability evidence packet.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const BLOCKOUT := preload("res://scenes/building/orison_v2_blockout.tscn")

var shots = ShotHarnessScript.new()
var camera: Camera3D

func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M08", 8):
		get_tree().quit(2)
		return
	var blockout = BLOCKOUT.instantiate()
	blockout.show_ceilings = false
	add_child(blockout)
	_build_world()
	await shots.settle(0.8, "integrated_blockout_ready")
	await _shot("00_street_entrance", Vector3(0, 1.41, -14.0), Vector3(0, 1.2, -5.0))
	await _shot("01_lobby_route_choice", Vector3(0, 1.41, -5.3), Vector3(2.3, 1.3, -2.7))
	await _shot("02_upward_transition", Vector3(2.3, 1.41, -2.8), Vector3(2.3, 2.3, -0.2))
	await _shot("03_f02_landing_2a_threshold", Vector3(-1.5, 4.61, 0), Vector3(-6.5, 4.3, 0))
	await _shot("04_return_to_core", Vector3(-6.1, 4.61, 0), Vector3(1.8, 4.4, -2.7))
	await _shot("05_f04_landing_4b_threshold", Vector3(-1.5, 11.01, 0), Vector3(-6.5, 10.7, -0.4))
	await _shot("06_terminal_home_context", Vector3(-9.9, 11.01, 1.25), Vector3(-9.0, 10.65, 1.25))
	await _shot("07_bedside_exit_direction", Vector3(-11.95, 11.01, 8.9), Vector3(-10.4, 10.5, 6.3))
	get_tree().quit(0 if shots.finish() else 2)

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.064, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.77, 0.82)
	env.ambient_light_energy = 0.75
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72
	add_child(camera)

func _shot(label: String, from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	await shots.capture(label)
