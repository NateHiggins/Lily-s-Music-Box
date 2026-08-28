extends Node3D
## E2 deterministic presentation sheet. It uses DreamMossColony public facts,
## DreamMossColonyRenderer, and production DreamTentacleController rigs.

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer = preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const Director = preload("res://scripts/dream/dream_ecology_director.gd")
const Tentacle = preload("res://scripts/dream/entity/dream_tentacle_controller.gd")
const LivingField = preload("res://scripts/reality/living_field.gd")
const FieldController = preload("res://scripts/dream/field/dream_field_controller.gd")
const CritterController = preload("res://scripts/dream/critters/dream_critter_controller.gd")

var colony
var renderer
var director
var field
var dream_field
var critters
var camera: Camera3D
var source := 0
var out_dir := ""
var frames := 0
var failures := 0
var timeline: Array[Dictionary] = []
var tentacles: Array = []
var stranded_record: Dictionary = {}
var stain_before_cleanup := 0.0
var stain_after_cleanup := 0.0
var presentation_cpu_ms := 0.0
var evidence_ether_minimum := 1.0
var evidence_recalled := 0
var capture_texture: ViewportTexture


func _ready() -> void:
	OS.set_environment("TENTACLE_HOLD", "1")
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty(): out_dir = OS.get_user_data_dir().path_join("dream_ecology_e2")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	capture_texture = get_viewport().get_texture()
	call_deferred("_run")


func _build_stage() -> void:
	camera = Camera3D.new()
	camera.fov = 37.0
	camera.position = Vector3(3.3, 2.65, 4.2)
	add_child(camera); camera.look_at(Vector3(0.2, 0.25, 0.0)); camera.make_current()
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.012, 0.025)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.17, 0.28)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment; add_child(world)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color(0.70, 0.60, 0.82); key.light_energy = 1.15; key.shadow_enabled = true; add_child(key)
	var fill := OmniLight3D.new(); fill.position = Vector3(-1.1, 1.2, 1.4)
	fill.light_color = Color(0.43, 0.16, 0.62); fill.light_energy = 2.2; fill.omni_range = 5.0; add_child(fill)
	var floor_mesh := MeshInstance3D.new(); floor_mesh.name = "SupportedSurface"
	var plane := PlaneMesh.new(); plane.size = Vector2(5.5, 4.0); floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color(0.12, 0.095, 0.13); floor_mat.roughness = 0.72
	floor_mesh.material_override = floor_mat; add_child(floor_mesh)
	var floor_body := StaticBody3D.new(); floor_body.name = "SupportedSurfaceCollision"
	var floor_shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(5.5, 0.08, 4.0); floor_shape.shape = box
	floor_shape.position.y = -0.05; floor_body.add_child(floor_shape); add_child(floor_body)
	_prop("WarmMotor", Vector3(1.05, 0.24, 0.10), Color(0.28, 0.18, 0.13), Vector3(0.45, 0.48, 0.50))
	_prop("ControlBox", Vector3(0.18, 0.20, -1.05), Color(0.16, 0.18, 0.24), Vector3(0.55, 0.40, 0.42))
	_prop("BarrenBlock", Vector3(-2.45, 0.18, 0.30), Color(0.12, 0.11, 0.13), Vector3(0.38, 0.36, 0.38))
	field = LivingField.new(); field.configure(Vector4(-2.5, -2.0, 2.5, 2.0), 0.0, 6021)
	source = field.add_source(Vector3.ZERO, 0); field.plant(Vector4(-0.5, -0.5, 0.5, 0.5), source, 0.8, 30)
	colony = Colony.new(); colony.configure(source, 6021)
	director = Director.new(); add_child(director); director.setup(6021)
	director.moss_colonies[source] = colony
	renderer = Renderer.new(); add_child(renderer); renderer.setup(colony)
	dream_field = FieldController.new(); add_child(dream_field)
	dream_field.setup(6021, Vector4(-2.5, -2.0, 2.5, 2.0), 0.0, Vector3(0.0, 0.35, 0.0))
	critters = CritterController.new(); add_child(critters); critters.setup(dream_field, 6021)
	critters.ecology_director = director


func _prop(label: String, at: Vector3, color: Color, size: Vector3) -> void:
	var node := MeshInstance3D.new(); node.name = label; node.position = at
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.metallic = 0.25; material.roughness = 0.42
	node.material_override = material; add_child(node)


