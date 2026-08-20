extends "res://tests/dream_surface_target_shot.gd"
## Exact-stage frames of the production embrace over the established target
## pocket. The inherited harness contributes no helper room, light or camera.


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	var hazard := _stage_camera()
	if hazard == null:
		printerr("[DREAM EMBRACE SHOT] target pocket missing")
		get_tree().quit(1)
		return
	_settle_lamp(true)
	_seed_ruled_dwell()
	if not bool(root.call("_begin_embrace")):
		printerr("[DREAM EMBRACE SHOT] production presentation refused")
		get_tree().quit(1)
		return
	var embrace := root.get("_embrace") as Node
	embrace.set_process(false)
	await _capture_stage(embrace, "00_room_before_capture", 0.0, 25)
	await _capture_stage(embrace, "01_gold_at_every_edge", 0.28, 25)
	await _capture_stage(embrace, "02_no_direction", 0.52, 25)
	await _capture_stage(embrace, "03_eyes_closed", 0.72, 25)
	await _capture_stage(embrace, "04_lamp_inside_gold", 1.0, 25)
	_settle_lamp(false)
	embrace.call("set_lamp_state_for_proof", false)
	await _capture_stage(embrace, "05_chosen_lamp_stays_off", 1.0, 25)
	print("[DREAM EMBRACE SHOT] 6 frames, findings=%d" % failures)
	get_tree().quit(failures)


func _capture_stage(embrace: Node, stem: String, amount: float,
		frames: int) -> void:
	embrace.call("set_progress_for_proof", amount)
	await _capture(stem, frames)
