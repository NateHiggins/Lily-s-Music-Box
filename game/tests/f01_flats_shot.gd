extends Node
## ORISON-RR-F01-FLATS — 1A and 1D room/circulation proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F01-FLATS", 8):
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
	for room_id in ["F01_A_MAIN", "F01_A_BED", "F01_A_BATH",
			"F01_D_MAIN", "F01_D_BED", "F01_D_BATH", "F01_D_OFFICE"]:
		if "switch_system" in root and root.switch_system:
			if not root.switch_system.toggle_room(room_id):
				root.switch_system.toggle_room(room_id)
	await shots.settle(0.8, "flat_rooms_lit")
	player.set_process(false)

	_look([-5.85, -0.70, 1.62], [-10.20, -1.55, 1.20], 74.0)
	await shots.capture("00_1a_main_from_entry")
	_look([-6.20, -2.40, 1.62], [-7.20, -0.35, 1.05], 68.0)
	await shots.capture("01_1a_entry_fridge")
	_look([-7.35, -4.05, 1.62], [-6.05, -5.35, 1.05], 70.0)
	await shots.capture("02_1a_bath_threshold")
	_look([-8.10, -8.85, 1.62], [-11.50, -7.35, 1.05], 72.0)
	await shots.capture("03_1a_bedroom")
	_look([8.10, -3.20, 1.62], [11.20, -4.65, 1.20], 74.0)
	await shots.capture("04_1d_main_from_entry")
	_look([7.35, -4.05, 1.62], [6.05, -5.35, 1.05], 68.0)
	await shots.capture("05_1d_bath_threshold")
	_look([7.35, -1.20, 1.62], [6.10, -2.45, 1.05], 68.0)
	await shots.capture("06_1d_office_threshold")
	_look([5.85, -1.20, 1.62], [7.35, -1.85, 1.05], 68.0)
	await shots.capture("07_1d_office_reverse")
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
