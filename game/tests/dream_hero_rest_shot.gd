extends Node
## H1 production comparator: one fixed lamp/camera, one moving production hero.
## Each pose is frozen once, then rendered old/old/rest for a real A/A floor.

const StageScript := preload("res://tests/dream_stage.gd")

var stage


func _ready() -> void:
	stage = StageScript.new()
	add_child(stage)
	call_deferred("_capture")


func _capture() -> void:
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty():
		out = OS.get_user_data_dir().path_join("hero_rest")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(0.5).timeout
	# This is a hero material proof. Keep the room and the player's lamp, stop
	# the surrounding ecology from adding a changing visual noise floor.
	stage.margin.set_process(false)
	stage.critters.set_process(false)
	stage.director.set_process(false)
	stage.field.set_process(false)
	stage.hero.grow = 1.0
	stage.hero.state = stage.hero.State.SEEKING
	stage.hero.state_clock = 0.0
	for mat in stage.hero.materials:
		mat.set_shader_parameter("grow", 1.0)
		mat.set_shader_parameter("proof_time", 1.75)
	var aim: Vector3 = stage.hero_at + stage.hero_aim.normalized() * 0.86
	var across: Vector3 = stage.hero_aim.normalized().cross(Vector3.UP).normalized()
	stage.camera.global_position = aim + across * 0.78 + Vector3.UP * 0.08
	stage.camera.look_at(aim, Vector3.UP)
	stage.camera.fov = 54.0
	stage.lamp.light_energy = 4.2
	await get_tree().create_timer(0.5).timeout
	if OS.get_environment("SHOT_PERF") == "1":
		await _measure_performance()
		get_tree().quit(0)
		return
	for pose in 6:
		stage.hero.set_process(true)
		await get_tree().create_timer(0.35).timeout
		stage.hero.set_process(false)
		for variant in [["control_a", false], ["control_b", false], ["rest_space", true]]:
			for mat in stage.hero.materials:
				mat.set_shader_parameter("flesh_rest_space", bool(variant[1]))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					out.path_join("pose_%02d_%s.png" % [pose, variant[0]]))
	print("[H1 SHOT] 6 frozen old/old/rest triplets -> %s" % out)
	get_tree().quit(0)


func _measure_performance() -> void:
	# Alternate the two shader paths in one frozen production scene. Geometry,
	# draw ownership, camera, lamp and procedural time remain identical.
	stage.hero.set_process(false)
	var control_trials: Array[float] = []
	var rest_trials: Array[float] = []
	for trial in 3:
		for rest_space in ([false, true] if trial % 2 == 0 else [true, false]):
			for mat in stage.hero.materials:
				mat.set_shader_parameter("flesh_rest_space", rest_space)
			for warmup in 10:
				await RenderingServer.frame_post_draw
			var start_usec := Time.get_ticks_usec()
			var draw_sum := 0.0
			var primitive_sum := 0.0
			for frame in 60:
				await RenderingServer.frame_post_draw
				draw_sum += Performance.get_monitor(
						Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				primitive_sum += Performance.get_monitor(
						Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			var frame_ms := (Time.get_ticks_usec() - start_usec) / 60000.0
			var label := "rest_space" if rest_space else "control"
			print("[H1 PERF] %s trial=%d frame_ms=%.3f draws=%.1f primitives=%.1f" % [
					label, trial + 1, frame_ms, draw_sum / 60.0,
					primitive_sum / 60.0])
			if rest_space:
				rest_trials.append(frame_ms)
			else:
				control_trials.append(frame_ms)
	control_trials.sort()
	rest_trials.sort()
	var control_median: float = control_trials[1]
	var rest_median: float = rest_trials[1]
	var delta_percent := 100.0 * (rest_median - control_median) / control_median
	print("[H1 PERF] MEDIAN control=%.3fms rest_space=%.3fms delta=%+.2f%%" % [
			control_median, rest_median, delta_percent])
