extends Node3D
## Bounded Forward+ closure sheets.  This harness stages public deterministic
## ecology facts and photographs the production renderers; it owns no runtime
## simulation, targeting, cleanup, narrative, or persistence authority.

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer = preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const LivingField = preload("res://scripts/reality/living_field.gd")
const Tentacle = preload("res://scripts/dream/entity/dream_tentacle_controller.gd")
const Critters = preload("res://scripts/dream/critters/dream_critter_controller.gd")
const CritterGenerator = preload("res://scripts/dream/critters/dream_critter_generator.gd")
const CritterSpecies = preload("res://scripts/dream/critters/dream_critter_species.gd")

var camera: Camera3D
var colony
var renderer
var field
var tentacles: Array = []
var out_dir := ""
var frames := 0
var failures := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty() or not out_dir.is_absolute_path():
		get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	call_deferred("_run")


func _build_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.009, 0.018)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.23, 0.19, 0.28)
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment; add_child(world)
	camera = Camera3D.new(); camera.fov = 34.0; add_child(camera); camera.make_current()
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-54, -32, 0)
	key.light_color = Color(0.82, 0.76, 0.96); key.light_energy = 1.45; add_child(key)
	var back := OmniLight3D.new(); back.position = Vector3(-0.5, 0.65, -0.7)
	back.light_color = Color(0.34, 0.10, 0.52); back.light_energy = 3.1; back.omni_range = 3.0; add_child(back)
	var floor := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(4.0, 3.0)
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color(0.09, 0.075, 0.11); floor_mat.roughness = 0.82
	floor.mesh = plane; floor.material_override = floor_mat; add_child(floor)
	field = LivingField.new(); field.configure(Vector4(-2, -1.5, 2, 1.5), 0.0, 76123)
	var source: int = field.add_source(Vector3.ZERO, 0)
	field.plant(Vector4(-0.6, -0.6, 0.6, 0.6), source, 0.8, 30)
	colony = Colony.new(); colony.configure(source, 76123); colony.seed_at(Vector3.ZERO)
	renderer = Renderer.new(); add_child(renderer); renderer.setup(colony)


func _run() -> void:
	match OS.get_environment("S1F_MATRIX_MODE"):
		"tentacles": await _tentacle_matrix()
		"crystal": await _crystal_matrix()
		_: await _cellular_matrix()
	print("[S1F MATRIX] PASS %d -> %s" % [frames, out_dir])
	await _teardown()
	get_tree().quit(failures)


