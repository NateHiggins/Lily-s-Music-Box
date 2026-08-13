extends Node
## Production-night Phase 4 evidence from the carriageway and the pavement
## that leaked in Check 1.
##     SHOT_DIR=<abs> godot --path game res://tests/StreetEndShot.tscn

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
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	await _capture("01_west_road_weather",
			[-8.0, -19.322, 1.68], [-20.10, -19.322, 2.10])
	await _capture("02_east_road_weather",
			[8.0, -19.322, 1.68], [20.60, -19.322, 2.10])
	await _capture("03_west_south_works",
			[-13.0, -26.105, 1.68], [-20.10, -26.105, 1.25])
	await _capture("04_east_south_works",
			[13.0, -26.105, 1.68], [20.60, -26.105, 1.25])
	print("[STREET END SHOT] 4 frames saved")
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
