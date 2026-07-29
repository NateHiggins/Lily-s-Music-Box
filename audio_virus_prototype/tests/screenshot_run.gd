extends Node
## Screenshot driver — not part of the game. Run under a virtual display:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . res://tests/Screenshot.tscn
## Steps the real sequence and saves frames of each key beat to the path in
## the SHOT_DIR environment variable (or user:// if unset).

var main: Node
var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	_run()


func _run() -> void:
	await _until(func(): return not main._isolate_btn.disabled, 30.0)
	await _shot("shot_01_ordinary_call")

	main._isolate_btn.button_pressed = true
	await _sleep(5.0)
	await _shot("shot_02_isolated")

	await _until(func(): return not main._capture_btn.disabled, 20.0)
	main._on_capture_pressed()
	await _sleep(2.5)
	await _shot("shot_03_captured_loop")

	main._route_btns[GameState.ROUTE_SPEAKERS].button_pressed = true
	await _until(func(): return GameState.call_stage == GameState.Stage.RESPONSE, 40.0)
	await _sleep(2.0)
	await _shot("shot_04_transmission_response")

	main._do_outcome(GameState.Response.COMPLETE)
	await _sleep(8.0)
	await _shot("shot_05_complete_door")

	await _until(func(): return main._corporate.visible, 30.0)
	await _sleep(1.5)
	await _shot("shot_06_case_resolved")
	get_tree().quit(0)


func _shot(name_base: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name_base]
	img.save_png(path)
	print("saved %s" % path)


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _until(cond: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and not cond.call():
		await get_tree().create_timer(0.25).timeout
		elapsed += 0.25
