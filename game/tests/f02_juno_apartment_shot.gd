extends Node
## ORISON-RR-F02-JUNO — 2C home studio and converted recording room.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F02-JUNO", 8):
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
	player.pin_lamp_gutter_for_proof(1.0)
	_hide_overlays(root)
	if "sanity" in root and root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if "fourth_wall" in root and root.fourth_wall:
		root.fourth_wall.force_finish()
	if "switch_system" in root and root.switch_system:
		for room_id in ["F02_C_MAIN", "F02_C_BED1", "F02_C_BED2", "F02_C_BATH"]:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	for door_id in ["F02_DOOR_05", "F02_DOOR_10", "F02_DOOR_11", "F02_DOOR_12"]:
		var door := root.find_child(door_id, true, false)
		if door != null and door.has_method("npc_set_open"):
			door.call("npc_set_open", true)
	await shots.settle(1.0, "f02_juno_lit_open")

	_look([4.20, -0.14, 4.82], [8.10, 0.40, 4.30], 74.0)
	await shots.capture("00_entry_to_2c")
	_look([6.70, 0.10, 4.82], [9.50, 3.80, 4.25], 74.0)
	await shots.capture("01_main_studio_wide")
	_look([8.20, 1.30, 4.82], [5.95, 2.35, 4.25], 70.0)
	await shots.capture("02_kitchen_tape_shelf")
	_look([8.40, 2.20, 4.82], [11.65, 4.25, 4.15], 72.0)
	await shots.capture("03_recording_rig")
	_look([6.70, 5.55, 4.82], [7.55, 8.25, 4.15], 68.0)
	await shots.capture("04_only_bedroom")
	_look([11.65, 5.50, 4.82], [11.70, 8.20, 4.20], 70.0)
	await shots.capture("05_recording_room_threshold")
	_look([11.70, 6.85, 4.82], [11.55, 8.75, 4.10], 74.0)
	await shots.capture("06_recording_room_archive")
	_look([8.45, 4.60, 4.82], [6.05, 5.05, 4.12], 68.0)
	await shots.capture("07_bath_from_main")
	_finish(true)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()


func _hide_overlays(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer or child is Label3D:
			child.visible = false
		_hide_overlays(child)


func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
