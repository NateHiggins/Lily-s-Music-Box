extends Node
## ORISON-V2-M08 — concise human route-readability evidence packet.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const REVIEW := preload("res://scenes/building/orison_v2_integrated_review.tscn")

var shots = ShotHarnessScript.new()
var camera: Camera3D

func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M08A", 10):
		get_tree().quit(2)
		return
	var review = REVIEW.instantiate()
	var blockout = review.get_node("Blockout")
	blockout.show_ceilings = false
	blockout.show_clearance_anchors = false
	review.get_node("Player").queue_free()
	add_child(review)
	_build_world()
	_hide_overlays(blockout)
	await shots.settle(0.8, "readability_cues_ready")
	await _shot("00_exterior_public_entrance", Vector3(0, 1.41, -14.0), Vector3(0, 1.25, -11.65))
	await _shot("01_lobby_upward_decision", Vector3(0, 1.41, -7.2), Vector3(2.25, 1.45, -2.4))
	await _shot("02_stair_entry_ascending_flight", Vector3(1.35, 1.41, -3.45), Vector3(2.3, 2.2, -0.7))
	await _shot("03_intermediate_landing_turn", Vector3(2.3, 3.01, 0.55), Vector3(3.8, 2.85, -0.5))
	await _shot("04_f02_arrival_2a_threshold", Vector3(-3.4, 4.61, 0), Vector3(-5.6, 4.35, 0))
	await _shot("05_2a_exit_primary_core_return", Vector3(-6.45, 4.61, 0), Vector3(-1.2, 4.35, -2.7))
	await _shot("06_f04_arrival_4b_threshold", Vector3(-3.4, 11.01, 0), Vector3(-5.6, 10.75, 0))
	await _shot("07_4b_entry_work_home", Vector3(-7.45, 11.01, 1.15), Vector3(-9.05, 10.45, 1.25))
	await _shot("08_unobstructed_terminal_context", Vector3(-9.9, 11.01, 1.25), Vector3(-9.05, 10.35, 1.25))
	await _shot("09_bedside_home_exit_direction", Vector3(-14.0, 11.01, 7.3), Vector3(-11.7, 10.38, 8.0), 90.0)
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

func _shot(label: String, from: Vector3, at: Vector3, fov := 72.0) -> void:
	camera.global_position = from
	camera.fov = fov
	camera.look_at(at, Vector3.UP)
	await shots.capture(label)

func _hide_overlays(blockout: Node3D) -> void:
	for envelope: Dictionary in blockout.layout.get("envelopes", []):
		var node := blockout.get_node_or_null(str(envelope.id)) as Node3D
		if node != null:
			node.visible = false
	for anchor: Dictionary in blockout.layout.get("anchors", []):
		var overlay := blockout.get_node_or_null("%s/Envelope" % str(anchor.id)) as Node3D
		if overlay != null:
			overlay.visible = false
