extends Node
## Before/after evidence for the Harukiya rebuild.
##     SHOT_DIR=<abs> godot --path game res://tests/HarukiyaShot.tscn

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.5).timeout
	_hide_ui(get_tree().root)
	cam = Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	# Head of the stair, looking down the descent.
	await _snap("01_descent_from_lobby", [5.10, -29.40, 1.55], [5.10, -34.60, -2.20])
	# Standing on the treads mid-flight.
	await _snap("02_mid_flight", [5.10, -31.60, -0.55], [5.10, -35.20, -2.40])
	# The foot of the stair and the red door.
	await _snap("03_foot_and_red_door", [5.10, -34.30, -2.10], [4.15, -34.40, -2.10])
	# Street mouth of the shaft.
	await _snap("04_street_mouth", [5.10, -25.60, 1.60], [5.10, -30.00, 0.20])
	# B3: the arcade corner from the foot of the stair - jukebox against
	# the south wall, the two receivers on the east wall beside it.
	await _snap("05_arcade_corner", [3.30, -34.30, -1.95], [2.60, -37.30, -2.30])
	# B3: the lounge, looking south down the deck at the conversation pit.
	await _snap("06_lounge", [2.50, -30.60, -1.95], [2.80, -33.60, -2.35])
	# The room from the door, so the whole plan reads at once.
	await _snap("07_room_from_door", [3.60, -34.42, -1.95], [-6.00, -33.20, -2.20])
	print("[HARUKIYA SHOT] 7 frames saved")
	get_tree().quit(0)


func _snap(label: String, eye: Array, target: Array) -> void:
	cam.global_position = GameBoot.b2g(eye)
	cam.look_at(GameBoot.b2g(target))
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
