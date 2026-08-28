extends Node
## ORISON-RR-F02-SERVICE — shared corridor, plant rooms and atrium proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F02-SERVICE", 7):
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
	_hide_overlays(root)
	if "sanity" in root and root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if "fourth_wall" in root and root.fourth_wall:
		root.fourth_wall.force_finish()
	for room_id in ["F02_CORRIDOR", "F02_WSTOR", "F02_UTILITY", "F02_HALL", "F02_ATRIUM"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	var plant_door := root.find_child("F02_DOOR_04", true, false)
	if plant_door != null and plant_door.has_method("npc_set_open"):
		plant_door.call("npc_set_open", true)
	await shots.settle(1.0, "service_spine_lit_open")
	player.set_process(false)

	_look([-4.10, 5.80, 4.82], [-4.20, -4.80, 4.30], 72.0)
	await shots.capture("00_corridor_southbound")
	_look([4.10, -5.80, 4.82], [4.20, 4.80, 4.30], 72.0)
	await shots.capture("01_corridor_northbound")
	_look([-4.25, 0.65, 4.82], [-6.60, 0.95, 4.20], 70.0)
	await shots.capture("02_wstor_open_leaf")
	_look([-6.25, 0.70, 4.82], [-11.80, 1.20, 4.15], 74.0)
	await shots.capture("03_wstor_interior")
	_look([-1.85, 3.65, 4.82], [1.85, 5.40, 4.35], 72.0)
	await shots.capture("04_utility_from_door")
	_look([-2.80, -6.10, 4.82], [2.50, -4.55, 4.45], 72.0)
	await shots.capture("05_hall_lift_approach")
	_look([-2.70, -2.70, 4.82], [2.00, 1.20, 4.30], 76.0)
	await shots.capture("06_atrium_from_southwest")
	_finish(true)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()


func _hide_overlays(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = false
		elif child is Label3D:
			child.visible = false
		_hide_overlays(child)


func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
