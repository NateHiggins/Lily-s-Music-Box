extends Node
## ORISON-RR-F02-2B — Lena Ortiz's supporting-resident apartment.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F02-2B", 6):
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
		for room_id in ["F02_B_MAIN", "F02_B_KITCHEN", "F02_B_ALCOVE", "F02_B_BATH"]:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	for door_id in ["F02_DOOR_03", "F02_DOOR_06", "F02_DOOR_09"]:
		var door := root.find_child(door_id, true, false)
		if door != null and door.has_method("npc_set_open"):
			door.call("npc_set_open", true)
	await shots.settle(1.0, "f02_2b_lit_open")
	var cabinet := root.find_child("F02_2B_MIRROR_01", true, false) as MedicineCabinetProp
	if cabinet != null:
		print("[ORISON-RR-F02-2B CABINET] closed_at_capture=%s contents=%s" % [
				str(not cabinet.is_door_open()), str(cabinet.inventory_names())])

	_look([-4.20, 5.52, 4.82], [-8.80, 5.15, 4.35], 74.0)
	await shots.capture("00_entry_to_living")
	_look([-10.60, 4.10, 4.82], [-13.15, 6.05, 4.35], 72.0)
	await shots.capture("01_living_story_wall")
	_look([-9.10, 6.05, 4.82], [-6.20, 8.25, 4.30], 72.0)
	await shots.capture("02_kitchen_from_living")
	_look([-9.55, 8.15, 4.82], [-12.35, 8.25, 4.25], 70.0)
	await shots.capture("03_alcove_from_kitchen")
	_look([-12.65, 6.75, 4.82], [-11.55, 8.85, 4.20], 68.0)
	await shots.capture("04_alcove_storage")
	_look([-7.05, 4.75, 4.82], [-6.05, 4.10, 4.20], 68.0)
	await shots.capture("05_bath_from_living")
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
