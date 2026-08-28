extends Node
## ORISON-RR-VERTICAL-ENDS — all basement rooms and the roof terminus.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-VERTICAL-ENDS", 11):
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
	for room_id in ["B1_STORAGE_CAGES", "B1_LAUNDRY", "B1_BOILER",
			"B1_ELECTRICAL", "B1_HALL", "B1_ATRIUM", "B1_UTILITY",
			"B1_COAL", "ROOF_OPEN"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	for door_id in ["B1_DOOR_03", "B1_DOOR_06", "B1_DOOR_07",
			"ROOF_DOOR_01", "ROOF_DOOR_02"]:
		var route_door := root.find_child(door_id, true, false)
		if route_door != null and route_door.has_method("npc_set_open"):
			route_door.call("npc_set_open", true)
	await shots.settle(1.0, "vertical_ends_lit_open")

	_look([-8.00, -4.70, -1.18], [-12.30, -4.70, -1.65], 72.0)
	await shots.capture("00_storage_cages_entry")
	_look([-6.30, 3.30, -1.18], [-11.80, 6.20, -1.75], 72.0)
	await shots.capture("01_laundry_entry")
	_look([5.95, 4.05, -1.18], [9.05, 1.55, -1.65], 72.0)
	await shots.capture("02_boiler_from_door")
	_look([10.75, 1.25, -1.18], [12.55, 1.50, -1.75], 66.0)
	await shots.capture("03_coal_room")
	_look([6.10, -2.00, -1.18], [11.80, -6.50, -1.65], 72.0)
	await shots.capture("04_electrical_entry")
	_look([-2.80, -6.10, -1.18], [2.45, -4.55, -1.45], 72.0)
	await shots.capture("05_basement_hall")
	_look([-2.70, -2.70, -1.18], [2.00, 1.15, -1.50], 76.0)
	await shots.capture("06_basement_atrium")
	_look([-1.85, 3.65, -1.18], [1.85, 5.40, -1.55], 72.0)
	await shots.capture("07_basement_utility")
	_look([-2.80, -5.20, 20.82], [1.20, -7.20, 20.30], 72.0)
	await shots.capture("08_roof_door_route")
	_look([-2.70, -2.65, 20.82], [1.20, 0.20, 20.25], 76.0)
	await shots.capture("09_roof_eye_guard")
	_look([2.80, 4.80, 20.82], [8.70, -1.20, 20.25], 76.0)
	await shots.capture("10_roof_garden_deck")
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
