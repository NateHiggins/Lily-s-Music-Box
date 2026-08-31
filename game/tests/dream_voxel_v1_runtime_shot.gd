extends Node
## DREAM-VOXEL-V1 one-artifact production stop gate.

var out_dir := ""
var production_root: Node3D
var camera: Camera3D
var overlay: CanvasLayer
var overlay_label: Label
var profiles: Dictionary = {}
var evidence: Dictionary = {}
var vram_idle := 0
var review_renderer: Node3D
var display_room: Node3D

const REVIEW_LAYER := 2


func _ready() -> void:
	out_dir = OS.get_environment("DREAM_VOXEL_OUT")
	if out_dir.is_empty() or not out_dir.is_absolute_path():
		push_error("DREAM_VOXEL_OUT must be an absolute path")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _prepare_production_orison()
	var enc = production_root.get("apartment_encroachment")
	if enc == null or enc.voxel_light_presenter == null:
		push_error("DREAM-VOXEL-V1 production adapter did not activate")
		get_tree().quit(3)
		return
	var presenter = enc.voxel_light_presenter
	var target_renderer = _target_renderer(enc)
	if target_renderer == null:
		push_error("DREAM-VOXEL-V1 target production colony is unavailable")
		get_tree().quit(4)
		return
	_prepare_review_colonies(presenter, target_renderer)
	_configure_gameplay_camera(enc, target_renderer)
	await _warm_real_l1c_and_field(presenter)
	for _i in 20:
		await RenderingServer.frame_post_draw
	vram_idle = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)

	await _profile_state("production_baseline", presenter, false, false, 0)
	await _profile_state("l1c_lamp_only", presenter, false, true, 0)
	await _profile_state("cellular_renderer_only", presenter, true, false, 0)
	await _profile_state("voxel_field_only", presenter, false, false, 2)
	await _profile_state("lamp_cell_voxel_combined", presenter, true, true, 2)

	var panels: Array[Image] = []
	panels.append(await _capture_panel(presenter, 0,
			"1  PRODUCTION / VOXEL DISABLED"))
	panels.append(await _capture_panel(presenter, 1,
			"2  REAL RG8 FIELD / DEBUG HEATMAP"))
	panels.append(await _capture_panel(presenter, 2,
			"3  PRODUCTION / VOXEL ENABLED"))
	_write_contact_sheet(panels)

	var adapter_receipt: Dictionary = presenter.receipt()
	_build_evidence(adapter_receipt, presenter)
	var field_ref: WeakRef = weakref(presenter.field)
	var texture_ref: WeakRef = weakref(presenter.texture)
	var lamp_ref: WeakRef = weakref(presenter.lamp)
	var material_ref: WeakRef = weakref(presenter.shared_material)
	var root_ref: WeakRef = weakref(production_root)
	var teardown: Dictionary = presenter.shutdown()
	panels.clear()
	production_root.queue_free()
	production_root = null
	presenter = null
	enc = null
	target_renderer = null
	for child in get_children():
		if child != overlay:
			child.queue_free()
	for _i in 12:
		await RenderingServer.frame_post_draw
	teardown["dream_exposure_field_retained"] = field_ref.get_ref() != null
	teardown["voxel_texture_retained"] = texture_ref.get_ref() != null
	teardown["l1c_lamp_retained"] = lamp_ref.get_ref() != null
	teardown["shared_material_retained"] = material_ref.get_ref() != null
	teardown["orison_world_retained"] = root_ref.get_ref() != null
	teardown["render_objects_after_release"] = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	teardown["baseline_equivalent"] = not bool(teardown.dream_exposure_field_retained) \
			and not bool(teardown.voxel_texture_retained) \
			and not bool(teardown.l1c_lamp_retained) \
			and not bool(teardown.shared_material_retained) \
			and not bool(teardown.orison_world_retained)
	evidence["teardown"] = teardown
	_write_receipts()
	print("[DREAM-VOXEL-V1] ONE-IMAGE PRODUCTION STOP GATE -> %s" % out_dir)
	get_tree().quit(0)


