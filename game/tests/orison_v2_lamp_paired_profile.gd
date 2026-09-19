extends Node
## Same-frame paired GPU measurements. Two views share one composed world.
const Runtime = preload("res://scenes/building/orison_v2_runtime.tscn")
const State = preload("res://scripts/lamp/lamp_optical_state.gd")
const DUST_LAYER = 1 << 18
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var world: OrisonV2RuntimeRoot
var directory: String

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	for i in 2:
		var view := SubViewport.new()
		view.size = Vector2i(1280,720)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.world_3d = World3D.new() if i == 0 else views[0].world_3d
		add_child(view)
		views.append(view)
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	world = Runtime.instantiate()
	views[0].add_child(world)
	if world.startup_failed:
		get_tree().quit(2)
		return
	var player := world.player
	var air: Node3D = world.get_node("LampAtmosphere")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.global_position = world.adapter.root.to_global(Vector3(-8.5,3.2,0))
	player.camera.global_position = player.global_position + Vector3.UP*player.STANDING_EYE
	player.camera.look_at(world.adapter.root.to_global(Vector3(-13.4,4.3,.75)))
	player.set_lamp_enabled(true)
	await get_tree().create_timer(.5).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.service_set_carrier._pass_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hide_canvases(world)
	air.driver.state = State.new()
	air.driver.state.configure(0x28A11CE,true)
	air.driver.state.advance(2.0)
	air.driver.apply_output()
	air._update_volume(0)
	air.particles.layers = DUST_LAYER
	for i in 2:
		var camera := Camera3D.new()
		views[i].add_child(camera)
		camera.global_transform = player.camera.global_transform
		camera.fov = player.camera.fov
		camera.near = player.camera.near
		camera.far = player.camera.far
		camera.environment = world.get_node("WakingAtmosphere").environment.duplicate()
		camera.make_current()
		cameras.append(camera)
	# A/B the empty-froxel optimization at the same pose and simulation time.
	# Hide particles for this exact-image check; their GPU motion is unrelated.
	air.particles.visible = false
	var reference := air.material.duplicate() as ShaderMaterial
	reference.shader = preload("res://tests/fixtures/lamp_material/air_before_empty_skip.gdshader")
	air.field.bind_material(reference)
	for candidate in [false,true]:
		air.volume.material = air.material if candidate else reference
		for frame in 90: await RenderingServer.frame_post_draw
		views[0].get_texture().get_image().save_png(directory.path_join("fog_optimization_%s.png"%["candidate" if candidate else "reference"]))
	air.volume.material = air.material
	air.field.unbind_material(reference)
	reference = null
	air.particles.visible = true
	var result := {"resolution":[1280,720], "method":"simultaneous shared World3D, alternating view assignment", "held_pass":"excluded equally", "intervals":[]}
	# Null controls measure renderer order overhead without a visual difference.
	var modes := [[false,false],[true,false],[false,true],[true,true],
		[false,true],[true,false],[false,false],[true,true]]
	for run in modes.size():
		var mode: Array = modes[run]
		for i in 2:
			cameras[i].environment.volumetric_fog_enabled = bool(mode[i])
			cameras[i].cull_mask = 0xFFFFF if bool(mode[i]) else 0xFFFFF & ~DUST_LAYER
		for frame in 60: await RenderingServer.frame_post_draw
		var pairs: Array = []
		for frame in 120:
			await RenderingServer.frame_post_draw
			pairs.append([RenderingServer.viewport_get_measured_render_time_gpu(views[0].get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_gpu(views[1].get_viewport_rid())])
		result.intervals.append({"fog_by_view":mode,"pairs_view0_view1_ms":pairs})
		if run in [1,2]:
			for i in 2:
				views[i].get_texture().get_image().save_png(directory.path_join("view_%d_%s.png"%[run,"candidate" if bool(mode[i]) else "reference"]))
	# Actual injection timestamps are outside viewport GPU queries.
	air.field.profiling = true
	for frame in 180:
		air.field.observe(air.observation,true)
		await RenderingServer.frame_post_draw
	air.field.profiling = false
	result.injection_gpu_us = air.field.gpu_samples_us.duplicate()
	result.injection_construction_us = air.field.construction_us.duplicate()
	result.injection_submission_us = air.field.submission_us.duplicate()
	FileAccess.open(directory.path_join("paired_profile.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().create_timer(.3).timeout
	for view in views: view.queue_free()
	await get_tree().process_frame
	print("V2 LAMP PAIRED PROFILE: eight 120-frame intervals including null controls captured; interpretation requires order-bias review")
	get_tree().quit()

func _hide_canvases(node: Node) -> void:
	if node is CanvasLayer: node.visible = false
	for child in node.get_children(): _hide_canvases(child)
