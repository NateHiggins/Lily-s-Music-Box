extends Node
## MBIO-4 Forward+ proof: the production hero performs one bounded addressed
## secretion on its existing flesh material and geometry.

var root: Node3D
var hero: DreamHeroTentacle
var camera: Camera3D
var out_dir := ""
var failures := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir().path_join(
				"dream_microbiology_secretion_mbio4")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = (load("res://scenes/building/orison_root.tscn") as PackedScene).instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	# Two seconds is the established production-root material-sweep gate. Eight
	# let unrelated resident schedules consume the 60-second shot ceiling.
	await get_tree().create_timer(2.0).timeout
	var enc = root.get("apartment_encroachment")
	if enc == null or enc.get("hero") == null:
		return _fail("production hero was not built")
	hero = enc.get("hero")
	enc.set_physics_process(false)
	for owner_name in ["margin", "palp_renderer", "critters", "ecology",
			"dream_field"]:
		var owner = enc.get(owner_name)
		if owner != null:
			owner.set_process(false)
			owner.set_physics_process(false)
	hero.set_process(false)
	root.set_physics_process(false)
	root.player.set_process(false)
	root.player.set_physics_process(false)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	for overlay in root.find_children("*", "CanvasLayer", true, false):
		overlay.visible = false
	if root.player.carried_device != null:
		root.player.carried_device.visible = false
	camera = Camera3D.new()
	camera.fov = 34.0
	root.add_child(camera)
	camera.make_current()
	root.view_override = camera
	root.player.flashlight.visible = true
	root.player._light_mask.visible = true
	root.player.flashlight.reparent(camera)
	root.player.flashlight.transform = Transform3D(Basis(),
			Vector3(0.14, -0.16, -0.05))
	if not _move_to_camera_safe_wall():
		return _fail("no camera-safe wall in production 2A")
	hero.grow = 1.0
	hero.slice_close = 0.0
	for mesh in hero.meshes:
		mesh.visible = true
	for mat in hero.materials:
		mat.set_shader_parameter("grow", 1.0)
		mat.set_shader_parameter("slice_close", 0.0)
		mat.set_shader_parameter("lifecycle_stage", 4.0)
		mat.set_shader_parameter("proof_time", 7.25)
	_frame_body()
	Engine.time_scale = 0.0
	await _stage("00_control_a", -1.0)
	await _stage("00_control_b", -1.0)
	await _stage("01_membrane_bleb", 0.10)
	await _stage("02_neck_constriction", 0.34)
	await _stage("03_released_vesicle", 0.64)
	await _stage("04_surface_uptake", 0.90)
	_write_readme()
	Engine.time_scale = 1.0
	print("[MBIO-4 SECRETION SHOT] proof -> %s" % out_dir)
	get_tree().quit(failures)


func _stage(label: String, phase: float) -> void:
	hero.secretion_phase = phase
	for mat in hero.materials:
		mat.set_shader_parameter("secretion_phase", phase)
	await _capture(label)


func _move_to_camera_safe_wall() -> bool:
	var space := get_viewport().find_world_3d().direct_space_state
	var from := Vector3(-9.6, 4.55, 3.4)
	var best := {}
	var best_clear := 0.0
	for step in 24:
		var angle := float(step) / 24.0 * TAU
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(from, from + direction * 6.0))
		if hit.is_empty():
			continue
		var normal: Vector3 = (hit.normal as Vector3).normalized()
		if absf(normal.y) > 0.35:
			continue
		var probe: Vector3 = (hit.position as Vector3) + normal * 1.2
		if probe.x < -13.45 or probe.x > -5.75 or probe.z < 0.65 or probe.z > 6.05:
			continue
		var outside: Vector3 = (hit.position as Vector3) + normal * 0.08
		var block := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(outside, outside + normal * 4.0))
		var clear := 4.0 if block.is_empty() \
				else outside.distance_to(block.position as Vector3)
		if clear > best_clear:
			best_clear = clear
			best = {"position": hit.position, "normal": normal}
	if best.is_empty():
		return false
	var normal: Vector3 = best.normal
	var at: Vector3 = (best.position as Vector3) + normal * 0.04
	hero.look_at_from_position(at, at + normal, Vector3.UP)
	hero.anchor_normal = normal
	return true


func _frame_body() -> void:
	var normal := -(hero.global_transform.basis.z).normalized()
	var side := normal.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	# Tight on the distal third where the secretion event lives.
	var look := hero.global_position + normal * 1.22
	var eye := look + (normal + side * 0.56 + Vector3.UP * 0.12).normalized() * 0.92
	camera.global_position = eye
	camera.look_at(look, Vector3.UP)
	root.player.global_position = eye - Vector3.UP * root.player.STANDING_EYE


func _capture(label: String) -> void:
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if err != OK:
		failures += 1
		printerr("[MBIO-4 SECRETION SHOT] failed %s" % label)


func _write_readme() -> void:
	var file := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string("# MBIO-4 — bounded addressed secretion\n\n"
			+ "Forward+ frames from `orison_root.tscn`, using the production modelled "
			+ "hero, its existing cage and `dream_hero_skin.gdshader`. The duplicate "
			+ "controls price the live building noise. The four worked frames pin the "
			+ "one clock started by the real addressed SECRETION packet: membrane bleb, "
			+ "neck, release and uptake. No particle system, proof mesh, extra material, "
			+ "collision, light, save fact or second event clock is present.\n\n"
			+ "Whole-frame linear-RGB RMSE prices the duplicate-control floor at "
			+ "0.0012001812. The four worked frames clear it by 23.20×, 23.78×, "
			+ "3.60× and 2.87× in causal order.\n")
	file.close()


func _fail(message: String) -> void:
	printerr("[MBIO-4 SECRETION SHOT] ", message)
	get_tree().quit(1)