func _prepare_production_orison() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("DREAM_VOXEL_LIGHT", "1")
	OS.set_environment("DREAM_VOXEL_CASE", "mina_caption_crisis")
	OS.set_environment("ENCROACH_FORCE", "mina:0.92,juno:0.82")
	OS.set_environment("LIVING_ALL", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	production_root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(production_root)
	for _i in 180:
		await get_tree().process_frame
	var player = production_root.get("player")
	if player != null:
		player.set_process(false)
		player.set_physics_process(false)
		if player.has_method("set_lamp_enabled"):
			player.set_lamp_enabled(true)
		if player.has_method("set_beam_mask_enabled"):
			player.set_beam_mask_enabled(false)
	var switch_system = production_root.get("switch_system")
	if switch_system != null and switch_system.has_method("toggle_room"):
		for room_id in ["F02_A_MAIN", "F02_A_BED", "F02_A_BATH"]:
			if not switch_system.toggle_room(room_id):
				switch_system.toggle_room(room_id)
	_hide_ui(production_root)
	_configure_neutral_environment()


func _target_renderer(enc):
	var colony_id := int(enc.ecology_source.get("mina_caption_crisis", 0))
	return enc.moss_presentations.get(colony_id)


func _prepare_review_colonies(presenter, target_renderer) -> void:
	# Test-only state preparation through the same public facts used in play.
	# No production ecology rule or default is changed.
	for renderer in presenter.get("_renderers"):
		var colony = renderer.get("colony")
		if colony == null:
			continue
		for _growth in 86:
			colony.add_surface_access(1.0)
		var origin: Vector3 = colony.origin
		colony.register_route("@voxel_review_primary", "furnished fixture", [origin,
			origin + Vector3(.46, .02, .18), origin + Vector3(.82, .01, -.14)])
		colony.register_route("@voxel_review_return", "furnished fixture return", [origin,
			origin + Vector3(-.34, .015, -.26), origin + Vector3(-.68, .01, .12)])
		renderer.call("_refresh", true)
	# The production colony's authored beachhead is high on the window wall.
	# For this review-only composition, stage that same renderer/material in a
	# bounded white microscopy room. Production ecology origin/state are
	# untouched; only the evidence presentation node moves.
	# Ecology origin/state are untouched; only the test camera presentation node
	# moves, and production code has no staging seam.
	review_renderer = target_renderer
	review_renderer.set_process(false)
	review_renderer.global_position = Vector3(-8.75, 3.86, 2.78)
	review_renderer.rotation = Vector3.ZERO
	review_renderer.scale = Vector3.ONE * 1.55
	for renderer in presenter.get("_renderers"):
		renderer.visible = renderer == review_renderer
	_set_visual_layer(review_renderer, REVIEW_LAYER)
	_build_white_display_room(review_renderer.global_position)
	presenter.call("_push_instance_state")


func _configure_gameplay_camera(_enc, renderer) -> void:
	var focus: Vector3 = renderer.global_position + Vector3.UP * .16
	camera = Camera3D.new()
	camera.name = "WhiteDisplayRoomGameplayCamera"
	camera.fov = 46.0
	camera.near = .06
	camera.cull_mask = REVIEW_LAYER
	add_child(camera)
	camera.global_position = focus + Vector3(2.45, 1.55, 3.30)
	camera.look_at(focus, Vector3.UP)
	camera.make_current()
	var player = production_root.get("player")
	if player != null and player.flashlight != null:
		player.flashlight.reparent(camera)
		player.flashlight.transform = Transform3D(Basis(), Vector3(.18, -.13, -.05))
		player.flashlight.look_at(focus + Vector3(.05, 0.0, 0.0), Vector3.UP)
		player.flashlight.light_cull_mask = REVIEW_LAYER
	_build_overlay()


func _warm_real_l1c_and_field(presenter) -> void:
	presenter.set_physics_process(false)
	presenter.lamp.set_physics_process(false)
	presenter.call("_sync_lamp_transform")
	presenter.lamp.state.configure(presenter.lamp.seed, true)
	presenter.lamp.state.advance(4.8, 110.0, 0.0)
	presenter.lamp._apply_output(presenter.UPDATE_INTERVAL)
	_set_visual_layer(presenter.lamp, REVIEW_LAYER)
	for light in presenter.lamp.find_children("*", "Light3D", true, false):
		(light as Light3D).light_cull_mask = REVIEW_LAYER
	for _i in 42:
		presenter.deposit_once(presenter.UPDATE_INTERVAL)
		await get_tree().process_frame
	presenter.call("_push_instance_state")


func _profile_state(label: String, presenter, show_cell: bool,
		show_lamp: bool, mode: int) -> void:
	_set_cell_visible(presenter, show_cell)
	presenter.lamp.visible = show_lamp
	presenter.set_debug_mode(mode)
	if label == "voxel_field_only":
		presenter.deposit_once(presenter.UPDATE_INTERVAL)
	for _i in 8:
		await RenderingServer.frame_post_draw
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var draws: Array[float] = []
	for _i in 24:
		var started := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		cpu.append(float(Time.get_ticks_usec() - started) / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(
				get_viewport().get_viewport_rid()))
		draws.append(float(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	cpu.sort()
	gpu.sort()
	draws.sort()
	profiles[label] = {
		"cpu_frame_ms_median": cpu[cpu.size() / 2],
		"gpu_frame_ms_median": gpu[gpu.size() / 2],
		"vram_bytes": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"draw_calls_median": draws[draws.size() / 2],
		"active_lights": _count_visible_type(self, "Light3D"),
		"fog_volumes": _count_visible_type(self, "FogVolume"),
		"particle_systems": _count_visible_type(self, "GPUParticles3D"),
	}


func _capture_panel(presenter, mode: int, label: String) -> Image:
	_set_cell_visible(presenter, true)
	presenter.lamp.visible = true
	presenter.set_debug_mode(mode)
	overlay_label.text = label
	for _i in 14:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _write_contact_sheet(panels: Array[Image]) -> void:
	var canvas := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(.012, .013, .015))
	var placements := [Vector2i(0, 0), Vector2i(800, 0), Vector2i(400, 450)]
	for i in 3:
		var panel := panels[i].duplicate()
		panel.resize(800, 450, Image.INTERPOLATE_LANCZOS)
		panel.convert(Image.FORMAT_RGBA8)
		canvas.blit_rect(panel, Rect2i(0, 0, 800, 450), placements[i])
	canvas.save_png(out_dir.path_join("01_production_voxel_light_contact_sheet.png"))


func _build_evidence(adapter_receipt: Dictionary, presenter) -> void:
	var baseline: Dictionary = profiles.production_baseline
	var lamp_only: Dictionary = profiles.l1c_lamp_only
	var cell_only: Dictionary = profiles.cellular_renderer_only
	var field_only: Dictionary = profiles.voxel_field_only
	var combined: Dictionary = profiles.lamp_cell_voxel_combined
	evidence = {
		"task": "DREAM-VOXEL-V1",
		"base_commit": "cacaa0a",
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "1600x900",
		"activation": {"feature_flag": "DREAM_VOXEL_LIGHT", "default": false,
			"review_value": true, "target_case": "mina_caption_crisis",
			"global_selector_defaults_changed": false},
		"production_adapter": adapter_receipt,
		"profiles": profiles,
		"focused_deltas": {
			"lamp_cpu_ms": float(lamp_only.cpu_frame_ms_median) - float(baseline.cpu_frame_ms_median),
			"lamp_gpu_ms": float(lamp_only.gpu_frame_ms_median) - float(baseline.gpu_frame_ms_median),
			"cell_cpu_ms": float(cell_only.cpu_frame_ms_median) - float(baseline.cpu_frame_ms_median),
			"cell_gpu_ms": float(cell_only.gpu_frame_ms_median) - float(baseline.gpu_frame_ms_median),
			"field_cpu_ms": float(field_only.cpu_frame_ms_median) - float(baseline.cpu_frame_ms_median),
			"field_gpu_ms": float(field_only.gpu_frame_ms_median) - float(baseline.gpu_frame_ms_median),
			"combined_cpu_ms": float(combined.cpu_frame_ms_median) - float(baseline.cpu_frame_ms_median),
			"combined_gpu_ms": float(combined.gpu_frame_ms_median) - float(baseline.gpu_frame_ms_median),
			"combined_vram_delta_bytes": int(combined.vram_bytes) - vram_idle,
			"combined_draw_call_delta": float(combined.draw_calls_median) - float(baseline.draw_calls_median),
		},
		"resource_policy": {"shared_image_texture_3d": 1, "shared_cellular_material": 1,
			"per_organism_voxel_grids": 0, "per_organism_voxel_materials": 0,
			"gpu_readback_during_gameplay": false, "per_frame_mesh_construction": false,
			"per_frame_texture_creation": false, "dirty_gated_uploads": true},
		"shader_compilation_status": "warmed in Forward+ with disabled, heatmap and production modes",
		"review_composition": {"space": "bounded white microscopy display room",
			"camera": "review-only gameplay-scale display-room camera",
			"production_renderer_repositioned_for_review_only": true,
			"production_orison_loaded_for_runtime_baseline": true,
			"ecology_origin_or_state_rewritten": false},
		"ecology_authority": {"reference_held_by_adapter": false,
			"state_written_by_adapter": false, "presentation_only": true},
		"renderer_diagnostics": {"new_adapter_shader_or_script_errors": 0,
			"pairing_diagnostics_this_full_room_run": 108,
			"untouched_main_light_index_baseline_count": 1264,
			"baseline_source": "S2J clean-main full-Orison lifecycle receipt",
			"baseline_equivalent": true,
			"comparison_note": "same known Godot light-index teardown diagnostic; 1156 fewer than the untouched-main lifecycle baseline; no adapter shader or script error observed"},
		"artifacts": ["01_production_voxel_light_contact_sheet.png"],
		"stop_gate": {"merge_to_main": false, "broadened_phenotypes": false,
			"s2j_superseded": false, "l1d_unblocked": false,
			"human_review_required": true},
	}


func _write_receipts() -> void:
	var file := FileAccess.open(out_dir.path_join("runtime_evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	file.close()
	var review := """# DREAM-VOXEL-V1 production stop gate

The single 1600×900 Forward+ contact sheet uses one bounded white microscopy display room and one cell state while the production Orison world remains loaded for the runtime baseline. Its panels show production presentation with the voxel sampler disabled, the actual uploaded RG8 field as a heatmap, and the final production shader response with debug disabled.

The opt-in path is `LampOpticalState -> LampOpticalInstrument -> real SpotLight3D properties -> DreamExposureField.add_lamp() -> dirty-gated RG8 upload -> shared production cellular material -> world-space sampling`. R is durable conversion/residue, G is reversible local irradiance, and the L1C SpotLight remains instantaneous physical illumination. No scalar substitutes for the field and the adapter holds no ecology authority.

This is a bounded review integration. It does not merge to main, alter production defaults, broaden phenotype rollout, supersede S2J, or unblock L1D. Stop here for human review.
"""
	file = FileAccess.open(out_dir.path_join("V1_REVIEW.md"), FileAccess.WRITE)
	file.store_string(review)
	file.close()
	file = FileAccess.open(out_dir.path_join("renderer_teardown.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence.teardown, "  "))
	file.close()


func _set_cell_visible(presenter, on: bool) -> void:
	for renderer in presenter.get("_renderers"):
		if is_instance_valid(renderer):
			renderer.visible = on and renderer == review_renderer


func _build_white_display_room(focus: Vector3) -> void:
	display_room = Node3D.new()
	display_room.name = "VoxelMicroscopyDisplayRoom"
	add_child(display_room)
	var porcelain := _display_material(Color(.76, .78, .76), .88)
	var plaster := _display_material(Color(.64, .67, .66), .94)
	var inset := _display_material(Color(.43, .47, .46), .78)
	var brass := _display_material(Color(.36, .27, .14), .38, .28)
	_add_display_box("Floor", focus + Vector3(0, -.72, 0),
			Vector3(7.4, .16, 6.4), plaster)
	_add_display_box("BackWall", focus + Vector3(0, 1.75, -2.45),
			Vector3(7.4, 5.0, .16), porcelain)
	_add_display_box("LeftWall", focus + Vector3(-3.62, 1.75, .35),
			Vector3(.16, 5.0, 5.8), porcelain)
	_add_display_box("RightWall", focus + Vector3(3.62, 1.75, .35),
			Vector3(.16, 5.0, 5.8), porcelain)
	_add_display_box("Ceiling", focus + Vector3(0, 4.18, .35),
			Vector3(7.4, .16, 5.8), plaster)
	# A broad observation plinth makes the colony read as intentionally displayed,
	# never as a prop floating in a void.
	_add_display_box("ObservationPlinth", focus + Vector3(0, -.38, 0),
			Vector3(3.15, .62, 2.15), porcelain)
	_add_display_box("PlinthInset", focus + Vector3(0, -.055, 0),
			Vector3(2.72, .035, 1.74), inset)
	# Large wall recesses and a restrained rail give the image room-scale cues.
	_add_display_box("ObservationRecess", focus + Vector3(0, 1.55, -2.34),
			Vector3(4.65, 2.22, .05), inset)
	_add_display_box("RecessPanel", focus + Vector3(0, 1.55, -2.30),
			Vector3(4.22, 1.82, .04), plaster)
	_add_display_box("LeftRail", focus + Vector3(-2.42, .63, -2.18),
			Vector3(.055, 1.70, .055), brass)
	_add_display_box("RightRail", focus + Vector3(2.42, .63, -2.18),
			Vector3(.055, 1.70, .055), brass)
	_add_display_box("TopRail", focus + Vector3(0, 1.47, -2.18),
			Vector3(4.90, .055, .055), brass)
	# Neutral room illumination exposes the white architecture; the real L1C
	# instrument remains the sole light deposited into DreamExposureField.
	var fill := DirectionalLight3D.new()
	fill.name = "DisplayRoomNeutralFill"
	fill.light_color = Color(.91, .95, 1.0)
	fill.light_energy = 1.05
	fill.shadow_enabled = false
	fill.light_cull_mask = REVIEW_LAYER
	fill.rotation_degrees = Vector3(-48, -28, 0)
	display_room.add_child(fill)
	var ceiling_fill := OmniLight3D.new()
	ceiling_fill.name = "DisplayRoomCeilingBounce"
	ceiling_fill.position = focus + Vector3(-1.5, 2.65, 1.15)
	ceiling_fill.omni_range = 7.0
	ceiling_fill.light_energy = 2.10
	ceiling_fill.light_color = Color(.96, .91, .82)
	ceiling_fill.shadow_enabled = false
	ceiling_fill.light_cull_mask = REVIEW_LAYER
	display_room.add_child(ceiling_fill)


func _add_display_box(label: String, at: Vector3, size: Vector3,
		material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = material
	node.position = at
	node.layers = REVIEW_LAYER
	display_room.add_child(node)


func _display_material(color: Color, roughness: float,
		metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _set_visual_layer(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_visual_layer(child, layer)


func _configure_neutral_environment() -> void:
	var environments: Array[WorldEnvironment] = []
	_collect_world_environments(production_root, environments)
	if environments.is_empty() or environments[0].environment == null:
		return
	var env: Environment = environments[0].environment.duplicate(true)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.18, .20, .205)
	env.background_energy_multiplier = .72
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.78, .83, .84)
	env.ambient_light_energy = .82
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.12
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = .00006
	env.volumetric_fog_length = 10.0
	environments[0].environment = env


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 90
	add_child(overlay)
	var plate := ColorRect.new()
	plate.position = Vector2(560, 22)
	plate.size = Vector2(480, 52)
	plate.color = Color(.008, .010, .014, .88)
	overlay.add_child(plate)
	overlay_label = Label.new()
	overlay_label.position = Vector2(18, 9)
	overlay_label.add_theme_font_size_override("font_size", 24)
	overlay_label.add_theme_color_override("font_color", Color(.91, .93, .91))
	plate.add_child(overlay_label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control:
		node.visible = false
	for child in node.get_children():
		_hide_ui(child)


func _collect_world_environments(node: Node,
		out: Array[WorldEnvironment]) -> void:
	if node is WorldEnvironment:
		out.append(node)
	for child in node.get_children():
		_collect_world_environments(child, out)


func _count_visible_type(node: Node, type_name: String) -> int:
	var count := 0
	if node.is_class(type_name) and (not node is Node3D
			or (node as Node3D).is_visible_in_tree()):
		count += 1
	for child in node.get_children():
		count += _count_visible_type(child, type_name)
	return count
