extends Node
## V3 daylight review of the arcade's street face: the V1 frontispiece
## (engaged piers, blind archivolt, keystone, cartouche) over the portal,
## judged in the light the night frames kept dodging.
##     SHOT_DIR=<abs> godot --path game res://tests/VantryElevationShot.tscn

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT_FORCE", "13:30")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	await _capture("01_frontispiece_head_on",
			[14.0, -12.2, 1.65], [14.0, -27.9, 5.10])
	await _capture("02_frontispiece_oblique",
			[6.6, -13.6, 1.65], [14.6, -27.6, 4.40])
	await _capture("03_portal_close",
			[14.0, -21.5, 1.60], [14.0, -27.9, 3.60])
	print("[VANTRY ELEVATION SHOT] 3 frames saved")
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
