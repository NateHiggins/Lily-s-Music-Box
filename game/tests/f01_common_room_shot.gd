extends Node
## ORISON-RR-F01-COMMON — player-height composition proof for the first
## bounded room-reconstruction checkpoint.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")

var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not shots.setup(self, "ORISON-RR-F01-COMMON", 4):
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
	if "switch_system" in root and root.switch_system:
		if not root.switch_system.toggle_room("F01_COMMON_B"):
			root.switch_system.toggle_room("F01_COMMON_B")
	await shots.settle(0.8, "room_lit")
	player.set_process(false)

	# Corridor approach through F01_DOOR_03: purpose and circulation must read
	# from the player's first legal standing position.
	_look([-6.00, 5.82, 1.62], [-9.05, 6.65, 1.20], 69.0)
	await shots.capture("00_threshold_primary_station")

	# Ordinary standing position at the tea basin, looking back across the
	# shared table and its deliberately mismatched settle/chair seating.
	_look([-6.45, 8.15, 1.62], [-9.15, 6.55, 1.05], 66.0)
	await shots.capture("01_tea_station_to_table")

	# Reverse-angle route proof: the entry and both service-room approaches
	# remain legible from the meeting table.
	_look([-9.15, 7.15, 1.62], [-6.25, 5.45, 1.30], 72.0)
	await shots.capture("02_table_to_exits")

	# The north-west bay after retiring the anachronistic arcade silhouette.
	# Vacancy here is intentional circulation/rest space, not a prompt to add
	# an unrelated replacement cabinet.
	_look([-8.20, 8.65, 1.62], [-12.80, 8.35, 1.15], 64.0)
	await shots.capture("03_quiet_west_bay")
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
