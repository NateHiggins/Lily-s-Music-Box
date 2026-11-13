extends Node3D
## INERT local optical/cover diagnostic. Real PlayerController + V2 WeatherFX,
## synthetic service-normalized conditions, primitive test geometry. No city,
## campaign/save reconstruction, walked route or artistic acceptance is claimed.

const Effects := preload("res://scripts/building/v2_weather_fx.gd")
const Service := preload("res://scripts/building/live_weather_service.gd")
const INPUTS: Array[String] = [
	"res://scripts/player/player_controller.gd",
	"res://scripts/building/weather_fx.gd",
	"res://scripts/building/v2_weather_fx.gd",
	"res://scripts/building/queens_weather_extension.gd",
	"res://scripts/building/live_weather_service.gd",
	"res://shaders/queens_precipitation_motion.gdshader",
	"res://shaders/queens_precipitation_draw.gdshader",
	"res://shaders/weather_lens.gdshader",
]
const OUTSIDE := Vector3(0.0, 0.03, 0.0)
const INSIDE := Vector3(0.0, 0.03, 5.0)
var player: PlayerController
var effects: Effects
var extension: QueensWeatherExtension
var directory := ""
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var frames: Array[Dictionary] = []
var captures: Array[String] = []
var conditions: Dictionary = {}
var done := false
var original_pointer: Input.MouseMode
var original_taa := false
var source_before: Dictionary = {}
var initial_authority := ""

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks.append({"name": message, "passed": ok})
	print("PRECIP VISIBILITY ", "PASS " if ok else "FAIL ", message)
	if not ok:
		failures.append(message)
		push_error(message)

func input_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in INPUTS:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	result["test"] = FileAccess.get_file_as_string(get_script().resource_path).replace("\r\n", "\n").sha256_text()
	return result

func box(identity: String, size: Vector3, at: Vector3, color: Color, solid := true) -> void:
	var body := StaticBody3D.new()
	body.name = identity
	body.collision_layer = 1 if solid else 0
	body.collision_mask = 0
	body.position = at
	add_child(body)
	var draw := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	draw.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	draw.material_override = material
	body.add_child(draw)
	if solid:
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		body.add_child(shape)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.save_png(directory.path_join(name + ".png")) == OK, "capture " + name)
	captures.append(name + ".png")

func observation(label: String) -> Dictionary:
	var row: Dictionary = {
		"phase": label, "taa": get_viewport().use_taa,
		"camera": str(player.camera.global_transform), "fov": player.camera.fov,
		"player": str(player.global_position), "exposed_ray": effects.exposed(player.global_position),
		"outdoor": effects.get("_outdoor"), "weights": str(extension.weights),
		"conditions": conditions.duplicate(true), "lens_level": effects.get("_lens_level"),
		"contact_updates": effects.get("contact_updates"), "emitters": [],
	}
	for emitter: GPUParticles3D in effects.get("gpu_emitters"):
		row.emitters.append({"name": emitter.name, "emitting": emitter.emitting,
			"visible": emitter.visible, "amount": emitter.amount, "ratio": emitter.amount_ratio,
			"speed_scale": emitter.speed_scale, "draw_shader": emitter.draw_pass_1.surface_get_material(0).shader.resource_path})
	samples.append(row)
	return row

func hold_frames(label: String, count: int, moving := false) -> void:
	var previous := Time.get_ticks_usec()
	for frame in count:
		if moving:
			# Scripted placement, not an input or physics-walking claim. Keep the
			# actual production camera/emitters and world-space particle motion.
			var phase := float(frame) / maxf(1.0, float(count - 1))
			player.global_position = OUTSIDE + Vector3(sin(phase * TAU) * 0.75, 0, -phase * 1.5)
			player.camera.rotation = Vector3(deg_to_rad(-3.0), sin(phase * TAU) * deg_to_rad(22.0), 0.0)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append({"phase": label, "index": frame, "wall_ms": float(now - previous) / 1000.0,
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
			"outdoor": effects.get("_outdoor"), "lens_level": effects.get("_lens_level")})
		previous = now
		if moving and frame in [0, 40, 80, 119]:
			await capture("%s_%03d" % [label, frame])
			# PNG readback/encoding is outside the following sample interval.
			previous = Time.get_ticks_usec()

func set_station(at: Vector3) -> void:
	player.global_position = at
	player.camera.rotation = Vector3(deg_to_rad(-3.0), 0, 0)
	# Real cover query is still throttled normally; the following wait gives
	# the .1 s owner poll time to run, including on unusually fast hardware.
	await get_tree().physics_frame
	await get_tree().create_timer(0.2).timeout

