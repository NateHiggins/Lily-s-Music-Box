extends Node
## ORISON-RR-F01-SERVICE — storage, utility, hall and atrium proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F01-SERVICE", 7):
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
	for room_id in ["F01_STORAGE_C", "F01_UTILITY", "F01_HALL", "F01_ATRIUM"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	await shots.settle(0.8, "service_rooms_lit")
	player.set_process(false)

	_look([5.65, 2.00, 1.62], [8.20, 2.60, 1.10], 72.0)
	await shots.capture("00_storage_south")
	_look([8.80, 6.15, 1.62], [6.20, 4.80, 1.15], 72.0)
	await shots.capture("01_storage_north")
	_look([-1.90, 3.55, 1.62], [1.90, 5.35, 1.25], 72.0)
	await shots.capture("02_utility_from_door")
	_look([1.70, 6.20, 1.62], [-2.60, 4.40, 1.35], 72.0)
	await shots.capture("03_utility_reverse")
	_look([-2.80, -6.20, 1.62], [2.60, -4.50, 1.45], 72.0)
	await shots.capture("04_hall_lift_approach")
	_look([2.70, -5.80, 1.62], [-3.05, -4.45, 1.55], 72.0)
	await shots.capture("05_hall_art_wall")
	_look([-2.75, -2.75, 1.62], [2.10, 1.25, 1.30], 76.0)
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
		elif child is Label3D and (child.name == "Nameplate"
				or node.is_in_group("resident_placeholders")):
			child.visible = false
		_hide_overlays(child)


func _finish(ok: bool) -> void:
	var passed := shots.finish() if ok else false
	get_tree().quit(0 if passed else 2)
