extends Node
## ORISON-RR-F03-OMAR — 3B repair workflow and maintained home.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F03-OMAR", 7):
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
	_hide_other_characters(root)
	if "sanity" in root and root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if "fourth_wall" in root and root.fourth_wall:
		root.fourth_wall.force_finish()
	if "switch_system" in root and root.switch_system:
		for room_id in ["F03_B_MAIN", "F03_B_KITCHEN", "F03_B_ALCOVE", "F03_B_BATH"]:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	for door_id in ["F03_DOOR_03", "F03_DOOR_07", "F03_DOOR_10"]:
		var door := root.find_child(door_id, true, false)
		if door != null and door.has_method("npc_set_open"):
			door.call("npc_set_open", true)
	await shots.settle(1.0, "f03_omar_lit_open")

	_look([-4.20, 5.52, 8.02], [-8.20, 5.20, 7.52], 74.0)
	await shots.capture("00_entry_to_3b")
	_look([-8.40, 5.20, 8.02], [-10.55, 4.10, 7.48], 74.0)
	await shots.capture("01_maintained_main_room")
	_look([-9.15, 4.70, 8.02], [-11.35, 6.02, 7.35], 70.0)
	await shots.capture("02_workbench_teardown")
	_look([-11.45, 4.20, 8.02], [-13.35, 4.72, 7.35], 68.0)
	await shots.capture("03_intake_outgoing_bays")
	_look([-8.30, 6.95, 8.02], [-9.70, 9.20, 7.42], 70.0)
	await shots.capture("04_labeled_fastener_storage")
	_look([-11.15, 7.05, 8.02], [-12.45, 8.50, 7.38], 70.0)
	await shots.capture("05_sleeping_alcove")
	_look([-7.15, 5.45, 8.02], [-5.95, 4.25, 7.32], 68.0)
	await shots.capture("06_bathroom")
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


func _hide_other_characters(node: Node) -> void:
	for child in node.get_children():
		if child != player and (child is CharacterBody3D
				or String(child.name).begins_with("NPC_")):
			child.visible = false
		_hide_other_characters(child)


func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
