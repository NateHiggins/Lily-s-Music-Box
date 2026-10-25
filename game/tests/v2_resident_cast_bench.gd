extends Node3D
## Focused loaded/rendered family diagnostics. Not composed-world qualification.
const Resident := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
var failures: Array[String] = []
var records: Array = []
var actors: Array[AnimatedResident] = []

func _ready() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
	print("[RESIDENT CAST] ", "PASS " if ok else "FAIL ", message)

func run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.095, .105, .12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.65, .7, .8)
	environment.environment.ambient_light_energy = .5
	add_child(environment)
	var light := DirectionalLight3D.new()
	add_child(light); light.rotation_degrees = Vector3(-35, -25, 0)
	var camera := Camera3D.new()
	add_child(camera); camera.make_current()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.5
	var roster := Resident.roster()
	check(roster.size() == 18, "exact approved cast roster with model and catalogue owners")
	for index in roster.size():
		var row: Dictionary = roster[index]
		var actor: AnimatedResident = Resident.new()
		actor.setup(row.display, row.id, row.unit, row.model)
		actor.externally_driven = true
		actor.position = Vector3((index % 6) * 1.55, 0, (index / 6) * 4.0)
		add_child(actor); actors.append(actor)
		if actor.mina_animation: preload("res://scripts/characters/mina_idle_animation.gd").install(actor)
		check(actor._model != null and actor._model.scale.is_equal_approx(Vector3.ONE), row.id + " original model and scale")
		check(actor._animation_player != null and actor._animation_player.is_playing(), row.id + " active personal idle")
		check(actor.mina_animation != null or str(actor._animation_player.current_animation) == actor.preferred_idle,
			row.id + " existing temperament role selects its exact personal clip")
		var draws := actor.find_children("*", "MeshInstance3D", true, false)
		var triangles := 0; var uv_bad := 0; var tangent_missing := 0
		for draw: MeshInstance3D in draws:
			for surface in draw.mesh.get_surface_count():
				var arrays := draw.mesh.surface_get_arrays(surface)
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var tangent: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
				if tangent.size() != vertices.size() * 4: tangent_missing += 1
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if indices.is_empty():
					for v in vertices.size(): indices.append(v)
				triangles += indices.size() / 3
				if uv.size() != vertices.size(): uv_bad += indices.size() / 3
				else:
					for face in range(0, indices.size(), 3):
						var a := uv[indices[face]]; var b := uv[indices[face + 1]]; var c := uv[indices[face + 2]]
						if absf((b-a).cross(c-a)) < 1e-12: uv_bad += 1
				var material := draw.get_active_material(surface) as StandardMaterial3D
				check(material != null and material.metallic == 0 and not material.uv1_triplanar,
						row.id + " local dielectric atlas finish")
				check(material != MatLib.get_mat("resident_" + str(row.id)), row.id + " shared catalogue material untouched")
				for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
					check(texture != null and texture.get_image() != null and texture.get_image().has_mipmaps(), row.id + " loaded map mip chain")
		check(uv_bad == 0, row.id + " imported UV triangle areas: " + str(uv_bad))
		check(tangent_missing == 0, row.id + " imported tangent streams")
		records.append({"resident": row.id, "triangles": triangles, "degenerate_uv_triangles": uv_bad,
			"missing_tangent_surfaces": tangent_missing, "idle": str(actor._animation_player.current_animation)})
		await get_tree().process_frame
	var frame_ms: Array[float] = []
	camera.position = Vector3(3.8, 5, 17); camera.look_at(Vector3(3.8, .8, 4))
	var previous := Time.get_ticks_usec()
	var sample_started := previous
	var frame := 0
	while frame < 240 or Time.get_ticks_usec() - sample_started < 4000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if frame >= 60: frame_ms.append((now - previous) / 1000.0)
		previous = now
		frame += 1
	for actor: AnimatedResident in actors:
		check(actor._animation_player.is_playing(), actor.resident_id + " idle continues beyond original three-second clip")
	var texture_bytes := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var video_bytes := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("all_eighteen.png"))
	for cohort in 3:
		for index in actors.size(): actors[index].visible = index / 6 == cohort
		camera.position = Vector3(3.85, 1.0, cohort * 4.0 + 8)
		camera.look_at(Vector3(3.85, .85, cohort * 4.0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("cast_%d.png" % cohort))
	var bar: Dictionary = {}
	if failures.is_empty():
		var reviewer := load("res://tests/v2_bar_resident_review.gd") as Script
		if reviewer == null or not reviewer.can_instantiate():
			check(false, "bar review helper compiles")
		else:
			bar = await reviewer.run(self, actors, camera, directory)
			check(bar.has("failures") and bar.has("poses") and bar.has("native_import_metrics"),"bar review finishes and returns its complete diagnostic record")
			for failure: String in bar.get("failures", []): failures.append("bar: " + failure)
	var file := FileAccess.open(directory.path_join("cast.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class": "INERT", "scope": "Loaded family bench; no playable-world performance, arrival, schedule, save or human acceptance claims",
		"residents": records, "failures": failures, "full_cast_frame_ms": frame_ms,
		"texture_bytes": texture_bytes, "video_bytes": video_bytes,
		"settings": {"viewport": str(get_viewport().get_visible_rect().size), "max_fps": Engine.max_fps,
			"vsync": DisplayServer.window_get_vsync_mode(), "msaa_3d": get_viewport().msaa_3d,
			"cast_camera": "orthographic size 5.5; fixed family environment and key light"},
		"bar_review": bar,
		"memory_limit": "Original PackedScenes still reference their source atlases; active-map reduction alone establishes no memory saving."}, "\t")); file.close()
	print("RESIDENT CAST BENCH: ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
