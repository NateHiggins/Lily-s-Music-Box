extends Node3D

const Gate = preload("res://zone_layer_gate.gd")
var checks: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var target: MeshInstance3D
var neighbor: MeshInstance3D
var lamp: OmniLight3D
var world_contents: Node3D
var camera: Camera3D
var gate: Gate
var case_name: String
var shot_dir: String
var stage_times: Array[Dictionary] = []

func _ready() -> void:
	case_name = OS.get_environment("VULKAN_PAIRING_CASE")
	shot_dir = OS.get_environment("SHOT_DIR")
	print("[PAIRING_PROBE] PID=", OS.get_process_id(), " CASE=", case_name,
		" RENDERER=", RenderingServer.get_current_rendering_method())
	check(["static", "raw", "candidate", "omission"].has(case_name), "known case")
	check(RenderingServer.get_current_rendering_method() == "forward_plus", "actual Forward+ renderer")
	_build()
	gate = Gate.new(target, case_name in ["candidate", "omission"])
	await rendered_frames(8)
	capture("01_initial", true)
	if case_name == "static":
		await rendered_frames(8)
		capture("02_blocked", true)
		await rendered_frames(8)
		capture("03_restored", true)
	else:
		var started: int = Time.get_ticks_usec()
		gate.set_block(&"passage", true)
		gate.set_block(&"street_core", true)
		gate.set_block(&"passage", false)
		check(target.layers == 0, "second blocker survives first release")
		check(target.visible, "layer gate preserves owner's visible property")
		var prior_rebinds: int = gate.rebinds
		var prior_changes: int = gate.changes
		for i in range(8):
			gate.set_block(&"street_core", true)
		check(gate.rebinds == prior_rebinds and gate.changes == prior_changes, "unchanged blocker requests cause no scenario churn")
		await rendered_frames(8)
		stage_times.append({"stage": "first_hide_8_frames", "elapsed_usec": Time.get_ticks_usec() - started})
		capture("02_blocked", false)
		gate.set_block(&"street_core", false)
		check(target.layers == 1 and gate.blocks.is_empty(), "last release restores authored mask and empties blockers")
		await rendered_frames(8)
		capture("03_restored", true)
		# Repeated actual transitions exercise pair ownership, not only idempotency.
		started = Time.get_ticks_usec()
		for i in range(6):
			gate.set_block(&"passage", true)
			await rendered_frames(3)
			gate.set_block(&"passage", false)
			await rendered_frames(3)
		stage_times.append({"stage": "six_hide_restore_cycles_36_frames", "elapsed_usec": Time.get_ticks_usec() - started})
		gate.set_block(&"street_core", true)
		await rendered_frames(8)
	check(neighbor.layers == 1 and neighbor.visible, "neighbor mask and visibility remain owned by neighbor")
	lamp.queue_free()
	await rendered_frames(8)
	capture("04_light_deleted", case_name == "static")
	check(not is_instance_valid(lamp), "light actually retired before final capture")
	if case_name == "candidate":
		check(gate.rebinds == gate.changes and gate.changes == 15, "every actual mask transition has exactly one pre-change rebind")
	elif case_name == "static":
		check(gate.changes == 0 and gate.rebinds == 0, "static control never changes layers or scenario")
	else:
		check(gate.rebinds == 0 and gate.changes == 15, "red control retains layer transitions with no rebind")
	var counts: Dictionary = {"changes": gate.changes, "rebinds": gate.rebinds, "unchanged_calls": gate.unchanged_calls}
	gate = null
	world_contents.queue_free()
	await rendered_frames(8)
	await get_tree().create_timer(0.1).timeout
	var failures: int = 0
	for item in checks:
		if not item["passed"]:
			failures += 1
	var receipt: Dictionary = {
		"schema": "astra-vulkan-pairing-probe-v1", "case": case_name,
		"pid": OS.get_process_id(), "engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"user_data_dir": OS.get_user_data_dir(), "checks": checks,
		"captures": captures, "counts": counts, "stage_times": stage_times,
		"functional_failures": failures,
		"scope": "standalone primitive scene; external log gate required; no production or human acceptance"
	}
	var file: FileAccess = FileAccess.open(shot_dir.path_join("probe_receipt.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write probe receipt")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("[PAIRING_PROBE] FUNCTIONAL_FAILURES=", failures, " CHECKS=", checks.size(), " COUNTS=", counts)
	get_tree().quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "label": label})
	print("[PAIRING_CHECK] ", "PASS " if ok else "FAIL ", label)

func rendered_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

func capture(label: String, expect_target: bool) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = shot_dir.path_join(label + ".png")
	var saved: Error = img.save_png(path)
	var orange: int = 0
	var cyan: int = 0
	# Every other pixel is sufficient and bounds CPU cost on this 1280x720 fixture.
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.25 and c.r > c.g * 1.65 and c.r > c.b * 1.9:
				orange += 1
			if c.b > 0.25 and c.g > 0.2 and c.b > c.r * 1.7 and c.g > c.r * 1.7:
				cyan += 1
	check(saved == OK, label + " PNG saved")
	check((orange > 100) if expect_target else (orange == 0), label + " target draw matches layer expectation")
	check(cyan > 100, label + " unaffected neighbor still draws")
	captures.append({"file": path, "orange_sample_pixels": orange, "cyan_sample_pixels": cyan,
		"expected_target_visible": expect_target, "target_layers": target.layers,
		"target_visible_property": target.visible, "width": img.get_width(), "height": img.get_height()})

func _build() -> void:
	world_contents = Node3D.new()
	add_child(world_contents)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.8
	env_node.environment = env
	world_contents.add_child(env_node)
	camera = Camera3D.new()
	camera.position = Vector3(3.2, 2.4, 5.5)
	world_contents.add_child(camera)
	camera.look_at(Vector3(0.4, 0.55, 0))
	camera.current = true
	target = box(Vector3(1, 1.2, 1), Vector3(-0.5, 0.6, 0), Color(0.9, 0.18, 0.035))
	neighbor = box(Vector3(0.7, 0.8, 0.7), Vector3(1.2, 0.4, 0), Color(0.025, 0.7, 0.9))
	box(Vector3(6, 0.1, 5), Vector3(0, -0.05, 0), Color(0.18, 0.18, 0.18))
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, 1.2)
	lamp.omni_range = 7.0
	lamp.light_energy = 2.0
	lamp.light_size = 0.15
	lamp.light_cull_mask = 1
	lamp.shadow_enabled = true
	world_contents.add_child(lamp)

func box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	node.mesh = mesh
	node.layers = 1
	node.position = pos
	world_contents.add_child(node)
	return node
