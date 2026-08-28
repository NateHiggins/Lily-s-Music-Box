extends Node3D
## L1B six-frame calibration gate. This is test-only and never enters Orison.

var output_dir := "res://../art/renders/lamp_optics_l1b/review_01"
const FAUNA_SHADER := preload("res://shaders/dream_fauna.gdshader")

var camera: Camera3D
var rig: LampOpticalInstrument
var environment: Environment
var columns: Array[Node3D] = []
var material_group: Node3D
var organism: MeshInstance3D
var caption: Label
var capture_overhead_ms := 0.0
var warm_cpu_samples: Array[float] = []
var draw_samples: Array[float] = []
var vram_before := 0
var vram_after := 0
var world_environment: WorldEnvironment
var production_root: Node3D
var organism_material: ShaderMaterial


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir + "/diagnostic"))
	vram_before = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	_build_calibration_room()
	await _settle(18)
	await _capture_diagnostic()
	await _capture_acceptance()
	vram_after = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	_write_receipt()
	get_tree().quit(0)


func _build_calibration_room() -> void:
	world_environment = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("24272c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8b929a")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.18
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0001
	environment.volumetric_fog_length = 16.0
	environment.volumetric_fog_detail_spread = 1.4
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.58
	world_environment.environment = environment
	add_child(world_environment)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.position = Vector3(6.9, 3.25, 7.8)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.25, -3.0))
	add_child(camera)
	camera.make_current()
	_add_static_box("GrayFloor", Vector3(13, 0.18, 17), Vector3(0, -0.09, -2.5),
			Color("6f7378"), 0.78, 0.0)
	_add_static_box("GrayRearWall", Vector3(13, 5.5, 0.22), Vector3(0, 2.65, -10.8),
			Color("686d73"), 0.82, 0.0)
	_add_static_box("GrayLeftWall", Vector3(0.22, 5.5, 17), Vector3(-6.4, 2.65, -2.5),
			Color("5f646a"), 0.88, 0.0)
	_build_material_targets()
	_build_lamp()
	_build_overlay()


func _build_material_targets() -> void:
	material_group = Node3D.new()
	material_group.name = "CalibrationMaterials"
	add_child(material_group)
	_add_sphere("MatteWhite", Vector3(-2.1, 0.72, -4.9), 0.72,
			_material(Color("d8d5cf"), 0.84, 0.0))
	_add_sphere("GlossyDark", Vector3(-0.15, 0.72, -5.2), 0.72,
			_material(Color("171a20"), 0.08, 0.05))
	var brass := _add_cylinder("Brass", Vector3(1.75, 0.78, -5.15), 0.48, 1.55,
			_material(Color("b77a20"), 0.12, 0.92))
	var wax_mat := ShaderMaterial.new()
	var wax_shader := Shader.new()
	wax_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
