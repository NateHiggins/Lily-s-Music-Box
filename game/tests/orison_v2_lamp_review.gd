extends Node
## Matched composed-world review. This does not enable the replacement globally.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var directory: String
var world: OrisonV2RuntimeRoot
var fog: FogVolume
var failures: Array[String] = []
var checks := 0
var _readback_done := false
var _off_bytes := PackedByteArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		push_error("Lamp review requires a capture directory")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	world = Runtime.instantiate()
	add_child(world)
	if world.startup_failed:
		get_tree().quit(2)
		return
	var player := world.player
	var air: Node3D = world.get_node("LampAtmosphere")
	if air.volume == null:
		push_error("Lamp atmosphere failed to compose")
		get_tree().quit(2)
		return
	air.set_process(false)
	air.volume.visible = false
	air.particles.visible = false
	air.particles.emitting = false
	var atmosphere: Node3D = world.get_node("WakingAtmosphere")
	var environment: Environment = atmosphere.environment
	environment.volumetric_fog_enabled = false
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.camera.make_current()
	player.global_position = world.adapter.root.to_global(Vector3(-8.5,3.2,0))
	player.camera.global_position = player.global_position + Vector3.UP*player.STANDING_EYE
	player.camera.look_at(world.adapter.root.to_global(Vector3(-13.4,4.3,.75)))
	player.set_lamp_enabled(true)
	# Settle the carried-device transform, then hold one deterministic thermal
	# state for every photometric comparison. Never tune against different sags.
	await get_tree().create_timer(.3).timeout
	player.set_process(false)
	world.service_set_carrier.set_process(false)
	air.driver.state = preload("res://scripts/lamp/lamp_optical_state.gd").new()
	air.driver.state.configure(0x28A11CE,true)
	air.driver.state.advance(2.0)
	air.driver.apply_output()
	FileAccess.open(directory.path_join("thermal_state.json"),FileAccess.WRITE).store_string(
			JSON.stringify(air.driver.state.save_state(),"\t",true,true))
	player.set_beam_mask_enabled(true)
	await _capture("01_current_overlay")
	player.set_beam_mask_enabled(false)
	await _capture("02_spotlight_only")
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = .0001
	environment.volumetric_fog_length = 12.0
	fog = air.volume
	air.set_process(true)
	await _capture("03_bounded_volume")
	_check(air.field.ready and air.field.failed.is_empty() and air.field.updates > 0 and air.field.uploads > 0,
			"instantaneous optical field injects actual carried-lamp observations")
	_check(air.field.last_observation_error.is_empty() and air.field.readbacks == 0,
			"ordinary optical frames have valid observations and no readback")
	_check(player.lamp_presentation == air.driver, "one preserved controller owns V2 lamp presentation")
	var device: ServiceSetProp = world.service_set_carrier.device
	_check(device._lamp_glass_material.emission == air.driver.output.color
			and is_equal_approx(device._lamp_glass_material.emission_energy_multiplier,float(air.driver.output.filament_emission)),
			"modeled lens follows controller color and thermal emission")
	var radio_was_on := device.radio_powered
	device.set_radio_powered(not radio_was_on,false)
	_check(is_equal_approx(device._lamp_glass_material.emission_energy_multiplier,float(air.driver.output.filament_emission)),
			"radio state cannot overwrite thermal lens output")
	device.set_radio_powered(radio_was_on,false)
	_check(is_equal_approx(air.field.stability,float(air.driver.output.temporal_stability))
			and is_equal_approx(air.field.energy,player.flashlight.light_energy),
			"field consumes actual controller stability and delivered energy")
	_check(air.material.get_shader_parameter("lamp_radiance") == air.field.radiance,
			"participating-air material samples the shared field texture")
	_check(air.particle_material.get_shader_parameter("lamp_radiance") == air.field.radiance
			and air.field._materials.size() == 2, "air and dust share exactly one optical field")
	_check(air.particles.amount == 48 and not air.particles.local_coords
			and air.particles.visible and air.particles.emitting,
			"bounded world-space dust participates while lamp is on")
	_check(fog.visible and player.flashlight.shadow_enabled, "real shadow lamp lights bounded volume")
	_check(fog.size == Vector3(3.9,6.5,3.9), "accepted L1C world bounds expressed on native Y cone axis")
	_check(fog.global_basis.y.dot(player.flashlight.global_basis.z) > .999
			and fog.to_global(Vector3(0,3.25,0)).distance_to(player.flashlight.global_position) < .001,
			"native cone apex is at lens and opens along actual beam")
	_check(not player._light_mask.is_visible_in_tree() and player.flashlight.light_projector == null,
			"no photographic overlay or projected texture")
	# A dark-room comparison isolates the lamp from the room pendant.
	for energy in [.74,1.5,2.4]:
		player.set_lamp_base_energy(energy)
		await _capture("room_energy_%s"%str(energy).replace(".","_"))
	player.set_lamp_base_energy(1.5)
	var room_light: LightFixtureProp = world.adapter.resolve("F02_A_MAIN_LT_PENDANT_SHADE")
	room_light.set_powered(false)
	await _capture("03b_lamp_only_volume")
	for energy in [1.5,2.4,4.2]:
		player.set_lamp_base_energy(energy)
		await _capture("energy_%s"%str(energy).replace(".","_"))
	player.set_lamp_base_energy(1.5)
	air.set_process(false)
	fog.visible = false
	air.particles.visible = false
	await _capture("03c_lamp_only_no_volume")
	fog.visible = true
	air.set_process(true)
	await _shadow_control(air)
	player.set_process(true)
	world.service_set_carrier.set_process(true)
	player.set_lamp_enabled(false)
	await _capture("04_lamp_off")
	_check(not player.lamp_is_enabled() and not fog.visible and player.flashlight.light_volumetric_fog_energy == 0,
			"logical off immediately excludes participating beam")
	_check(not air.particles.visible and not air.particles.emitting, "logical off excludes dust and stops emission")
	_check(not air.field.enabled and air.field.energy == 0, "logical off clears instantaneous field input")
	air.field.debug_readback(func(bytes: PackedByteArray):
		_off_bytes = bytes
		_readback_done = true)
	for i in 120:
		if _readback_done: break
		await get_tree().process_frame
	var all_zero := not _off_bytes.is_empty()
	for byte in _off_bytes:
		if byte != 0:
			all_zero = false
			break
	_check(_readback_done and _off_bytes.size() == 48*48*64*8 and all_zero,
			"entire GPU radiance volume clears on lamp off")
	_off_bytes.clear()
	player.set_lamp_enabled(true)
	await get_tree().create_timer(.6).timeout
	_check(fog.visible and not player._light_mask.is_visible_in_tree(), "toggle cannot restore photographic overlay")
	_check(fog.global_transform.is_equal_approx(player.flashlight.global_transform * Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,0,-3.25))),
			"volume follows the real carried lens transform")
	var retained := [weakref(air),weakref(fog),weakref(air.material),weakref(air.field),weakref(air.field.radiance),weakref(air.field.optics)]
	retained.append_array([weakref(air.particles),weakref(air.particle_material),
			weakref(air.particles.draw_pass_1),weakref(air.particles.process_material)])
	retained.append_array([weakref(air.driver),weakref(air.driver.state)])
	await _profile(air)
	await _profile_injection(air)
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().create_timer(.3).timeout
	for reference: WeakRef in retained:
		_check(reference.get_ref() == null, "new beam owner/resource released")
	print("V2 LAMP REVIEW: %d checks; %d failures; air and dust, other material families pending" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(label: String) -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _shadow_control(air: Node3D) -> void:
	var player := world.player
	player.set_process(false)
	air.set_process(false)
	var blocker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.45,.7,.12)
	blocker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.12,.12,.12)
	blocker.material_override = material
	add_child(blocker)
	blocker.global_transform = player.flashlight.global_transform.translated_local(Vector3(0,0,-1.2))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = player.camera.global_position+player.camera.global_basis.x*.65
	camera.look_at(player.flashlight.global_position-player.flashlight.global_basis.z*3.0)
	camera.make_current()
	for index in 3:
		blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if index == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await _capture("shadow_%d_%s"%[index,"cast" if index == 1 else "clear"])
	player.camera.make_current()
	camera.queue_free()
	blocker.queue_free()
	air.set_process(true)

