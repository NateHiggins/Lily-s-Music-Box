extends Node3D
## Split E3A close proof. E3A_MODE selects one short packet so no run exceeds
## the capture ceiling; every frame uses the production one-draw crab renderer.

const Critters = preload("res://scripts/dream/critters/dream_critter_controller.gd")
const Generator = preload("res://scripts/dream/critters/dream_critter_generator.gd")
const Species = preload("res://scripts/dream/critters/dream_critter_species.gd")

var controller
var crab: Dictionary
var camera: Camera3D
var out_dir := ""
var frames := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	print("[E3A SHOT] building close stage")
	camera = Camera3D.new(); camera.fov = 25.0; add_child(camera); camera.make_current()
	var world := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.045, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.31, 0.46)
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment; add_child(world)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-52, -34, 0)
	key.light_color = Color(0.85, 0.76, 0.96); key.light_energy = 1.65; add_child(key)
	var rim := OmniLight3D.new(); rim.position = Vector3(-0.65, 0.75, -0.65)
	rim.light_color = Color(0.40, 0.12, 0.60); rim.light_energy = 3.4; rim.omni_range = 3.0; add_child(rim)
	var floor := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(2.4, 2.0)
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color(0.13, 0.115, 0.15); floor_mat.roughness = 0.8
	floor.mesh = plane; floor.material_override = floor_mat; add_child(floor)
	# Ten-centimetre scale reference, deliberately non-luminous.
	for i in 4:
		var tick := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(0.008, 0.008, 0.10)
		tick.mesh = box; tick.position = Vector3(-0.38 + i * 0.10, 0.006, -0.42); tick.material_override = floor_mat; add_child(tick)
	controller = Critters.new(); add_child(controller); print("[E3A SHOT] building production batch"); controller.setup(null, 4401)
	print("[E3A SHOT] production batch ready")
	var morph: Dictionary = Generator.generate(Species.Kind.FOLD_CRAB, 4401)
	crab = {"id": 1, "morph": morph, "pos": Vector3(0, float(morph.tall) * 0.52, 0),
			"up": Vector3.UP, "fwd": Vector3.FORWARD, "gait": 0.0, "alive": 1.0,
			"moving": false, "leg_state": [], "support_legs": 0, "leg_root_gap_max": 0.0,
			"twin": false, "spin": 0.0, "photo": {}, "photo_side": 0.0, "mechanical": {},
			"fold_leg": 2, "fold": 0.0, "unfold": 0.0, "manipulator_deploy": 0.0,
			"information_pulse": 0.0, "ecology_repeat_count": 0}
	controller.critters.append(crab)
	for _i in 4: controller._advance_crab_gait(crab, 1.0 / 30.0)
	controller._push()
	print("[E3A SHOT] specimen ready")


func _run() -> void:
	print("[E3A SHOT] capture mode starting")
	match OS.get_environment("E3A_MODE"):
		"anatomy": await _anatomy()
		"gait": await _gait()
		"examination": await _examination()
		"fold": await _fold()
		_: await _anatomy()
	print("[E3A SHOT] %s PASS %d -> %s" % [OS.get_environment("E3A_MODE"), frames, out_dir])
	get_tree().quit(0)


func _look(offset: Vector3, at := Vector3(0, 0.07, 0)) -> void:
	camera.position = at + offset; camera.look_at(at)


func _anatomy() -> void:
	var shots := [
		["A01_dorsal_three_quarter", Vector3(0.38, 0.28, 0.48)],
		["A02_ventral_three_quarter", Vector3(0.40, -0.10, 0.45)],
		["A03_direct_underside", Vector3(0.0, -0.48, 0.02)],
		["A04_side_silhouette", Vector3(0.58, 0.08, 0.0)],
		["A05_front_sensory_crown", Vector3(0.0, 0.10, 0.56)],
		["A06_rear_transfer_rosette", Vector3(0.0, 0.08, -0.56)],
		["A07_socket_joint_close", Vector3(0.30, 0.10, 0.22)],
		["A08_foot_pad_close", Vector3(0.34, 0.05, -0.28)]]
	for shot in shots:
		_look(shot[1]); await _capture(shot[0])
	crab.manipulator_deploy = 1.0; crab.unfold = 1.0; controller._push()
	_look(Vector3(0.20, 0.06, -0.48), Vector3(0.0, 0.045, 0.0)); await _capture("A09_manipulator_deployed")
	crab.manipulator_deploy = 0.0; crab.unfold = 0.0; controller._push()
	await _capture("A10_manipulator_folded")


func _gait() -> void:
	_look(Vector3(0.52, 0.23, 0.48)); crab.moving = true
	for shot in ["B01_three_plus_supports", "B02_early_swing", "B03_mid_swing_clearance",
			"B04_foot_placement", "B05_weight_transfer"]:
		crab.gait = float(crab.gait) + 0.42
		controller._advance_crab_gait(crab, 1.0 / 24.0); controller._push(); await _capture(shot)
	crab.morph.turn_bias = 0.9; crab.gait = float(crab.gait) + 0.55
	controller._advance_crab_gait(crab, 1.0 / 24.0); controller._push(); await _capture("B06_turn_asymmetry")
	crab.moving = false; controller._advance_crab_gait(crab, 0.2); controller._push(); await _capture("B07_settled_stop")


func _examination() -> void:
	_look(Vector3(0.44, 0.18, 0.50))
	var states := [
		["C01_approach", 0.0, 0.0, 0.0], ["C02_sensory_opening", 0.35, 0.15, 0.0],
		["C03_manipulator_contact", 0.75, 0.65, 0.0], ["C04_palpation", 1.0, 1.0, 0.15],
		["C05_information_acquisition", 1.0, 1.0, 1.0], ["C06_withdrawal", 0.35, 0.25, 0.65],
		["C07_return_deposit", 0.0, 0.0, 1.0]]
	for row in states:
		crab.unfold = row[1]; crab.manipulator_deploy = row[2]; crab.information_pulse = row[3]
		controller._push(); await _capture(row[0])


func _fold() -> void:
	_look(Vector3(0.42, 0.22, 0.46))
	crab.fold = 0.0; crab.unfold = 0.0; controller._push(); await _capture("D01_unfolded_control")
	crab.fold = 1.0; crab.unfold = 1.0; controller._push(); await _capture("D02_folded_same_camera")


func _capture(label: String) -> void:
	for _i in 5: await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image.save_png(out_dir.path_join(label + ".png")) == OK: frames += 1
