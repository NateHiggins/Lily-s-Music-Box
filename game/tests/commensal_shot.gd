extends Node
## Workstream-owned production proof for waking commensal C1.
##
## SHOT_DIR=<absolute> godot --path game --resolution 1280x720 \
##     res://tests/CommensalShot.tscn

var root: Node3D
var director: CommensalDirector
var camera: Camera3D
var output := ""
var failures := 0
var _frame_serial := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT_FORCE", "night")
	OS.set_environment("WEATHER_SEED", "19280731")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.dream_seed = "1928000019280000"
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	director = root.commensals
	if director == null:
		push_error("production CommensalDirector missing")
		get_tree().quit(1)
		return
	director.force_night_for_test(true)
	director._tick.stop()
	_hide_capture_ui(get_tree().root)
	camera = Camera3D.new()
	camera.fov = 48.0
	add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.set_physics_process(false)
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty():
		output = OS.get_user_data_dir().path_join("orison_commensals_c1")
	DirAccess.make_dir_recursive_absolute(output)

	var lamps: Array = director.anchor_ids.lamp_positions
	var lamp: Vector3 = lamps[0]
	await _stage(lamp + Vector3(1.75, -0.42, 2.20), lamp)
	director.moth_batch.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	await _capture("01_lamp_moths_control_a")
	await _capture("02_lamp_moths_control_b")
	director.moth_batch.visible = true
	await _capture("03_lamp_moths_final")
	get_tree().paused = false
	await _stage(lamp + Vector3(0.72, -0.18, 0.92), lamp)
	camera.fov = 38.0
	director.moth_batch.visible = true
	await _capture("04_lamp_moths_close")

	var weed: Vector3 = director.anchor_ids.hoarding_base
	camera.fov = 48.0
	await _stage(weed + Vector3(1.45, 0.68, 1.75), weed + Vector3.UP * 0.18)
	director.weed_batch.visible = true
	await _capture("05_hoarding_weed_final")

	var kitchen := director._roach_at
	camera.fov = 38.0
	await _stage(kitchen + Vector3(0.38, 0.25, 0.42),
			kitchen + Vector3.UP * 0.04)
	director.reset_habituation_for_test()
	await _capture("06_kitchen_quiet")
	director._on_room_toggled(CommensalDirector.KITCHEN_ROOM, true)
	await get_tree().create_timer(0.20).timeout
	await _capture("07_kitchen_scatter")

	print("[COMMENSAL SHOT] seven production frames saved; findings=%d" % failures)
	get_tree().quit(failures)


func _stage(eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	root.player.global_position = eye - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	root.player.velocity = Vector3.ZERO
	root._apply_visibility(root.player.global_position)
	await get_tree().create_timer(0.65).timeout


func _capture(label: String) -> void:
	var expected := _frame_serial + 1
	RenderingServer.frame_post_draw.connect(_mark_frame, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 2000
	while _frame_serial < expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(_mark_frame):
		RenderingServer.frame_post_draw.disconnect(_mark_frame)
	if _frame_serial < expected:
		failures += 1
		push_error("no rendered frame for " + label)
		return
	var path := output.path_join(label + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1
		push_error("could not save " + path)


func _mark_frame() -> void:
	_frame_serial += 1


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