func run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		push_error("SHOT_DIR required"); get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	original_pointer = Input.mouse_mode
	original_taa = get_viewport().use_taa
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		check(false, "requires windowed Forward+ Vulkan"); finish(); return
	RealityState.persistence_enabled = false
	GameBoot.settings.weather_network_enabled = false
	initial_authority = JSON.stringify(RealityState.data)
	source_before = input_hashes()
	get_viewport().use_taa = true # Production weather's default, kept ON for all captures.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().create_timer(150.0).timeout.connect(func():
		if not done:
			check(false, "150 second diagnostic deadline"); finish())
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.65, 0.72, 0.80)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -25, 0)
	key.light_energy = 0.8
	key.shadow_enabled = true
	add_child(key)
	box("Ground", Vector3(64, 0.2, 64), Vector3(0, -0.1, 0), Color(0.14, 0.16, 0.18))
	box("DarkBackdrop", Vector3(16, 10, 0.2), Vector3(-8, 5, -18), Color(0.045, 0.055, 0.065))
	box("BrightBackdrop", Vector3(16, 10, 0.2), Vector3(8, 5, -18), Color(0.75, 0.77, 0.80))
	box("RealRoofBlocker", Vector3(6, 0.25, 6), Vector3(0, 3.1, 5), Color(0.20, 0.19, 0.18))
	player = PlayerController.new()
	player.name = "ProductionPlayer"
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.set_lamp_enabled(false)
	for layer: CanvasLayer in player.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	player.camera.make_current()
	effects = Effects.new()
	effects.name = "ProductionWeatherFX"
	effects.setup(player, Callable(effects, "exposed"), Callable(effects, "covered"))
	extension = QueensWeatherExtension.new()
	effects.extreme_weather = extension
	effects.set("weather_environment", environment)
	add_child(effects)
	check(effects.get("gpu_emitters").size() == 6, "real PlayerController selects all six production GPU emitters")
	if effects.get("gpu_emitters").size() != 6:
		finish(); return
	effects.apply_profile({"rain": Color(0.62, 0.70, 0.82), "fog": Color(0.32, 0.24, 0.16)})
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await get_tree().physics_frame
	for preset: String in ["rain", "snow"]:
		conditions = Service.presentation(Service.simulated_snapshot(preset))
		conditions.wind_speed_kmh = 18.0
		conditions.wind_direction_degrees = 90.0
		conditions.rain_intensity = 0.55 if preset == "rain" else 0.0
		conditions.snow_intensity = 0.55 if preset == "snow" else 0.0
		conditions.thunderstorm = false
		extension.receive_conditions(conditions, "1929-01-15", 1928)
		extension.advance(300.0) # Settle only this isolated presentation fixture.
		effects.set_live_conditions(conditions)
		await set_station(OUTSIDE)
		await hold_frames(preset + "_warmup_excluded", 180)
		var outside: Dictionary = observation(preset + "_outside")
		var active_kind := 0 if preset == "rain" else 2
		check(bool(outside.outdoor) and bool(outside.exposed_ray), preset + " starts beneath open sky")
		check(outside.emitters[active_kind].emitting and outside.emitters[active_kind].visible, preset + " GPU emission and draw are active")
		await capture(preset + "_outside_taa")
		await hold_frames(preset + "_moving_taa", 120, true)
		observation(preset + "_moved")
		await set_station(INSIDE)
		await get_tree().create_timer(2.3).timeout
		var inside: Dictionary = observation(preset + "_covered")
		check(not bool(inside.exposed_ray) and not bool(inside.outdoor), preset + " actual roof collider activates cover")
		check(not inside.emitters[active_kind].emitting and not inside.emitters[active_kind].visible, preset + " near precipitation is suppressed under cover")
		check(float(inside.lens_level) <= 0.002, preset + " lens moisture decays under shelter")
		await capture(preset + "_covered_taa")
		await set_station(OUTSIDE)
		await hold_frames(preset + "_resume_excluded", 180)
		var resumed: Dictionary = observation(preset + "_resumed")
		check(resumed.emitters[active_kind].emitting and resumed.emitters[active_kind].visible and bool(resumed.outdoor), preset + " re-exposure resumes production precipitation")
		check(int(resumed.contact_updates) > 0, preset + " actual collision heightfield was updated")
		await capture(preset + "_resumed_taa")
	check(JSON.stringify(RealityState.data) == initial_authority, "local weather fixture preserves campaign data")
	check(input_hashes() == source_before, "source inputs stay frozen throughout local review")
	finish()

func finish() -> void:
	if done: return
	done = true
	var size: Vector2 = get_viewport().get_visible_rect().size
	var report: Dictionary = {"evidence_class": "INERT",
		"scope": "Local real PlayerController and production V2 WeatherFX GPU path, service-normalized synthetic rain/snow, bright/dark test geometry, scripted camera movement, actual roof cover/resume; default TAA kept on. Not an occupied-world route, campaign selection, nighttime lighting or artistic acceptance.",
		"renderer": RenderingServer.get_current_rendering_method(),
		"viewport": [size.x, size.y], "taa": get_viewport().use_taa,
		"source_inputs_lf_sha256": source_before, "checks": checks,
		"failures": failures, "samples": samples, "frames": frames, "captures": captures,
		"limits": ["No threshold claims pixel visibility; inspect all images and moving sequence.",
			"Known current cover behavior hides the entire camera volume, including outdoor rain through the opening.",
			"Primitive stock is diagnostic only; not a PBR game asset.",
			"Wall samples exclude explicit PNG encoding intervals; warmup/resume excluded labels are not steady gameplay samples."]}
	FileAccess.open(directory.path_join("precipitation_visibility.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	Input.mouse_mode = original_pointer
	get_viewport().use_taa = original_taa
	print("PRECIPITATION VISIBILITY PROBE: ", checks.size(), " checks, ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
