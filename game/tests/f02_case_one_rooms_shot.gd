extends Node
## ORISON-RR-F02-CASE-ONE — 2A route, stations and door-clearance proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F02-CASE-ONE", 7):
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
	for room_id in ["F02_CORRIDOR", "F02_A_MAIN", "F02_A_BED", "F02_A_BATH"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	for door_id in ["F02_DOOR_02", "F02_DOOR_07", "F02_DOOR_08"]:
		var route_door := root.find_child(door_id, true, false)
		if route_door != null and route_door.has_method("npc_set_open"):
			route_door.call("npc_set_open", true)
	await shots.settle(1.0, "case_one_lit_open")
	player.set_process(false)

	_look([-4.05, -1.65, 4.82], [-6.40, -1.80, 4.35], 72.0)
	await shots.capture("00_corridor_to_2a")
	_look([-5.90, -2.00, 4.82], [-7.10, -0.80, 4.20], 68.0)
	await shots.capture("01_entry_kitchen_fridge")
	_look([-6.10, -2.30, 4.82], [-11.60, -3.50, 4.35], 74.0)
	await shots.capture("02_main_room_from_entry")
	_look([-8.00, -4.65, 4.82], [-9.55, -6.00, 4.05], 68.0)
	await shots.capture("03_bedroom_door_shelf")
	_look([-10.05, -3.85, 4.82], [-11.65, -5.40, 4.15], 68.0)
	await shots.capture("04_caption_workstation")
	_look([-8.55, -6.60, 4.82], [-12.10, -8.10, 4.15], 72.0)
	await shots.capture("05_bedroom_from_threshold")
	_look([-7.40, -5.05, 4.82], [-6.15, -5.70, 4.05], 68.0)
	await shots.capture("06_bath_from_threshold")
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
