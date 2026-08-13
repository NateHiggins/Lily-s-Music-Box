extends Node
## Deterministic M0.5 construction evidence from both sides of the zone gate.
##     SHOT_DIR=<abs> godot --path game res://tests/PassageShot.tscn

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	cam = Camera3D.new()
	cam.fov = 72.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	# The beauty frame proves architecture, not one stochastic traffic phase.
	# Keep the authored vehicles in the scene but freeze their run before the
	# four camera stations are recorded.
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	await _capture("01_street_portal",
			[14.0, -20.5, 1.68], [14.0, -28.9, 1.62])
	await _capture("02_throat_reveal",
			[14.0, -33.2, 1.68], [14.0, -48.0, 1.52])
	await _capture("03_hall_south",
			[14.0, -39.5, 1.68], [14.0, -61.0, 1.48])
	await _capture("04_hall_north",
			[14.0, -63.6, 1.68], [14.0, -42.0, 1.48])
	print("[PASSAGE SHOT] 4 frames saved")
	get_tree().quit(0)


func _capture(label: String, blender_eye: Array, blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
	# Two frames apply the camera-owned visibility gate; the longer hold lets
	# compatibility lights settle before the frame becomes evidence.
	await get_tree().create_timer(1.25).timeout
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
