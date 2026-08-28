extends Node3D

const Colony := preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer := preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const Critters := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const Generator := preload("res://scripts/dream/critters/dream_critter_generator.gd")
const Species := preload("res://scripts/dream/critters/dream_critter_species.gd")


func _ready() -> void:
	var camera := Camera3D.new(); camera.position = Vector3(0, 1.2, 2.2)
	add_child(camera); camera.make_current()
	for _i in 30: await get_tree().process_frame
	var colony = Colony.new(); colony.configure(4, 8821); colony.seed_at(Vector3.ZERO)
	var video_before := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	for _i in 120: colony.add_surface_access(1.0)
	for _i in Colony.MAX_CILIA: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	var renderer = Renderer.new(); add_child(renderer); renderer.setup(colony)
	for _i in 30: await get_tree().process_frame
	var start := Time.get_ticks_usec()
	for _i in 600: renderer._process(1.0 / 60.0)
	var cpu_ms := float(Time.get_ticks_usec() - start) / 600000.0
	var baseline_draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var video_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var video_delta := maxi(0, video_bytes - video_before)
	var rows := []
	for item in [["near", 2.2], ["mid", 5.0], ["far", 10.0]]:
		camera.position.z = float(item[1]); renderer._process(0.25)
		var lod_start := Time.get_ticks_usec()
		for _sample in 240: renderer._process(1.0 / 60.0)
		var lod_census: Dictionary = renderer.census()
		rows.append({"lod": item[0], "visible": lod_census.cilia_visible,
				"carpet": lod_census.get("cilia_carpet_visible", 0),
				"cpu_ms": float(Time.get_ticks_usec() - lod_start) / 240000.0})
	var organism_costs := await _complex_costs()
	print("[S1E PERF] cpu_ms=%.4f draws=%d materials=6 video_bytes=%d video_delta=%d lod=%s normal_visible=%d dense_visible=%d organisms=%s census=%s" % [
			cpu_ms, baseline_draws, video_bytes, video_delta, rows,
			int(rows[1].visible), int(rows[0].visible), organism_costs, renderer.census()])
	var ok := cpu_ms < 0.35 and int(rows[0].visible) >= int(rows[1].visible) \
			and int(rows[1].visible) >= int(rows[2].visible) \
			and organism_costs.size() == 4
	renderer.free(); renderer = null
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	await get_tree().process_frame
	print("DREAM SURFACE S1E PERFORMANCE TEST: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _complex_costs() -> Array[Dictionary]:
	var controller = Critters.new(); add_child(controller); controller.setup(null, 9917)
	var pool: Array[Dictionary] = []
	for i in 12:
		var kind := Species.Kind.FOLD_CRAB if i % 2 == 0 else Species.Kind.CRYSTAL_LISTENER
		var morph: Dictionary = Generator.generate(kind, 9917 + i)
		pool.append({"id":i+1,"morph":morph,"pos":Vector3(float(i%4)*0.22,0.09,float(i/4)*0.22),
			"up":Vector3.UP,"fwd":Vector3.FORWARD,"gait":0.0,"alive":1.0,"moving":false,
			"leg_state":[],"support_legs":0,"leg_root_gap_max":0.0,"twin":false,"spin":0.0,
			"photo":{},"photo_side":0.0,"mechanical":{},"fold_leg":0,"fold":0.0,
			"unfold":0.0,"manipulator_deploy":0.0,"information_pulse":0.0,"ecology_repeat_count":0})
	var rows: Array[Dictionary] = []
	for count in [1, 4, 8, 12]:
		controller.critters.assign(pool.slice(0, count))
		var start := Time.get_ticks_usec()
		for _i in 300: controller._push()
		rows.append({"count":count,"cpu_ms":float(Time.get_ticks_usec()-start)/300000.0})
	controller.free()
	await get_tree().process_frame
	return rows
