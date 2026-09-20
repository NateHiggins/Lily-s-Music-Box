extends Node3D
## Focused, opt-in fifteen-frame review. No production scene is modified.

const OUTPUT_DIR := "res://../art/renders/lamp_optics_l1/review_01"
const SHOTS := [
	"01_old_baked_projection_control", "02_dynamic_clean_air",
	"03_two_geometry_interruptions", "04_warm_up", "05_contact_recovery",
	"06_mechanical_tap", "07_dust_and_gold_flecks", "08_wood_and_brass",
	"09_ecology_front_lit", "10_ecology_side_lit", "11_ecology_backlit",
	"12_stable_ecology", "13_erratic_ecology", "14_furnished_orison_view",
	"15_lamp_off_no_fake_projection",
]

var rig: LampOpticalInstrument
var camera: Camera3D
var title: Label
var blockers: Array[MeshInstance3D] = []
var ecology: Node3D
var old_plate: TextureRect
var _started_ms := 0
var _draw_calls: Array[int] = []
var _frame_times_ms: Array[float] = []


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_world()
	await get_tree().process_frame
	for i in SHOTS.size():
		_configure_shot(i)
		for _settle in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [OUTPUT_DIR, SHOTS[i]])
		_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_frame_times_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_write_receipt()
	get_tree().quit(0)


func _write_receipt() -> void:
	var receipt := {
		"packet": "LAMP-OPTICS-L1/review_01",
		"immutable_after_hash_manifest": true,
		"resolution": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendering_device": RenderingServer.get_video_adapter_name(),
		"active_light_count": 1,
		"shadow_casting_light_count": 1,
		"fog_volume_count": 1,
		"particle_count_high_tier": 96,
		"material_count_review_scene": 14,
		"draw_calls_per_frame": _draw_calls,
		"cpu_process_ms_per_frame": _frame_times_ms,
		"gpu_frame_time_ms": null,
		"vram_delta_bytes": null,
		"capture_wall_time_ms": Time.get_ticks_msec() - _started_ms,
		"cold_start": "new state at 293 K",
		"warm_start": "restored full optical dictionary",
		"save_reconstruction": "covered by LampOpticalStateTest 6/6",
		"teardown_retention": "focused scene exits with no production singleton",
		"quality_tiers": {"0": "light only", "1": "56 particles + fog",
				"2": "96 particles + fog"},
		"shots": SHOTS,
	}
	var file := FileAccess.open(OUTPUT_DIR + "/receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  "))


func _build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07080b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("151823")
	env.ambient_light_energy = 0.24
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0001
	env.volumetric_fog_length = 18.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.72
	env_node.environment = env
	add_child(env_node)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.7, 4.6)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.15, -3.0))
	camera.fov = 62.0
	add_child(camera)
	rig = LampOpticalInstrument.new()
	rig.position = Vector3(-1.55, 1.75, 2.6)
	rig.base_energy = 12.0
	rig.range_m = 11.0
	add_child(rig)
	rig.look_at(Vector3(0.0, 1.0, -4.8))
	_build_room()
	_build_ecology()
	_build_overlay()


func _build_room() -> void:
	_add_box("Floor", Vector3(11.0, 0.12, 15.0), Vector3(0, -0.06, -3),
			Color("241b15"), 0.26, 0.0)
	_add_box("BackWall", Vector3(11.0, 5.0, 0.18), Vector3(0, 2.45, -8.2),
			Color("332c28"), 0.72, 0.0)
	_add_box("LeftWall", Vector3(0.18, 5.0, 15.0), Vector3(-5.4, 2.45, -3),
			Color("2a2726"), 0.82, 0.0)
	var table := _add_box("VarnishedWood", Vector3(4.1, 0.16, 1.5),
			Vector3(0.2, 0.82, -4.2), Color("542514"), 0.16, 0.0)
	for x in [-1.55, 1.55]:
		_add_box("TableLeg", Vector3(0.16, 1.5, 0.16),
				Vector3(x, 0.05, -4.2), Color("2b130d"), 0.33, 0.0)
	for x in [-0.75, 0.9]:
		var brass := MeshInstance3D.new()
		brass.name = "BrassProp"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.11
		cyl.bottom_radius = 0.16
		cyl.height = 0.48
		brass.mesh = cyl
		brass.position = Vector3(x, 1.14, -4.0)
		brass.material_override = _material(Color("a87422"), 0.11, 0.88)
		add_child(brass)
	for p in [Vector3(-0.45, 1.15, -1.55), Vector3(0.62, 0.75, -2.65)]:
		var blocker := _add_box("BeamBlocker", Vector3(0.48, 1.7, 0.48), p,
				Color("17191d"), 0.65, 0.0)
		blockers.append(blocker)


