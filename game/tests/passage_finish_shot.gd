extends Node
## Production-night evidence for the weathered, movable Passage finish.
##     SHOT_DIR=<abs> godot --path game res://tests/PassageFinishShot.tscn

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
	cam.fov = 68.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	# Dynamic in play, deterministic in evidence: stop only after the rigid
	# bodies have settled on the terrazzo at their authored starting stations.
	for cart in get_tree().get_nodes_in_group("passage_pushcarts"):
		cart.linear_velocity = Vector3.ZERO
		cart.freeze = true

	await _capture("01_movable_middle_layer",
			[14.0, -40.3, 1.62], [14.0, -60.6, 1.20])
	await _capture("02_laundry_cart",
			[14.55, -44.8, 1.34], [13.0, -46.9, 0.72])
	await _capture("03_market_cart_and_drains",
			[13.35, -52.6, 1.34], [15.0, -54.8, 0.70])
	await _capture("04_news_cart_northbound",
			[15.0, -62.9, 1.46], [13.0, -60.2, 0.68])
	print("[PASSAGE FINISH SHOT] 4 frames saved")
	get_tree().quit(0)


func _capture(label: String, blender_eye: Array, blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
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
