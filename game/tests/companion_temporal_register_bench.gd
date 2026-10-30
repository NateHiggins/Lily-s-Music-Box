extends Node3D
## Small loaded-family diagnostic. No campaign/prologue acceptance claim.
const Register := preload("res://scripts/device/companion_temporal_register.gd")
const State := preload("res://scripts/game/prologue_state.gd")
var failures: Array[String] = []
var register: Node3D
var rig: Node3D
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("REGISTER CHECK ", label, " = ", ok)
	if not ok: failures.append(label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled = false
	var campaign := RealityState.data.duplicate(true)
	rig = preload("res://scripts/device/companion_mechanism.gd").new(); add_child(rig)
	if not rig.build(): check(false, "installed companion builds"); finish(); return
	rig.scale = Vector3.ONE * .42; rig.set_process(false)
	register = Register.new(); rig.add_child(register); rig.temporal_register = register
	if not register.configure(rig): check(false, "native accessory binds"); finish(); return
	check(register.native.global_basis.get_scale().distance_to(Vector3.ONE) < .00001, "phone scale applied once")
	var audit := preload("res://tests/clawfoot_bath_hand_bench.gd").new()
	for draw: MeshInstance3D in register.native.find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count(): audit.check_surface(draw, surface, draw.get_active_material(surface))
	check(audit.failures.is_empty(), "all seven imported stocks retain UV metrics, tangents and loaded PBR mips")
	audit.free()
	var source := MatLib.get_mat("glass_drawn_expressive")
	check(source.uv1_triplanar and source.albedo_color == Color.WHITE and not source.refraction_enabled, "catalogue glass remains unchanged")
	var environment := WorldEnvironment.new(); var state := Environment.new()
	state.background_mode = Environment.BG_COLOR; state.background_color = Color(.09, .11, .13)
	state.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; state.ambient_light_energy = .8
	environment.environment = state; add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-30, -25, 0); light.light_energy = .8; add_child(light)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = .26
	add_child(camera); camera.position = Vector3(.09, .02, .30); camera.look_at(Vector3(0, -.025, .015)); camera.make_current()
	await shot("stowed")
	var target := {"utc_unix_seconds": State.LOOP_START_UTC + 86300, "local_bias_minutes": -300, "local_zone": "EST"}
	check(register.begin(self, target), "validated command opens register without input lease")
	check(register.capacitor.get_shader_parameter("capacitor_charge") == 1.0 and register.emission_counts[1] > 0 and register.emission_counts[2] > 0 and register.emission_counts[3] > 0, "native three core tags drive powered emission")
	register.set_process(false)
	for frame in 240: register.advance(1.0 / 120)
	check(register.phase == "open" and register.hinge.basis.is_equal_approx(Basis(Vector3.RIGHT, deg_to_rad(-210))), "absolute authored open stop")
	print("REGISTER ANGLE open ", register.hinge.rotation, " basis ", register.hinge.basis)
	check(register.labels.Departure.text == "DEPARTURE  UNKNOWN", "staged date never invents death time")
	register.sample_clock(self, State.LOOP_START_UTC + 3600)
	check(register.labels.Passing.text == "PASS 11/10/1928 01.00", "passing row uses supplied historical clock")
	check(register.labels.Passing.pixel_size > register.labels.Departure.pixel_size, "larger passing aperture has larger text")
	await shot("open_front")
	camera.position = Vector3(-.07, .035, -.23); camera.look_at(Vector3(-.002, .018, -.021))
	await shot("capacitor_charged")
	# Verify the complete measured sweep in the installed frame, not just endpoints.
	for step in 121:
		register._set_opening(float(step) / 120)
		for draw: MeshInstance3D in register.native.find_children("*", "MeshInstance3D", true, false):
			var into_rig: Transform3D = rig.global_transform.affine_inverse() * draw.global_transform
			var contained := true
			for surface in draw.mesh.get_surface_count():
				for vertex: Vector3 in draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					contained = contained and register.envelope_in_rig().grow(.00001).has_point(into_rig * vertex)
			check(contained, "sweep manufactured vertices inside framing envelope: " + str(draw.name))
	register._set_opening(1)
	get_tree().paused = true
	var angle: float = register.hinge.rotation.x
	register.release(self); register.advance(1)
	check(register.hinge.rotation.x == angle, "pause freezes retraction")
	get_tree().paused = false
	register.set_process(false)
	for frame in 240: register.advance(1.0 / 120)
	check(register.phase == "idle" and not register.is_processing(), "released accessory settles and stops idle callbacks")
	check(register.capacitor.get_shader_parameter("capacitor_charge") == 0.0, "released command retires emission")
	check(register.hinge.basis.is_equal_approx(Basis(Vector3.RIGHT, deg_to_rad(-90))), "absolute authored stowed stop")
	print("REGISTER ANGLE closed ", register.hinge.rotation, " basis ", register.hinge.basis)
	check(RealityState.data == campaign, "presentation makes no campaign writes")
	camera.position = Vector3(-.08, .04, -.28); camera.look_at(Vector3(0, -.015, .01))
	await shot("capacitor_rear")
	await world_controls(target)
	finish()

