extends Node
## Before/after evidence for the light-court standard.
##     SHOT_DIR=<abs> godot --path game res://tests/AtriumShot.tscn

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
	cam.fov = 74.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam

	# Standing in the lobby well, looking straight up the court.
	await _snap("01_court_looking_up", [0.6, -3.4, 0.2], [0.0, 0.0, 14.0])
	# Mid-height, across the well.
	await _snap("02_court_from_f03", [2.4, -2.6, 9.6], [-0.3, 0.3, 15.0])
	# The base and its reading nook.
	await _snap("03_court_base", [2.6, -3.0, -1.6], [0.0, 0.2, -1.4])
	print("[ATRIUM SHOT] 3 frames saved")
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
