extends Node3D
## Imported isolated station diagnostics. This does not qualify the composed city.
var failures: Array[String] = []
var checks := 0
var observations: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("TRANSPORT BENCH: " + label)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled = false
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "writable diagnostic output directory")
	var mount_started := Time.get_ticks_usec()
	var station := preload("res://scripts/building/orison_v2_city_transport.gd").mount(self)
	var mount_ms := (Time.get_ticks_usec() - mount_started) / 1000.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_transport.json"))
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var low_source := (load("res://assets/props/city_transport_lod1.glb") as PackedScene).instantiate()
	var low_counts: Dictionary = {}
	for draw: MeshInstance3D in low_source.find_children("*", "MeshInstance3D", true, false):
		metrics._check_cap_mapping(draw.mesh, true)
		low_counts[str(draw.name)] = draw.mesh.surface_get_array_index_len(0)
	low_source.free()
	var parts := 0
	var lod_parts := 0
	for draw: MeshInstance3D in station.find_children("*", "MeshInstance3D", true, false):
		parts += 1
		var mesh := draw.mesh as ArrayMesh
		var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
		var lods: Array = surface.get("lods", [])
		var replacement_reduces := int(low_counts[str(draw.name).replace("_L0__", "_L1__")]) < mesh.surface_get_array_index_len(0)
		check((lods.size() == 1 and is_equal_approx(float(lods[0].edge_length), float(data.lod_error_m))) if replacement_reduces else lods.is_empty(), "replacement LOD where it reduces geometry: " + str(draw.name))
		if replacement_reduces: lod_parts += 1
		metrics._check_cap_mapping(mesh, true)
		var material := draw.material_override as StandardMaterial3D
		check(material != null and not MatLib.is_shared_material(material) and not material.uv1_triplanar, "local authored UV finish: " + str(draw.name))
		for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
			check(texture != null and texture.get_image().has_mipmaps(), "loaded PBR mip chain: " + str(draw.name))
		var shape := draw.get_node("SourceCollision/NearSurface") as CollisionShape3D
		check((shape.shape as ConcavePolygonShape3D).get_faces() == mesh.get_faces(), "near-only visible collision: " + str(draw.name))
	check(parts == data.parts.size() and parts > 0, "nonempty source roster")
	check(lod_parts > 0, "nonempty replacement body roster")
	check(metrics.failures.is_empty(), "imported metre charts and tangent metrics: " + str(metrics.failures))
	metrics.free()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.24, .3, .36)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7, .8, 1.)
	environment.environment.ambient_light_energy = .7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 2.
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var target := Vector3(65, 9, 10)
	camera.position = Vector3(65, 90, 240)
	camera.look_at(target)
	var viewport := get_viewport()
	var original_threshold := viewport.mesh_lod_threshold
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for row: Dictionary in [{"id":"forced_near", "threshold":0., "fov":75.}, {"id":"forced_far", "threshold":10000., "fov":75.}, {"id":"wide", "threshold":1., "fov":75.}, {"id":"narrow", "threshold":1., "fov":5.}, {"id":"forced_far_repeat", "threshold":10000., "fov":75.}, {"id":"forced_near_repeat", "threshold":0., "fov":75.}]:
		viewport.mesh_lod_threshold = float(row.threshold)
		camera.fov = float(row.fov)
		for frame in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var times: Array = []
		var previous := Time.get_ticks_usec()
		for frame in 90:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			times.append({"wall_ms":(now-previous)/1000.,"viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())})
			previous = now
		var primitives := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var calls := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		observations.append({"id":row.id,"fov":camera.fov,"lod_threshold":viewport.mesh_lod_threshold,"visible_primitives":primitives,"visible_draw_calls":calls,"resolution":str(viewport.get_visible_rect().size),"frame_samples":times})
		var out := OS.get_environment("SHOT_DIR")
		if not out.is_empty() and not str(row.id).ends_with("_repeat"):
			check(viewport.get_texture().get_image().save_png(out.path_join(str(row.id)+".png")) == OK, "render saved: " + str(row.id))
	check(int(observations[1].visible_primitives) < int(observations[0].visible_primitives), "forced far actually renders fewer triangles")
	check(int(observations[3].visible_primitives) > int(observations[2].visible_primitives), "narrow FOV selects more detail at the same distance")
	viewport.mesh_lod_threshold = 1.
	camera.fov = 72.
	for view: Dictionary in [{"id":"public_stair", "eye":Vector3(27, 1.41, -8), "target":Vector3(35, 3.3, -5)}, {"id":"lower_platform", "eye":Vector3(45, 12.79, 20), "target":Vector3(86, 12.38, 20)}]:
		camera.position = view.eye
		camera.look_at(view.target)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(directory.path_join(str(view.id)+".png")) == OK, "near finish inspection capture: " + str(view.id))
	viewport.mesh_lod_threshold = original_threshold
	var output := OS.get_environment("SHOT_DIR")
	var sources: Dictionary = {}
	for path: String in ["res://tests/v2_city_transport_bench.gd", "res://scripts/building/orison_v2_city_transport.gd", "res://assets/props/city_transport.glb", "res://assets/props/city_transport_lod1.glb", "res://data/orison_v2/exterior/city_transport.json", "res://data/runtime_material_sets.json", "res://scripts/material_library.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	var file: FileAccess
	if not output.is_empty():
		file = FileAccess.open(output.path_join("transport_bench.json"), FileAccess.WRITE)
		check(file != null, "diagnostic record opens")
	var result := {"evidence_class":"INERT", "scope":"Isolated imported geometry, collision, PBR maps, per-view LOD and repeated uncapped 90-frame viewport timings after warmup. Timings exclude captures. No composed route, whole-world performance or artistic acceptance.", "checks":checks,"failures":failures,"observations":observations,"source_hashes":sources,"draw_parts":parts,"replacement_parts":lod_parts,"mount_cpu_ms":mount_ms,"settings":{"msaa":viewport.msaa_3d,"taa":viewport.use_taa,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}}
	if file != null:
		file.store_string(JSON.stringify(result,"\t")+"\n")
		file.close()
	station.free()
	await get_tree().process_frame
	print("TRANSPORT BENCH: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