func _profile(air: Node3D) -> void:
	# Freeze scheduled actors, fixture personalities and thermal drift. Keep
	# the optical owner running so its actual injection cost stays measured.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	air.process_mode = Node.PROCESS_MODE_ALWAYS
	air.driver.state.configure(0x28A11CE,true)
	air.driver.state.advance(2.0)
	air.driver.apply_output()
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	var results := {}
	for iteration in 8:
		var enabled: bool = iteration % 4 in [1,2]
		air.set_process(enabled)
		fog.visible = enabled
		air.particles.visible = enabled
		air.particles.emitting = enabled
		world.get_node("WakingAtmosphere").environment.volumetric_fog_enabled = enabled
		for i in 60: await RenderingServer.frame_post_draw
		var gpu: Array[float] = []
		for i in 90:
			await RenderingServer.frame_post_draw
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		var raw := gpu.duplicate()
		gpu.sort()
		results[str(iteration)+("_volume" if enabled else "_spotlight")] = {"gpu_median_ms":gpu[45],"gpu_p95_ms":gpu[85],"gpu_max_ms":gpu[89],"samples_ms":raw}
	FileAccess.open(directory.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))

func _profile_injection(air: Node3D) -> void:
	# Force a fresh injection at a fixed pose: a conservative moving-lamp
	# compute measurement, independent of whole-viewport timing noise.
	air.set_process(false)
	air.field.profiling = true
	for i in 180:
		air.field.observe(air.observation,true)
		await RenderingServer.frame_post_draw
	air.field.profiling = false
	await RenderingServer.frame_post_draw
	var result := {}
	for key in ["gpu_samples_us","construction_us","submission_us"]:
		var samples: Array = air.field.get(key).duplicate()
		var raw := samples.duplicate()
		samples.sort()
		if samples.size() > 10:
			result[key] = {"count":samples.size(),"median":samples[samples.size()/2],
					"p95":samples[int(samples.size()*.95)],"max":samples[-1],"samples":raw}
	_check(result.size() == 3, "composed injection exposes GPU and CPU timing samples")
	FileAccess.open(directory.path_join("injection_profile.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