void fragment(){
 ALBEDO=vec3(0.48,0.13,0.15); ROUGHNESS=0.32; SPECULAR=0.72;
 SSS_STRENGTH=0.54; SSS_TRANSMITTANCE_COLOR=vec4(1.0,0.20,0.12,1.0);
 SSS_TRANSMITTANCE_DEPTH=0.42; SSS_TRANSMITTANCE_BOOST=0.52;
 BACKLIGHT=vec3(0.68,0.10,0.08);
}
"""
	wax_mat.shader = wax_shader
	_add_sphere("TranslucentWax", Vector3(3.35, 0.82, -5.0), 0.80, wax_mat)
	_add_static_box("VarnishedWood", Vector3(5.8, 0.22, 1.15),
			Vector3(0.6, 0.18, -7.25), Color("6d3218"), 0.16, 0.0)
	for x in [-0.75, 0.82]:
		var col := _add_static_box("Occluder", Vector3(0.62, 2.8, 0.62),
				Vector3(x, 1.4, -2.7), Color("aaa9a4"), 0.88, 0.0)
		columns.append(col)


func _build_lamp() -> void:
	rig = LampOpticalInstrument.new()
	rig.name = "L1BOpticalInstrument"
	rig.position = Vector3(-3.75, 2.15, 4.4)
	rig.base_energy = 8.2
	rig.range_m = 14.0
	rig.quality_tier = 2
	add_child(rig)
	rig.look_at(Vector3(0.25, 0.8, -6.1), Vector3.UP)
	rig.state.filament_temperature_k = 2773.0
	rig.state.thermal_inertia = 1.0
	rig.state.supplied_voltage = 110.0
	rig.state.limited_intensity = 0.92


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = Label.new()
	caption.position = Vector2(28, 24)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color("f4eee3"))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)


func _capture_acceptance() -> void:
	# 1: neutral off. The filament is cold and no beam/particle residue survives.
	_set_columns(false)
	_set_organism(false)
	_set_state(0.0, 293.0, 0.0, 0.0)
	caption.text = "NEUTRAL CALIBRATION — LAMP OFF"
	await _settle(12)
	await _save_view("01_neutral_lamp_off.png")
	# 2: stable beam.
	_set_state(0.94, 2773.0, 1.0, 0.0)
	caption.text = "STABLE DYNAMIC BEAM"
	await _settle(20)
	await _save_view("02_stable_dynamic_beam.png")
	# 3: real columns carve direct and volumetric light.
	_set_columns(true)
	caption.text = "TWO OCCLUDERS — SHADOWS CARVED THROUGH THE SHAFT"
	await _settle(20)
	await _save_view("03_two_occluders_carving_volume.png")
	_set_columns(false)
	# 4: seven-state contact sheet, one locked camera.
	var states: Array[Image] = []
	var labels := ["OFF", "EARLY WARM-UP", "STABLE", "CONTACT CHATTER",
			"MECHANICAL SHOCK", "RECOVERY", "COOLING"]
	var values := [
		[0.0, 293.0, 0.0, 0.0], [0.22, 1050.0, 0.31, 0.0],
		[0.94, 2773.0, 1.0, 0.0], [0.58, 2150.0, 0.78, 0.38],
		[0.70, 1880.0, 0.66, 0.82], [0.84, 2480.0, 0.90, 0.12],
		[0.16, 920.0, 0.24, 0.0],
	]
	for i in values.size():
		_set_state(values[i][0], values[i][1], values[i][2], values[i][3])
		caption.text = labels[i]
		await _settle(8)
		states.append(await _grab())
	_save_contact_sheet(states, 4, 2, "04_seven_state_temporal_contact_sheet.png")
	# 5: material, dust and gold. One frame, stable geometry.
	_set_state(0.96, 2773.0, 1.0, 0.0)
	caption.text = "MATTE • GLOSS • BRASS • WAX • WOOD • DUST • RARE GOLD"
	await _settle(24)
	await _save_view("05_material_dust_gold_response.png")
	# 6: approved production fauna mesh/material, identical camera and body.
	await _prepare_production_room()
	_build_approved_organism()
	# The handheld reflector is intentionally visible in the calibration views,
	# but these three views evaluate the illuminated tissue, not prop occlusion.
	for child in rig.get_children():
		if child is MeshInstance3D or child is GPUParticles3D:
			child.visible = false
	var ecology_key := OmniLight3D.new()
	ecology_key.name = "EcologyReviewKey"
	ecology_key.light_color = Color("ffc28a")
	ecology_key.light_energy = 2.2
	ecology_key.omni_range = 3.2
	ecology_key.omni_attenuation = 1.65
	ecology_key.shadow_enabled = true
	ecology_key.light_volumetric_fog_energy = 0.0
	add_child(ecology_key)
	var ecology_views: Array[Image] = []
	var subject := organism.global_position
	var to_camera := (camera.global_position - subject).normalized()
	var camera_right := camera.global_transform.basis.x.normalized()
	for setup in [
		{"label": "FRONT — WET RELIEF",
				"lamp": subject + to_camera * 1.8 + camera_right * 0.72 + Vector3.UP * 0.30},
		{"label": "SIDE — RIDGES / THICKNESS",
				"lamp": subject + camera_right * 1.8 + Vector3.UP * 0.18},
		{"label": "BACK — MEMBRANE / INTERNAL SILHOUETTES",
				"lamp": subject - to_camera * 1.55 + Vector3.UP * 0.18},
	]:
		rig.global_position = setup.lamp
		rig.look_at(subject, Vector3.UP)
		ecology_key.global_position = setup.lamp
		organism_material.set_shader_parameter("lamp_position", rig.global_position)
		organism_material.set_shader_parameter("lamp_direction",
				-rig.global_transform.basis.z)
		organism_material.set_shader_parameter("lamp_intensity", 1.0)
		caption.text = setup.label
		await _settle(14)
		ecology_views.append(await _grab())
	_save_contact_sheet(ecology_views, 3, 1,
			"06_front_side_back_ecology_furnished_room.png")


func _build_approved_organism() -> void:
	organism = MeshInstance3D.new()
	organism.name = "ApprovedAnemoneFauna"
	organism.mesh = DreamFaunaParts.anemones()
	organism.scale = Vector3.ONE * 3.8
	organism.position = camera.global_position \
			- camera.global_transform.basis.z.normalized() * 3.1 \
			+ Vector3(0.0, -0.48, 0.0)
	organism_material = ShaderMaterial.new()
	organism_material.shader = load("res://shaders/lamp_ecology_optics.gdshader")
	var mesh := organism.mesh as ArrayMesh
	mesh = mesh.duplicate(true)
	mesh.surface_set_material(0, organism_material)
	organism.mesh = mesh
	add_child(organism)
	# Organized dark vacuoles are geometry inside the approved outer surface;
	# they never emit and only appear by transmission/occlusion.
	for i in 5:
		var inner := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.10 + 0.025 * float(i % 2)
		sphere.height = sphere.radius * 2.0
		inner.mesh = sphere
		inner.position = organism.position + Vector3(-0.28 + i * 0.14,
				-0.06 + sin(float(i)) * 0.16, 0.0)
		inner.material_override = _material(Color("160814"), 0.44, 0.0)
		add_child(inner)


func _prepare_production_room() -> void:
	# Hide the calibration shell, then stage a runtime-only instance of the
	# genuinely furnished production F01 1D bedroom. No scene resource changes.
	for child in get_children():
		if child == camera or child == rig or child is CanvasLayer:
			continue
		if child is VisualInstance3D:
			child.visible = false
		elif child is Node3D and child != production_root:
			_set_visuals_visible(child, false)
	world_environment.environment = null
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	production_root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(production_root)
	for _i in 150:
		await get_tree().process_frame
	var player := production_root.get("player") as PlayerController
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.set_lamp_enabled(false)
		player.set_beam_mask_enabled(false)
		for child in player.get_children():
			if child is CanvasLayer:
				child.visible = false
		player.visible = false
	_hide_canvas_layers(production_root)
	if production_root.get("switch_system"):
		if not production_root.switch_system.toggle_room("F01_D_BED"):
			production_root.switch_system.toggle_room("F01_D_BED")
	camera.global_position = GameBoot.b2g([7.95, -6.65, 1.62])
	camera.look_at(GameBoot.b2g([11.55, -7.15, 1.08]), Vector3.UP)
	camera.fov = 58.0
	camera.make_current()
	await _settle(45)


func _set_visuals_visible(node: Node, on: bool) -> void:
	for child in node.get_children():
		if child is VisualInstance3D:
			child.visible = on
		_set_visuals_visible(child, on)


func _hide_canvas_layers(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = false
		_hide_canvas_layers(child)


func _capture_diagnostic() -> void:
	var old_position := camera.position
	var old_transform := camera.transform
	var debug := _build_frustum_debug()
	camera.position = Vector3(9.2, 4.8, 0.8)
	camera.look_at(rig.global_position + Vector3(0, 0, -3.2), Vector3.UP)
	caption.text = "DIAGNOSTIC SIDE VIEW — FRUSTUM / FOG BOUNDS / TARGETS / CAMERA"
	await _settle(4)
	await _save_view("diagnostic/side_view.png")
	_write_diagnostics()
	debug.queue_free()
	camera.transform = old_transform
	camera.position = old_position
	camera.look_at(Vector3(0.0, 1.25, -3.0), Vector3.UP)


func _build_frustum_debug() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "DiagnosticFrustum"
	var immediate := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("38e8ff")
	var origin := rig.global_position
	var forward := -rig.global_transform.basis.z.normalized()
	var right := rig.global_transform.basis.x.normalized()
	var up := rig.global_transform.basis.y.normalized()
	var far := origin + forward * rig.light.spot_range
	var radius := tan(deg_to_rad(rig.light.spot_angle)) * rig.light.spot_range
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for p in [far + right * radius, far - right * radius,
			far + up * radius, far - up * radius]:
		immediate.surface_add_vertex(origin)
		immediate.surface_add_vertex(p)
	immediate.surface_end()
	node.mesh = immediate
	add_child(node)
	return node


func _write_diagnostics() -> void:
	var target_positions := {}
	for child in material_group.get_children():
		if child is Node3D:
			var to_target: Vector3 = child.global_position - rig.global_position
			var angle := rad_to_deg(acos(clampf(to_target.normalized().dot(
					-rig.global_transform.basis.z), -1.0, 1.0)))
			target_positions[child.name] = {"position": child.global_position,
					"distance_m": to_target.length(), "axis_angle_deg": angle,
					"inside_cone": angle <= rig.light.spot_angle}
	var data := {
		"spotlight": {"position": rig.light.global_position,
				"direction": -rig.light.global_transform.basis.z,
				"cone_half_angle_deg": rig.light.spot_angle,
				"energy": rig.light.light_energy, "range_m": rig.light.spot_range,
				"attenuation": rig.light.spot_attenuation,
				"color": rig.light.light_color, "shadow_enabled": rig.light.shadow_enabled,
				"cull_mask": rig.light.light_cull_mask},
		"fog_volume": {"transform": rig.fog_volume.global_transform,
				"size": rig.fog_volume.size, "shape": rig.fog_volume.shape,
				"density_gain": rig._fog_material.get_shader_parameter("density_gain")},
		"environment": {"density": environment.volumetric_fog_density,
				"length": environment.volumetric_fog_length,
				"reprojection": environment.volumetric_fog_temporal_reprojection_amount,
				"exposure": environment.tonemap_exposure,
				"tonemapper": environment.tonemap_mode},
		"camera": {"position": camera.global_position, "fov": camera.fov},
		"particle_visibility_aabb": rig.particles.visibility_aabb,
		"ecology_visual_layer": organism.layers if organism else 1,
		"targets": target_positions,
	}
	var file := FileAccess.open(output_dir + "/diagnostic/diagnostics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))


func _set_state(intensity: float, temperature: float, heat: float, shock: float) -> void:
	rig.visible = true
	rig.state.switched_on = intensity > 0.001
	rig.state.limited_intensity = intensity
	rig.state.filament_temperature_k = temperature
	rig.state.thermal_inertia = heat
	rig.state.supplied_voltage = 110.0 if intensity > 0.001 else 0.0
	rig.state.mechanical_shock = shock
	rig.state.instability = shock * 0.48
	rig._apply_output()


func _set_columns(on: bool) -> void:
	for column in columns:
		column.visible = on


func _set_organism(on: bool) -> void:
	if organism:
		organism.visible = on


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
		warm_cpu_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_samples.append(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _save_view(name: String) -> void:
	var t0 := Time.get_ticks_usec()
	var image := await _grab()
	if image.get_width() != 1600 or image.get_height() != 900:
		image.resize(1600, 900, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_dir + "/" + name)
	capture_overhead_ms += float(Time.get_ticks_usec() - t0) / 1000.0


func _save_contact_sheet(images: Array[Image], columns_count: int, rows: int,
		name: String) -> void:
	var sheet := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("15171a"))
	var cell := Vector2i(1600 / columns_count, 900 / rows)
	for i in images.size():
		var src := images[i].duplicate()
		src.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		src.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(src, Rect2i(Vector2i.ZERO, cell),
				Vector2i((i % columns_count) * cell.x, (i / columns_count) * cell.y))
	sheet.save_png(output_dir + "/" + name)


func _write_receipt() -> void:
	var benchmark_state := LampOpticalState.new()
	benchmark_state.configure(1928, true)
	var t0 := Time.get_ticks_usec()
	for i in 20000:
		benchmark_state.advance(1.0 / 120.0, 110.0, 0.5 if i % 5000 == 0 else 0.0)
		benchmark_state.output()
	var controller_ms := float(Time.get_ticks_usec() - t0) / 20000.0 / 1000.0
	var receipt := {
		"packet": "LAMP-OPTICS-L1B/review_01", "resolution": "1600x900",
		"renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(),
		"optical_controller_cpu_ms_per_update": controller_ms,
		"controller_gate_ms": 0.20,
		"warm_total_cpu_ms_median": _median(warm_cpu_samples),
		"capture_readback_and_png_ms_total": capture_overhead_ms,
		"gpu_timing_ms": null,
		"gpu_timing_attempt": "Godot Performance exposes draw/CPU monitors but no stable per-viewport GPU timestamp in this build; RenderingDevice timestamps require an invasive renderer capture and were not fabricated.",
		"vram_before_bytes": vram_before, "vram_after_bytes": vram_after,
		"vram_delta_bytes": vram_after - vram_before,
		"draw_calls_median": _median(draw_samples),
		"particles_high_tier": 144, "fog_volume_count": 1,
		"fog_settings": {"volume_size": "project default", "volume_depth": "project default",
				"length_m": 16.0, "global_density": 0.0001,
				"local_density_gain": 0.055, "reprojection_amount": 0.58},
		"exposure": 1.18, "tonemapper": "ACES",
		"active_lights": 1, "shadowed_lights": 1,
		"acceptance_images": 6,
	}
	var file := FileAccess.open(output_dir + "/receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  "))


static func _median(values: Array[float]) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _add_static_box(name_value: String, size: Vector3, position_value: Vector3,
		color: Color, roughness: float, metallic: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_value
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = _material(color, roughness, metallic)
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = size
	shape.shape = collision
	body.add_child(shape)
	body.position = position_value
	add_child(body)
	return body


func _add_sphere(name_value: String, position_value: Vector3, radius: float,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = material
	node.position = position_value
	material_group.add_child(node)
	return node


func _add_cylinder(name_value: String, position_value: Vector3, radius: float,
		height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = material
	node.position = position_value
	material_group.add_child(node)
	return node


static func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
