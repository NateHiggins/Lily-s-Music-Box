extends Node
## ORISON-RR-F01-1D-BED — exterior-wall and bedside clearance proof.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F01-1D-BED", 2):
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
	# Keep the player lamp on in this regression view: production no longer owns
	# a projector cookie, so no deleted or stale GPU image may reach the wall.
	player.set_lamp_enabled(true)
	_hide_overlays(root)
	if "sanity" in root and root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if "fourth_wall" in root and root.fourth_wall:
		root.fourth_wall.force_finish()
	if "switch_system" in root and root.switch_system:
		if not root.switch_system.toggle_room("F01_D_BED"):
			root.switch_system.toggle_room("F01_D_BED")
	await shots.settle(0.8, "bedroom_lit")
	player.set_process(false)
	_look([7.95, -6.65, 1.62], [12.15, -7.25, 1.05], 72.0)
	await shots.capture("00_bedroom_from_door")
	_look([12.55, -8.80, 1.62], [11.25, -6.70, 0.75], 68.0)
	await shots.capture("01_bedside_clearance")
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
