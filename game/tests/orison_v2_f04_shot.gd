extends Node
## ORISON-V2-M07 — development-only F04/4B gray-box evidence.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const BLOCKOUT := preload("res://scenes/building/orison_v2_blockout.tscn")

var shots = ShotHarnessScript.new()
var camera: Camera3D

func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M07", 7):
		get_tree().quit(2)
		return
	var blockout = BLOCKOUT.instantiate()
	blockout.show_ceilings = false
	add_child(blockout)
	_build_review_world()
	if not await shots.settle(0.8, "f04_blockout_ready"):
		_finish(false)
		return
	_top_down()
	await shots.capture("00_f04_4b_top_down")
	_hide_semantic_overlays(blockout)
	_look(Vector3(-1.5, 11.01, 0.0), Vector3(-5.6, 10.65, 0.0), 72.0)
	await shots.capture("01_landing_to_4b")
	_look(Vector3(-4.6, 11.01, 0.0), Vector3(-7.4, 10.75, 0.0), 72.0)
	await shots.capture("02_corridor_threshold")
	_look(Vector3(-6.45, 11.01, -0.55), Vector3(-10.0, 10.75, 0.8), 74.0)
	await shots.capture("03_vestibule_main_work")
	_look(Vector3(-9.9, 11.01, 1.25), Vector3(-9.05, 10.65, 1.25), 68.0)
	await shots.capture("04_terminal_stance")
	_look(Vector3(-12.6, 11.01, 5.15), Vector3(-14.2, 10.75, 6.0), 72.0)
	await shots.capture("05_kitchen_aisle")
	_look(Vector3(-11.95, 11.01, 8.9), Vector3(-13.1, 10.5, 8.9), 70.0)
	await shots.capture("06_bedside_return")
	_finish(true)

func _build_review_world() -> void:
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
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

func _look(from: Vector3, at: Vector3, fov: float) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	camera.global_position = from
	camera.look_at(at, Vector3.UP)

func _top_down() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.global_position = Vector3(-8.0, 24.0, 3.8)
	camera.look_at(Vector3(-8.0, 9.6, 3.8), Vector3.FORWARD)

func _hide_semantic_overlays(blockout: Node3D) -> void:
	for envelope: Dictionary in blockout.layout.get("envelopes", []):
		var node := blockout.get_node_or_null(str(envelope.id)) as Node3D
		if node != null:
			node.visible = false
	for anchor: Dictionary in blockout.layout.get("anchors", []):
		var envelope := blockout.get_node_or_null("%s/Envelope" % str(anchor.id)) as Node3D
		if envelope != null:
			envelope.visible = false

func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
