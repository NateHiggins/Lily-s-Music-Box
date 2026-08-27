extends Node
## ORISON-RR-F01-ARRIVAL — player-height spatial proof for the street threshold,
## lobby and first service-spine turn.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")

var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F01-ARRIVAL", 5):
		get_tree().quit(2)
		return
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	if not await shots.settle(1.8, "production_ready"):
		_finish(false)
		return
	player = root.get("player") as PlayerController
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.set_lamp_enabled(true)
	_hide_non_diegetic_overlays(root)
	if "sanity" in root and root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if "fourth_wall" in root and root.fourth_wall:
		root.fourth_wall.force_finish()
	if "switch_system" in root and root.switch_system:
		if not root.switch_system.toggle_room("F01_LOBBY"):
			root.switch_system.toggle_room("F01_LOBBY")
	await shots.settle(0.8, "lobby_lit")
	player.set_process(false)

	_look([0.00, -12.20, 1.62], [0.00, -9.90, 1.58], 72.0)
	await shots.capture("00_exterior_to_threshold")

	_look([-0.35, -9.22, 1.62], [0.20, -7.15, 1.45], 70.0)
	await shots.capture("01_threshold_to_lobby")

	_look([3.72, -7.88, 1.62], [5.18, -7.88, 1.38], 61.0)
	await shots.capture("02_mail_corner_working_face")

	_look([3.72, -6.00, 1.62], [5.18, -5.82, 1.42], 68.0)
	await shots.capture("03_service_wall_working_faces")

	_look([4.20, -9.10, 1.62], [5.10, -1.60, 1.50], 66.0)
	await shots.capture("04_first_service_spine_turn")
	_finish(true)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()


func _hide_non_diegetic_overlays(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = false
		elif child is Label3D and (child.name == "Nameplate"
				or node.is_in_group("resident_placeholders")):
			child.visible = false
		_hide_non_diegetic_overlays(child)


func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
