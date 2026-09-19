extends "res://tests/dream_fauna_breath_shot.gd"
func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	if not _prepare_room() or not _aim_at("Tessellates",0.54):
		get_tree().quit(1)
		return
	for cohort: Dictionary in root.fauna.cohorts_in_room(room_key):
		if cohort.batch=="Tessellates":
			var target: Vector3 = cohort.position+Vector3(0,.17,0)
			_stand(root.player.camera.global_position.lerp(target,.25),target)
			break
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for material: ShaderMaterial in root.get("_molten_materials"):
		material.set_shader_parameter("gait_amount",0.0)
		material.set_shader_parameter("fauna_time_override",1.25)
		material.set_shader_parameter("ether_time_override",1.25)
	var mesh: Mesh = root.fauna.get("_tessellates").multimesh.mesh
	var tissue := mesh.surface_get_material(1) as ShaderMaterial
	for i in 180: await RenderingServer.frame_post_draw
	await _capture("01_cloudy_tissue",90)
	var candidate := tissue.shader
	tissue.shader = preload("res://shaders/dream_fauna.gdshader")
	await _capture("02_opaque_control",90)
	tissue.shader = candidate
	await _capture("03_cloudy_restored",90)
	tissue.shader = preload("res://shaders/dream_fauna.gdshader")
	await _capture("04_opaque_repeat",90)
	tissue.shader = candidate
	await _capture("05_cloudy_repeat",90)
	await _profile_pairs(tissue,candidate)
	root.player.set_lamp_enabled(false)
	await _capture("06_lamp_off",60)
	FileAccess.open(out_dir.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(perf,"\t"))
	root.queue_free()
	root = null
	for i in 10: await RenderingServer.frame_post_draw
	print("TESSELLATE REVIEW COMPLETE")
	get_tree().quit(failures)

func _capture(label: String, settle_frames := 45) -> void:
	for i in 60: await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	for i in settle_frames:
		await RenderingServer.frame_post_draw
		samples.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	var raw := samples.duplicate()
	samples.sort()
	perf[label] = {"main_view_gpu_median_ms":samples[samples.size()/2],"samples_ms":raw}
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label+".png"))

func _profile_pairs(tissue: ShaderMaterial, candidate: Shader) -> void:
	# ABBA blocks reduce time-order drift; both pipelines have already rendered.
	var blocks: Array[Dictionary] = []
	for block in 32:
		var enabled: bool = block % 4 in [1,2]
		tissue.shader = candidate if enabled else preload("res://shaders/dream_fauna.gdshader")
		for i in 12: await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		for i in 12:
			await RenderingServer.frame_post_draw
			samples.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		var raw := samples.duplicate()
		samples.sort()
		blocks.append({"cloudy":enabled,"median_ms":samples[6],"samples_ms":raw,
			"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	perf["paired_blocks"] = blocks
	tissue.shader = candidate
