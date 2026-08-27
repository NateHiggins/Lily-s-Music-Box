extends Node
## ORISON-RR-F01-SUPPORT — office, package room and public-restroom proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F01-SUPPORT", 6):
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
	for room_id in ["F01_OFFICE", "F01_PACKAGE", "F01_RESTROOM"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	await shots.settle(0.8, "support_rooms_lit")
	player.set_process(false)

	_look([-11.85, 5.10, 1.62], [-11.80, 3.60, 1.15], 70.0)
	await shots.capture("00_office_from_threshold")
	_look([-11.78, 3.25, 1.62], [-11.78, 5.05, 1.42], 69.0)
	await shots.capture("01_office_workbench_reverse")
	_look([-7.65, 5.05, 1.62], [-7.70, 3.25, 1.25], 70.0)
	await shots.capture("02_package_from_threshold")
	_look([-7.70, 3.70, 1.62], [-9.25, 2.77, 1.55], 65.0)
	await shots.capture("03_package_south_wall")
	_look([-12.20, 6.00, 1.62], [-13.15, 6.45, 1.05], 72.0)
	await shots.capture("04_restroom_from_threshold")
	_look([-12.75, 6.35, 1.62], [-13.38, 6.95, 1.18], 64.0)
	await shots.capture("05_restroom_fixture_station")
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