func _cellular_matrix() -> void:
	camera.position = Vector3(0.72, 0.48, 0.82); camera.look_at(Vector3(0, 0.08, 0))
	# One fixed subject/camera, with only public state facts changing.
	await _state("shared_01_previous_control", Colony.Phase.SEEDED, 0.18, 0.12, 0.0, 0.0)
	await _state("shared_02_neutral_membrane", Colony.Phase.TENDING, 0.42, 0.36, 0.2, 0.0)
	await _state("shared_03_phase_boundary", Colony.Phase.EXPLORING, 0.58, 0.48, 0.35, 0.0)
	await _state("shared_04_dic_directional", Colony.Phase.NETWORKED, 0.72, 0.62, 0.48, 0.0)
	await _state("shared_05_backlit_physiology", Colony.Phase.COMPLEX, 0.90, 0.84, 0.72, 0.0)
	renderer.present_report(Vector3(0.55, 0.10, 0.0), 1.0)
	await _state("shared_06_active_transport", Colony.Phase.COMPLEX, 1.0, 0.92, 1.0, 0.0)
	await _state("shared_07_disturbance", Colony.Phase.DISTURBED, 0.78, 0.42, 0.82, 0.28)
	await _state("shared_08_senescence", Colony.Phase.WITHERING, 0.42, 0.16, 1.0, 0.82)

	camera.position = Vector3(0.42, 0.24, 0.46); camera.look_at(Vector3(0, 0.045, 0))
	await _state("pioneer_01_thin_advancing_membrane", Colony.Phase.SEARCHING, 0.05, 0.08, 0.0, 0.0)
	await _state("pioneer_02_pseudopodial_edge", Colony.Phase.SEEDED, 0.14, 0.15, 0.05, 0.0)
	await _state("pioneer_03_edge_directed_flow", Colony.Phase.TENDING, 0.24, 0.26, 0.16, 0.0)
	await _state("pioneer_04_sparse_receptors", Colony.Phase.TENDING, 0.30, 0.31, 0.22, 0.0)
	await _state("pioneer_05_adhesion_plaques", Colony.Phase.EXPLORING, 0.38, 0.38, 0.28, 0.0)
	camera.position = Vector3(2.6, 1.75, 3.0); camera.look_at(Vector3.ZERO)
	await _state("pioneer_06_gameplay_phase_halo", Colony.Phase.EXPLORING, 0.38, 0.38, 0.28, 0.0)

	camera.position = Vector3(0.46, 0.30, 0.52); camera.look_at(Vector3(0, 0.06, 0))
	for i in 8: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	colony.register_route("radial_a", "a", [Vector3.ZERO, Vector3(0.35,0,0.05), Vector3(0.62,0,0.18)])
	colony.register_route("radial_b", "b", [Vector3.ZERO, Vector3(-0.28,0,0.18), Vector3(-0.55,0,0.30)])
	await _state("moss_01_membrane_folds", Colony.Phase.NETWORKED, 0.78, 0.74, 0.45, 0.0)
	await _state("moss_02_breathing_vacuoles", Colony.Phase.COMPLEX, 0.92, 0.90, 0.52, 0.0)
	await _state("moss_03_radial_transport", Colony.Phase.COMPLEX, 0.94, 0.92, 0.82, 0.0)
	renderer.present_report(Vector3(0.58,0.08,0.16), 1.0); await _capture("moss_04_report_rosette")
	await _capture("moss_05_rooted_ciliary_garden")
	await _state("moss_06_information_accumulation", Colony.Phase.COMPLEX, 1.0, 0.95, 1.0, 0.0)
	await _state("moss_07_low_ether", Colony.Phase.COMPLEX, 0.92, 0.08, 0.78, 0.0)
	await _state("moss_08_disturbance", Colony.Phase.DISTURBED, 0.80, 0.34, 0.74, 0.30)
	await _state("moss_09_senescence", Colony.Phase.WITHERING, 0.55, 0.12, 0.92, 0.78)
	await _state("moss_10_residue_transition", Colony.Phase.STAINED, 0.20, 0.0, 1.0, 1.0)

	# Fixed-camera protein sequence; count/organization follow information,
	# report, contact and senescence facts in the production renderer.
	camera.position = Vector3(0.31, 0.18, 0.34); camera.look_at(Vector3(0,0.05,0))
	await _state("proteins_01_confined_diffusion", Colony.Phase.NETWORKED, 0.7, 0.65, 0.18, 0.0)
	await _state("proteins_02_temporary_clustering", Colony.Phase.COMPLEX, 0.85, 0.75, 0.72, 0.0)
	renderer.present_report(Vector3(0.28,0.05,0), 0.55); await _capture("proteins_03_gate_opening")
	await _capture("proteins_04_compartment_hop")
	colony.disturbance = 0.45; renderer.present_report(Vector3(0.18,0.05,0.16), 0.85); await _capture("proteins_05_contact_recruitment")
	colony.reports = 8; renderer.present_report(Vector3(-0.22,0.05,0.12), 1.0); await _capture("proteins_06_reporting_reorganization")
	await _state("proteins_07_senescent_misclustering", Colony.Phase.WITHERING, 0.48, 0.10, 1.0, 0.88)

	await _state("senescence_01_ciliary_decoherence", Colony.Phase.DISTURBED, 0.72, 0.35, 0.75, 0.22)
	await _state("senescence_02_transport_arrest", Colony.Phase.WITHERING, 0.65, 0.25, 0.85, 0.42)
	await _state("senescence_03_protein_misclustering", Colony.Phase.WITHERING, 0.58, 0.18, 1.0, 0.58)
	await _state("senescence_04_cytoplasmic_slowdown", Colony.Phase.WITHERING, 0.48, 0.12, 1.0, 0.70)
	await _state("senescence_05_vacuole_failure", Colony.Phase.WITHERING, 0.38, 0.08, 1.0, 0.82)
	await _state("senescence_06_membrane_clouding", Colony.Phase.WITHERING, 0.28, 0.04, 1.0, 0.92)
	await _state("senescence_07_conduction_failure", Colony.Phase.STAINED, 0.15, 0.0, 1.0, 1.0)
	await _capture("senescence_08_pigment_coagulation")
	await _capture("senescence_09_ghost_network")
	await _state("senescence_10_authorized_cleanup", Colony.Phase.CLEARED, 0.0, 0.0, 0.0, 1.0)


func _state(label: String, phase: int, maturity: float, ether: float,
		information: float, collapse: float) -> void:
	colony.phase = phase; colony.maturity = maturity; colony.extent = 0.18 + maturity * 1.3
	colony.ether_reserve = ether; colony.ether_production = ether * 0.35
	colony.connected_ether_volume = ether * 2.2; colony.stored_information = information * 8.0
	colony.disturbance = 0.75 if phase == Colony.Phase.DISTURBED else 0.0
	colony.collapse_progress = collapse
	renderer._refresh(true)
	await _capture(label)