func world_controls(target: Dictionary) -> void:
	rig.queue_free(); await get_tree().process_frame
	var player := PlayerController.new(); add_child(player); player.set_physics_process(false)
	player.camera.make_current()
	var carrier := preload("res://scripts/device/companion_world_carrier.gd").new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	if not carrier.world_ready: check(false, "production carrier mounts accessory"); return
	carrier.set_process(false); carrier.rig.set_process(false); carrier.motion.set_physics_process(false)
	carrier.motion.motion_intensity = 0
	carrier.reading = true; carrier.rig.keyboard_open = 1; carrier.rig._apply_keyboard()
	register = carrier.rig.temporal_register
	check(register.begin(self, target), "real carrier accepts accessory presentation")
	register.set_process(false)
	for index in 240: register.advance(1.0 / 120)
	carrier.screen_frame.present_reading = true
	for index in 6: await RenderingServer.frame_post_draw
	var aperture := Rect2(Vector2.ZERO, Vector2(carrier.screen_frame.view.size)).grow(-1)
	var rows_inside := true
	for label: Label3D in register.labels.values():
		for corner in 8:
			rows_inside = rows_inside and aperture.has_point(carrier.screen_frame.view_camera.unproject_position(label.to_global(label.get_aabb().get_endpoint(corner))))
	check(rows_inside and carrier.screen_frame.safe_rect.position.x >= .67, "deployed rows fit the production cropped camera")
	var hull_contains := true
	for corner in 8:
		hull_contains = hull_contains and (register.envelope_in_rig().get_endpoint(corner) * .42).length() < carrier.motion.hull_radius
	check(hull_contains, "retained non-screen hull contains every corner of measured accessory sweep")
	await shot("production_frame")
	var old_cap := Engine.max_fps; Engine.max_fps = 0
	var view: SubViewport = carrier.screen_frame.view
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), true)
	var samples: Array = []
	for visible_now: bool in [true, false, false, true]:
		register.native.visible = visible_now
		for index in 24: await get_tree().process_frame
		var before := Time.get_ticks_usec()
		for index in 120:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			samples.append({"accessory_visible": visible_now, "wall_ms": (now - before) / 1000.0,
				"device_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()),
				"device_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())})
			before = now
	register.native.visible = true; Engine.max_fps = old_cap
	RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(), false)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("accessory_cost.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class": "INERT", "scope": "Same-pose ABBA accessory-visible/hidden render diagnostic, 24 warm-up and 120 intervals per leg; original body and framing stay fixed. Excludes loading/binding and occupied-world/script costs; no gameplay speedup claim.", "resolution": str(get_viewport().get_visible_rect().size), "samples": samples}, "\t"))
	var draft: String = carrier.session.draft
	carrier.device.set_radio_powered(false)
	register.advance(.01)
	check(register.phase == "closing" and register.capacitor.get_shader_parameter("capacitor_charge") == 0.0, "real power owner immediately retires capacitor and closes register")
	check(not register.begin(self, target), "unpowered register cannot deploy")
	for index in 240: register.advance(1.0 / 120)
	check(register.phase == "idle" and carrier.session.draft == draft, "power interruption preserves draft and reaches stow")
	carrier.device.set_radio_powered(true)
	var transient := Node.new(); add_child(transient)
	check(register.begin(transient, target), "next owner can deploy after recovery")
	register.set_process(false); transient.queue_free(); await get_tree().process_frame
	register.advance(.1)
	check(register._owner == null and register.capacitor.get_shader_parameter("capacitor_charge") == 0.0, "departed owner leaves no stale charge or observation")
	carrier.queue_free(); player.queue_free(); await get_tree().process_frame

func shot(label: String) -> void:
	for frame in 3: await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label + ".png")) == OK, "capture " + label)

func finish() -> void:
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("register.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class": "INERT", "checks": checks, "failures": failures, "scope": "Loaded accessory family, metric PBR, scale, authored stops, supplied dates, sweep/hull bounds, pause, real carrier framing/power/owner retirement and isolated render-cost controls. Not occupied-world qualification, validated campaign reload or artistic acceptance; the separate command bench covers real input and reload."}, "\t"))
	print("REGISTER BENCH COMPLETE checks=", checks, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
