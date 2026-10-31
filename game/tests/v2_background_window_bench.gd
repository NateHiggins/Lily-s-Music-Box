extends Node3D
## Isolated optical bench, not occupied-world qualification or artistic acceptance.
const Factory = preload("res://scripts/building/v2_background_window_material.gd")
var materials: Array[ShaderMaterial] = []
var camera: Camera3D
var result := {"scope": "isolated_background_window_optics", "failures": [], "captures": [], "timings": {}}
var output := "C:/ov/reports/window_interior_20261031"

func _ready() -> void:
	if not OS.get_environment("SHOT_DIR").is_empty():
		output = OS.get_environment("SHOT_DIR")
	get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	get_window().size = DisplayServer.screen_get_size()
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.025, 0.04, 0.065)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.48, 0.55, 0.65)
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 0.8
	add_child(light)
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.6, 0.9, 0), Vector3(0.6, 0.9, 0), Vector3(0.6, -0.9, 0), Vector3(-0.6, -0.9, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1,0,0,1, 1,0,0,1, 1,0,0,1, 1,0,0,1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0), Vector2(1.2,0), Vector2(1.2,1.8), Vector2(0,1.8)])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2, 0,2,3])
	var pane := ArrayMesh.new()
	pane.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var backing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(31, 10.0, 0.3)
	backing.mesh = box
	backing.position = Vector3(0, 0, -0.22)
	backing.material_override = MatLib.get_mat("limewash_plaster").duplicate()
	add_child(backing)
	for kind in range(4):
		var material: ShaderMaterial = Factory.create("optical-bench-%d" % kind, kind, Vector2(1.2, 1.8))
		materials.append(material)
		for key in ["glass_albedo", "glass_roughness", "glass_normal", "wall_albedo", "wood_albedo"]:
			var texture: Texture2D = material.get_shader_parameter(key)
			if texture == null or not texture.get_image().has_mipmaps():
				result.failures.append("missing loaded mips: %s" % key)
		var draw := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = pane
		multi.instance_count = 16
		for index in range(16):
			var x := -14.1 + kind * 7.4 + (index % 4) * 1.65
			var y: float = 3.3 - floorf(float(index) / 4.0) * 2.2
			multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, y, 0)))
			multi.set_instance_custom_data(index, Color(float(index + 1) / 64.0, 0, 0, 1))
		draw.multimesh = multi
		draw.material_override = material
		add_child(draw)
	camera.position = Vector3(0, 0, 25)
	camera.look_at(Vector3.ZERO)
	await _frames(12)
	for hour in [10.0, 20.0]:
		for material in materials:
			material.set_shader_parameter("minute_of_day", hour * 60.0)
		await _capture("front_%02d" % int(hour))
	camera.position = Vector3(-12, 0.6, 6)
	camera.look_at(Vector3(-10, 0, 0))
	await _capture("oblique_evening")
	camera.position = Vector3(-10.7, 0.2, 3.1)
	camera.look_at(Vector3(-10.2, 0, 0))
	await _capture("close_evening")
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for enabled in [false, true, false]:
		for material in materials:
			material.set_shader_parameter("interiors_enabled", enabled)
		await _frames(90)
		var cpu: Array[float] = []
		var gpu: Array[float] = []
		var frames: Array[float] = []
		var previous := Time.get_ticks_usec()
		for sample in range(120):
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frames.append(float(now - previous) / 1000.0)
			previous = now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		var key := "interiors" if enabled else ("control_after" if result.timings.has("control_before") else "control_before")
		result.timings[key] = {"cpu_ms": _distribution(cpu), "gpu_ms": _distribution(gpu), "frame_ms": _distribution(frames), "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	result["viewport"] = [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	result["completed"] = true
	var file := FileAccess.open(output.path_join("diagnostic.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("WINDOW OPTICAL BENCH ", JSON.stringify(result))
	get_tree().quit(0 if result.failures.is_empty() else 1)

func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().process_frame

func _capture(label: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	result.captures.append(path)

func _distribution(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median": values[values.size() / 2], "p95": values[int(values.size() * 0.95)], "p99": values[int(values.size() * 0.99)], "max": values[-1]}
