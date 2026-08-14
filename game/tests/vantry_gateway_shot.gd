extends Node
## Reproducible Gate A evidence for the Vantry host facade and subway kiosk.
##
##   SHOT_DIR=<abs> GATEWAY_DRY=1 godot --path game \
##       res://tests/VantryGatewayShot.tscn

var root: Node3D
var cam: Camera3D
var _frame_serial := 0
var _capture_failed := false


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	if OS.get_environment("GATEWAY_DRY") == "1" and root.weather != null:
		root.weather.visible = false
	cam = Camera3D.new()
	cam.fov = 72.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	await _capture("01_portal_front",
			[14.0, -20.5, 1.68], [14.0, -28.9, 1.62])
	await _capture("02_east_pavement",
			[24.0, -23.9, 1.68], [16.0, -28.4, 1.70])
	await _capture("03_west_pavement",
			[4.0, -23.9, 1.68], [17.8, -28.6, 1.70])
	await _capture("04_road_arrival",
			[14.0, -17.0, 1.68], [14.6, -28.8, 1.85])
	await _capture("05_before_plane",
			[14.0, -27.45, 1.68], [14.0, -30.6, 1.62])
	await _capture("06_on_plane",
			[14.0, -28.316, 1.68], [14.0, -31.2, 1.62])
	await _capture("07_return_from_throat",
			[14.0, -33.2, 1.68], [14.0, -26.9, 1.60])
	print("[VANTRY GATEWAY SHOT] %s" % [
			"capture failed" if _capture_failed else "7 frames saved"])
	get_tree().quit(1 if _capture_failed else 0)


func _capture(label: String, blender_eye: Array, blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
	await get_tree().create_timer(1.0).timeout
	# A missing post-draw signal must fail this evidence harness rather than
	# strand its headless Godot process. The project rule is one process with a
	# 60-second outer timeout; this inner bound makes the failure attributable.
	var expected_frame := _frame_serial + 1
	RenderingServer.frame_post_draw.connect(_mark_frame, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 2000
	while _frame_serial < expected_frame and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(_mark_frame):
		RenderingServer.frame_post_draw.disconnect(_mark_frame)
	if _frame_serial < expected_frame:
		_capture_failed = true
		push_error("No rendered frame arrived for %s" % label)
		return
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))


func _mark_frame() -> void:
	_frame_serial += 1


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