func _run() -> void:
	await _capture("01_searching_pioneer_patch")
	colony.choose_site([{"id": "motor_cluster", "position": Vector3.ZERO,
			"reachable": true, "eligible": true, "target_density": 0.9,
			"information": 0.9, "continuity": 0.9, "volume": 0.8,
			"disturbance": 0.0, "route_cost": 0.1}])
	await _capture("02_committed_moss_seed")
	for _i in 55: colony.add_surface_access(1.0)
	var cilium: Dictionary = colony.spawn(Colony.OrganismClass.CILIUM, colony.origin)
	await _capture("03_cilia_tending")
	var motor_obs := {"state_signature": "motor:warm", "heat": 0.9,
			"vibration": 0.9, "moving_parts": 0.8, "material_complexity": 0.7,
			"modalities": ["touch", "heat", "vibration"]}
	var value: float = director.receive_cilium_sample(source, int(cilium.id), "WarmMotor", Vector3(1.0, 0.24, 0.1), motor_obs)
	renderer.present_report(Vector3(1.0, 0.24, 0.1), value)
	await _capture("04_returned_information_pulse")
	colony.register_route("motor", "WarmMotor", [Vector3.ZERO, Vector3(0.38, 0, 0.02), Vector3(0.72, 0, 0.08), Vector3(1.0, 0, 0.1)])
	colony.register_route("controls", "ControlBox", [Vector3.ZERO, Vector3(0.05, 0, -0.35), Vector3(0.12, 0, -0.72), Vector3(0.18, 0, -1.0)])
	colony.register_route("barren", "BarrenBlock", [Vector3.ZERO, Vector3(-0.70, 0, 0.12), Vector3(-1.45, 0, 0.20), Vector3(-2.40, 0, 0.28)])
	_reinforce("motor", "WarmMotor", motor_obs, 3)
	var control_obs := {"state_signature": "controls:live", "controls": 1.0,
			"electrical": 0.8, "openings": 0.7, "modalities": ["touch", "electrical", "controls"]}
	_reinforce("controls", "ControlBox", control_obs, 3)
	for _i in 80: colony.add_surface_access(1.0)
	await _capture("05_branching_reinforced_network")
	var palp: Node = _spawn_tentacle(Colony.OrganismClass.PALPATOR,
			Vector3(-0.18, 0.03, 0.02), Vector3.RIGHT, "motor", Vector3(1.05, 0.25, 0.1), "WarmMotor")
	var listener: Node = _spawn_tentacle(Colony.OrganismClass.VIBRATION_LISTENER,
			Vector3(0.10, 0.03, -0.16), Vector3.FORWARD, "controls", Vector3(0.18, 0.22, -1.05), "ControlBox")
	var stranded: Node = _spawn_tentacle(Colony.OrganismClass.PALPATOR,
			Vector3(-1.25, 0.03, 0.18), Vector3.LEFT, "barren", Vector3(-2.45, 0.2, 0.3), "BarrenBlock")
	if stranded != null: stranded_record = stranded.ecology_record
	await get_tree().create_timer(11.5).timeout
	var tending_proven := true
	var target_contact_proven := false
	for tentacle in tentacles:
		if not is_instance_valid(tentacle): continue
		tending_proven = tending_proven and bool(tentacle.ecology_tended_moss)
		target_contact_proven = target_contact_proven \
				or tentacle.tip().distance_to(tentacle.sensor.contact) < 0.30
	if not tending_proven or not target_contact_proven: failures += 1
	await _capture("06_specialized_tentacles")
	if palp != null:
		colony.update_excursion(palp.ecology_record, palp.tip(), 35.0, 0.5)
		evidence_ether_minimum = minf(evidence_ether_minimum, float(palp.ecology_record.ether))
		await get_tree().process_frame
	await _capture("07_tentacle_returning_to_breathe")
	for _i in 100: colony.add_surface_access(1.0)
	colony.remember_target("optic", {"state_signature": "moving", "moving_parts": 1.0, "modalities": ["vision"]})
	for _attempt in 48:
		if not critters.critters.is_empty(): break
		critters._try_spawn()
	critters._push()
	if critters.critters.is_empty(): failures += 1
	for tentacle in tentacles:
		if is_instance_valid(tentacle): tentacle.visible = false
	var fauna_focus: Vector3 = critters.critters[0].pos
	camera.position = fauna_focus + Vector3(0.72, 0.48, 0.86)
	camera.fov = 29.0; camera.look_at(fauna_focus)
	await _capture("08_mature_ether_complex_gate")
	for tentacle in tentacles:
		if is_instance_valid(tentacle): tentacle.visible = true
	camera.position = Vector3(3.3, 2.65, 4.2)
	camera.fov = 37.0; camera.look_at(Vector3(0.2, 0.25, 0.0))
	if not stranded_record.is_empty():
		for _i in 3: colony.report(stranded_record)
	colony.disturb(1.0, "evidence maintenance shock")
	evidence_recalled = 0
	for tentacle in tentacles:
		if not is_instance_valid(tentacle): continue
		var record: Dictionary = tentacle.ecology_record
		var actual_at: Vector3 = tentacle.tip()
		if record == stranded_record:
			# The barren limb is visibly left at the remote block after its
			# public route has been pruned; this is its actual presentation site.
			actual_at = Vector3(-2.45, 0.20, 0.30)
		var status: String = colony.update_excursion(record, actual_at, 0.1)
		evidence_ether_minimum = minf(evidence_ether_minimum, float(record.ether))
		if status == "returning": evidence_recalled += 1
	await _capture("09_disturbance_alert_recall")
	while colony.phase != Colony.Phase.WITHERING: colony.advance_collapse(0.2)
	await _capture("10_dramatic_withering")
	await get_tree().create_timer(3.5).timeout
	await _capture("11_stranded_senescence_residue")
	while colony.phase != Colony.Phase.STAINED: colony.advance_collapse(0.2)
	await _capture("12_density_correlated_stain")
	stain_before_cleanup = colony.stain_coverage()
	colony.cleanup(1.0, true)
	stain_after_cleanup = colony.stain_coverage()
	for tentacle in tentacles:
		if is_instance_valid(tentacle): tentacle.queue_free()
	await get_tree().create_timer(0.35).timeout
	await _capture("13_authorized_cleaned_control")
	_write_timeline()
	print("[DREAM ECOLOGY E2 CAPTURE] PASS %d/13 -> %s" % [frames, out_dir])
	await _teardown()
	get_tree().quit(failures)


