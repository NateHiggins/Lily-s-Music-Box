extends Node
## ORISON-RR-F02-2D — sealed apartment: solid landing wall and retained fabric.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F02-2D", 6):
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
	# The apartment has no corridor leaf. Only its original internal leaves
	# are opened for inspection; room circuits intentionally remain dark.
	for door_id in ["F02_DOOR_13", "F02_DOOR_14", "F02_DOOR_15"]:
		var door := root.find_child(door_id, true, false)
		if door != null and door.has_method("npc_set_open"):
			door.call("npc_set_open", true)
	await shots.settle(1.0, "f02_2d_dark_internal_open")

	_look([3.78, -8.35, 4.82], [4.40, -6.20, 4.30], 68.0)
	await shots.capture("00_solid_landing_wall")
	_look([8.85, -5.65, 4.82], [11.55, -3.30, 4.22], 74.0)
	await shots.capture("01_empty_main_room")
	_look([9.35, -6.65, 4.82], [11.55, -8.55, 4.20], 72.0)
	await shots.capture("02_empty_bedroom")
	_look([5.95, -1.55, 4.82], [7.45, -2.25, 4.18], 68.0)
	await shots.capture("03_empty_office")
	_look([7.20, -4.05, 4.82], [5.95, -5.05, 4.12], 68.0)
	await shots.capture("04_retained_bath_fabric")
	_look([12.40, -4.90, 4.82], [13.55, -4.90, 4.30], 66.0)
	await shots.capture("05_black_exterior_window")
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