func _tentacle_matrix() -> void:
	renderer.visible = false
	var purposes := [
		["tactile", Colony.OrganismClass.PALPATOR],
		["chemical", Colony.OrganismClass.SUCKER_SAMPLER],
		["thermal", Colony.OrganismClass.MANIPULATOR],
		["vibrational", Colony.OrganismClass.VIBRATION_LISTENER],
		["optical", Colony.OrganismClass.OCULAR_EXAMINER],
		["electrical", Colony.OrganismClass.RELAY_TENDRIL],
	]
	colony.maturity = 1.0; colony.ether_reserve = 1.0; colony.phase = Colony.Phase.COMPLEX
	for i in purposes.size():
		var purpose: int = purposes[i][1]
		var record: Dictionary = colony.spawn(purpose, Vector3.ZERO)
		var tentacle = Tentacle.new(); add_child(tentacle)
		var target := Vector3(0.75, 0.18, 0.0)
		var candidate := {"aabb": AABB(target-Vector3.ONE*0.12,Vector3.ONE*0.24),"name":"evidence_target","node":null}
		tentacle.setup(field, colony.source_id, Vector3.ZERO, Vector3.RIGHT, null, [candidate], 7700 + i)
		# Let the production emergence/orientation owner establish full anatomy
		# before binding the evidence ecology packet and freezing simulation.
		for _step in 180: tentacle._tick(1.0 / 60.0)
		tentacle.bind_ecology(colony, record, purpose)
		tentacle.set_process(false)
		tentacle._push_uniforms()
		tentacles.append(tentacle)
		for other in tentacles: other.visible = other == tentacle
		camera.position = Vector3(1.05, 0.58, 1.05); camera.look_at(Vector3(0.34,0.12,0))
		await _capture("%s_01_silhouette" % purposes[i][0], 24)
		camera.position = Vector3(0.58, 0.30, 0.52); camera.look_at(Vector3(0.28,0.10,0))
		await _capture("%s_02_surface_macro" % purposes[i][0], 18)
		tentacle.exploration_state = tentacle.ExplorationState.SURFACE_CONTACT
		tentacle.grip = 0.8; tentacle.exchange_flash = 0.65
		tentacle._push_uniforms()
		await _capture("%s_03_active_sensing" % purposes[i][0], 18)
		tentacle.ecology_record.information = 1.0
		tentacle.exploration_state = tentacle.ExplorationState.INFORMATION_RETURN
		tentacle._push_uniforms()
		await _capture("%s_04_internal_report_transport" % purposes[i][0], 18)
		camera.position = Vector3(3.2, 1.65, 3.3); camera.look_at(Vector3(0.3,0.12,0))
		await _capture("%s_05_gameplay_distance" % purposes[i][0], 8)


func _crystal_matrix() -> void:
	renderer.visible = false
	var controller = Critters.new(); add_child(controller); controller.setup(null, 78119)
	var morph: Dictionary = CritterGenerator.generate(CritterSpecies.Kind.CRYSTAL_LISTENER, 78119)
	morph.length = 0.16; morph.wide = 0.16; morph.tall = 0.14; morph.feelers = 12; morph.crystal = 0.95
	var crystal := {"id":1,"morph":morph,"pos":Vector3(0,0.09,0),"up":Vector3.UP,
		"fwd":Vector3.FORWARD,"gait":0.0,"alive":1.0,"moving":false,"leg_state":[],
		"support_legs":0,"leg_root_gap_max":0.0,"twin":false,"spin":0.0,"photo":{},
		"photo_side":0.0,"mechanical":{"response":0.0,"carrier":0,"age":99.0,"direction":Vector3.ZERO,"received":0},
		"fold_leg":0,"fold":0.0,"unfold":0.0,"manipulator_deploy":0.0,
		"information_pulse":0.0,"ecology_repeat_count":0}
	controller.critters.append(crystal); controller._push()
	camera.position = Vector3(0.46,0.28,0.52); camera.look_at(Vector3(0,0.08,0))
	await _capture("crystal_01_grown_membrane_mineral")
	await _capture("crystal_02_ordered_protein_lattice")
	crystal.mechanical.response = 0.75; crystal.mechanical.carrier = 2; crystal.mechanical.age = 0.15; controller._push()
	await _capture("crystal_03_resonance_node_cilia")
	crystal.spin = 1.2; controller._push(); await _capture("crystal_04_internal_standing_wave")
	crystal.unfold = 0.65; controller._push(); await _capture("crystal_05_birefringent_response")
	crystal.mechanical.carrier = 1; crystal.mechanical.response = 1.0; controller._push(); await _capture("crystal_06_frequency_signal_band")
	crystal.information_pulse = 1.0; controller._push(); await _capture("crystal_07_information_return")
	camera.position = Vector3(2.8,1.4,3.0); camera.look_at(Vector3(0,0.08,0)); await _capture("crystal_08_gameplay_distance")


func _capture(label: String, settle_frames := 8) -> void:
	for _i in settle_frames: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_dir.path_join(label + ".png"))
	if error == OK: frames += 1
	else: failures += 1


func _teardown() -> void:
	for tentacle in tentacles:
		if is_instance_valid(tentacle) and is_instance_valid(tentacle._probe):
			tentacle._probe.free(); tentacle._probe = null
	for child in get_children():
		if is_instance_valid(child): child.free()
	tentacles.clear(); renderer = null; colony = null; field = null; camera = null
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