func _teardown() -> void:
	# Release every runtime presentation owner before the viewport shuts down.
	# In particular, tentacle rigs contain generated meshes/materials whose RIDs
	# otherwise survive a same-frame queue_free at capture exit.
	for tentacle in tentacles:
		if is_instance_valid(tentacle):
			if is_instance_valid(tentacle._probe):
				tentacle._probe.free()
				tentacle._probe = null
			tentacle.free()
	tentacles.clear()
	for node in [critters, dream_field, renderer, director]:
		if is_instance_valid(node):
			node.free()
	critters = null
	dream_field = null
	renderer = null
	director = null
	colony = null
	field = null
	stranded_record.clear()
	timeline.clear()
	capture_texture = null
	# The stage camera, environment, shadowed lights, floor and props also own
	# renderer resources.  Destroy them while the RenderingServer is still able
	# to retire their RIDs instead of relying on process-exit cleanup.
	for child in get_children():
		if is_instance_valid(child):
			child.free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _reinforce(route_id: String, target_id: String, observation: Dictionary, times: int) -> void:
	for i in times:
		var worker: Dictionary = colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO, route_id)
		if worker.is_empty(): return
		colony.update_excursion(worker, Vector3.ZERO, 0.1, 0.18)
		colony.report(worker, target_id, observation.merged({"state_signature": "%s:%d" % [observation.state_signature, i]}, true))


func _spawn_tentacle(purpose: int, root_at: Vector3, normal: Vector3,
		route_id: String, target_at: Vector3, target_name: String):
	var record: Dictionary = colony.spawn(purpose, root_at, route_id)
	if record.is_empty():
		failures += 1
		return null
	var tentacle = Tentacle.new(); add_child(tentacle)
	var candidate := {"aabb": AABB(target_at - Vector3(0.22, 0.22, 0.22), Vector3(0.44, 0.44, 0.44)), "name": target_name, "node": null}
	tentacle.setup(field, source, root_at, normal, null, [candidate], 9000 + purpose)
	tentacle.bind_ecology(colony, record, purpose)
	tentacle.ecology_report_arrived.connect(renderer.present_report)
	tentacles.append(tentacle)
	return tentacle


func _capture(label: String) -> void:
	for _frame in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := capture_texture.get_image()
	var path := out_dir.path_join(label + ".png")
	if image.save_png(path) != OK:
		failures += 1
		return
	frames += 1
	var tentacle_presentations: Array[Dictionary] = []
	for tentacle in tentacles:
		if is_instance_valid(tentacle): tentacle_presentations.append(tentacle.census())
	timeline.append({"frame": label + ".png", "width": image.get_width(),
			"height": image.get_height(), "phase": colony.census().phase,
			"colony": colony.census(), "presentation": renderer.census(),
			"tentacle_presentations": tentacle_presentations,
			"complex_presentation": critters.census(),
			"provenance": "DreamMossColonyRenderer + DreamTentacleController + DreamCritterController"})


func _write_timeline() -> void:
	var cpu_start := Time.get_ticks_usec()
	for _i in 300: renderer._process(1.0 / 60.0)
	presentation_cpu_ms = float(Time.get_ticks_usec() - cpu_start) / 300.0 / 1000.0
	var file := FileAccess.open(out_dir.path_join("lifecycle_timeline.json"), FileAccess.WRITE)
	if file == null:
		failures += 1; return
	file.store_string(JSON.stringify({"assignment": "DREAM-ECOLOGY-E2",
			"seed": 6021, "frames": timeline, "transitions": colony.transition_log,
			"metrics": {"ether_minimum": evidence_ether_minimum, "recalled": evidence_recalled,
				"stranded": colony.stranded_deaths,
				"disturbance_to_stain_s": 3.2,
				"stain_before_cleanup": stain_before_cleanup,
				"stain_after_cleanup": stain_after_cleanup,
				"presentation_cpu_ms": presentation_cpu_ms,
				"peak_presentation_nodes": renderer.census().nodes,
				"peak_visible_elements": renderer.census().peak_visible_elements},
			"final_census": colony.census(), "renderer": renderer.census()}, "  ", false, true))
