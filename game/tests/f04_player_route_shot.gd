extends Node
## ORISON-RR-F04-PLAYER-ROUTE — corridor and player-flat spatial proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F04-PLAYER-ROUTE", 7):
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
	for room_id in ["F04_CORRIDOR", "F04_B_VESTIBULE", "F04_B_BATH",
			"F04_B_CLOSET", "F04_B_KITCHEN", "F04_B_MAIN", "F04_B_ALCOVE"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	await shots.settle(0.8, "player_route_lit")
	for door_id in ["F04_DOOR_03", "F04_DOOR_10"]:
		var route_door := root.find_child(door_id, true, false)
		if route_door != null and route_door.has_method("npc_set_open"):
			route_door.call("npc_set_open", true)
	await shots.settle(0.8, "route_doors_open")
	player.set_process(false)

	_look([-4.00, 3.87, 11.22], [-5.60, 3.87, 10.85], 72.0)
	await shots.capture("00_corridor_4b_approach")
	_look([-6.05, 3.75, 11.22], [-8.35, 3.90, 10.85], 72.0)
	await shots.capture("01_vestibule_to_main")
	_look([-7.35, 4.80, 11.22], [-6.10, 6.30, 10.65], 70.0)
	await shots.capture("02_bath_from_threshold")
	_look([-8.05, 4.55, 11.22], [-12.30, 4.00, 10.80], 74.0)
	await shots.capture("03_main_from_entry")
	_look([-10.20, 5.55, 11.22], [-8.20, 5.55, 10.55], 68.0)
	await shots.capture("04_desk_partition_clear")
	_look([-8.10, 7.05, 11.22], [-10.15, 9.20, 10.62], 70.0)
	await shots.capture("05_kitchen_door_and_run")
	_look([-11.20, 6.80, 11.22], [-12.85, 8.45, 10.65], 70.0)
	await shots.capture("06_sleeping_alcove")
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
		elif child is Label3D and (child.name == "Nameplate"
				or node.is_in_group("resident_placeholders")):
			child.visible = false
		_hide_overlays(child)


func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
