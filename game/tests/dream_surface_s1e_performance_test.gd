extends Node3D

const Colony := preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer := preload("res://scripts/dream/dream_moss_colony_renderer.gd")


func _ready() -> void:
	var camera := Camera3D.new(); camera.position = Vector3(0, 1.2, 2.2)
	add_child(camera); camera.make_current()
	var colony = Colony.new(); colony.configure(4, 8821); colony.seed_at(Vector3.ZERO)
	for _i in 120: colony.add_surface_access(1.0)
	for _i in Colony.MAX_CILIA: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	var renderer = Renderer.new(); add_child(renderer); renderer.setup(colony)
	for _i in 30: await get_tree().process_frame
	var start := Time.get_ticks_usec()
	for _i in 600: renderer._process(1.0 / 60.0)
	var cpu_ms := float(Time.get_ticks_usec() - start) / 600000.0
	var baseline_draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var video_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var rows := []
	for item in [["near", 2.2], ["mid", 5.0], ["far", 10.0]]:
		camera.position.z = float(item[1]); renderer._process(0.25)
		rows.append({"lod": item[0], "visible": renderer.census().cilia_visible})
	print("[S1E PERF] cpu_ms=%.4f draws=%d video_bytes=%d lod=%s census=%s" % [
			cpu_ms, baseline_draws, video_bytes, rows, renderer.census()])
	var ok := cpu_ms < 0.35 and int(rows[0].visible) >= int(rows[1].visible) \
			and int(rows[1].visible) >= int(rows[2].visible)
	renderer.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	print("DREAM SURFACE S1E PERFORMANCE TEST: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