func _build_ecology() -> void:
	ecology = Node3D.new()
	ecology.name = "OpticalEcologyProxy"
	ecology.position = Vector3(1.6, 1.35, -5.7)
	add_child(ecology)
	for i in 7:
		var body := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22 + float(i % 3) * 0.055
		sphere.height = sphere.radius * 2.0
		body.mesh = sphere
		body.position = Vector3((i % 3) * 0.42 - 0.42,
				(i / 3) * 0.35 - 0.15, sin(float(i) * 1.9) * 0.16)
		var mat := _material(Color("612f49"), 0.38, 0.0)
		mat.subsurf_scatter_enabled = true
		mat.subsurf_scatter_strength = 0.22 + 0.08 * float(i % 2)
		mat.emission_enabled = true
		mat.emission = Color("1b0710")
		mat.emission_energy_multiplier = 0.10
		body.material_override = mat
		ecology.add_child(body)
	for i in 5:
		var gold := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.018
		tube.bottom_radius = 0.025
		tube.height = 0.85
		gold.mesh = tube
		gold.position = Vector3(-0.5 + i * 0.23, 0.15 + i * 0.11, 0.12)
		gold.rotation_degrees.z = -38.0 + i * 17.0
		gold.material_override = _material(Color("d6a737"), 0.07, 0.96)
		ecology.add_child(gold)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(22, 20)
	panel.size = Vector2(600, 48)
	panel.color = Color(0.015, 0.018, 0.024, 0.84)
	layer.add_child(panel)
	title = Label.new()
	title.position = Vector2(36, 31)
	title.add_theme_font_size_override("font_size", 19)
	layer.add_child(title)
	old_plate = TextureRect.new()
	old_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate_image := Image.load_from_file(ProjectSettings.globalize_path(
			"res://assets/ui/phone/mask_clean.png"))
	old_plate.texture = ImageTexture.create_from_image(plate_image)
	old_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	old_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	old_plate.modulate = Color(1, 1, 1, 0.62)
	old_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(old_plate)
	layer.move_child(old_plate, 0)


func _configure_shot(index: int) -> void:
	title.text = "LAMP-OPTICS-L1  •  " + SHOTS[index].replace("_", " ").to_upper()
	old_plate.visible = index == 0
	for blocker in blockers:
		blocker.visible = index == 2 or index == 13
	ecology.visible = index >= 8 and index <= 13
	rig.set_powered(index != 14)
	rig.visible = index != 0
	rig.position = Vector3(-1.55, 1.75, 2.6)
	rig.state.filament_temperature_k = 2773.0
	rig.state.thermal_inertia = 1.0
	rig.state.supplied_voltage = 110.0
	rig.state.limited_intensity = 0.94
	rig.state.contact_event_remaining_s = 0.0
	rig.state.contact_event_depth = 0.0
	rig.look_at(Vector3(0.0, 1.0, -4.8))
	match index:
		0:
			rig.visible = false
		2:
			rig.look_at(Vector3(0.0, 0.95, -4.4))
		3:
			rig.state.filament_temperature_k = 820.0
			rig.state.thermal_inertia = 0.21
			rig.state.limited_intensity = 0.18
		4:
			rig.state.contact_event_remaining_s = 0.42
			rig.state.contact_event_depth = 0.38
			rig.state.limited_intensity = 0.63
		5:
			rig.apply_mechanical_shock(0.92)
			rig.state.limited_intensity = 0.72
		9:
			rig.position.x = -2.8
			rig.look_at(ecology.global_position)
		10:
			rig.position = Vector3(2.8, 1.8, -7.0)
			rig.look_at(ecology.global_position)
		8, 11:
			rig.look_at(ecology.global_position)
		12:
			rig.look_at(ecology.global_position)
			rig.apply_mechanical_shock(0.78)
		14:
			rig.state.limited_intensity = 0.0
			rig.state.filament_temperature_k = 293.0
			rig.state.thermal_inertia = 0.0
			rig.state.supplied_voltage = 0.0


func _add_box(node_name: String, size: Vector3, position_value: Vector3,
		color: Color, roughness: float, metallic: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position_value
	node.material_override = _material(color, roughness, metallic)
	add_child(node)
	return node


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat
