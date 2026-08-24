extends Node
## DO-2 production proof: one local conversation, held at causal milestones.
const StageScript := preload("res://tests/dream_stage.gd")

var stage
var out_dir := ""
var at := Vector3(-1.72, 1.20, 0.92)


func _ready() -> void:
	stage = StageScript.new()
	add_child(stage)
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://dream_organelle_signal"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


func _capture(label: String) -> void:
	stage.palps._process(0.0)
	stage.critters._push()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[organelle shot] %s  %s" % [label, stage.director.signal_census()])


func _run() -> void:
	var warm := 8.0
	if not OS.get_environment("SHOT_WARM").is_empty():
		warm = maxf(3.0, OS.get_environment("SHOT_WARM").to_float())
	stage.camera.global_position = Vector3(0.05, 1.54, -0.12)
	stage.camera.look_at(Vector3(-1.95, 1.18, 0.90), Vector3.UP)
	stage.lamp.light_energy = 4.2
	await get_tree().create_timer(warm).timeout
	if stage.margin.palps.size() < 3 or stage.critters.critters.size() < 2:
		printerr("[organelle shot] insufficient population")
		get_tree().quit(2)
		return

	# Hold the simulation, not the renderers. This makes every change below a
	# response we placed through the production owner rather than ambient drift.
	stage.margin.frozen = true
	stage.critters.enabled = false
	stage.hero.set_process(false)
	var palps: Array = [stage.margin.palps[0], stage.margin.palps[1],
			stage.margin.palps[2]]
	for i in palps.size():
		var p: Dictionary = palps[i]
		p.anchor = Vector3(-2.88, 0.92 + float(i) * 0.25, 0.58 + float(i) * 0.28)
		p.normal = Vector3.RIGHT
		p.side = Vector3.FORWARD
		p.tip = p.anchor + Vector3(0.72, 0.03 * float(i - 1), 0.08 * float(i - 1))
		p.last_tip = p.tip
		p.aim = (p.tip as Vector3) - (p.anchor as Vector3)
		p.aim = (p.aim as Vector3).normalized()
		p.extend = 1.0
		p.grow = 1.0
		p.target = Vector3.INF
		p.contact = 0.0
		p.attend_override = Vector3.INF
		p.local_look = false
		p.morph.length = 0.78
		p.morph.base_radius = 0.055 if i == 0 else 0.040
		if i == 2:
			# Present from the control onward: the response is the same fixed
			# cilia closing to sample, never new anatomy appearing for the beat.
			p.parent = int(palps[0].id)
			p.unfold = 1.0
			p.cilia_out = 1.0
			p.cilia_band = 0.62
			p.morph.cilia = 1.0
			p.task_done = false
			p.cilia_signal_clock = -1.0
	var social: Dictionary = stage.critters.critters[0]
	for candidate in stage.critters.critters:
		if int(candidate.morph.kind) == DreamCritterSpecies.Kind.CRYSTAL_LISTENER:
			social = candidate
			break
	var solitary: Dictionary = stage.critters.critters[1] \
			if stage.critters.critters[1] != social else stage.critters.critters[0]
	social.pos = Vector3(-1.72, 1.20, 1.24)
	social.up = Vector3.UP
	social.fwd = Vector3.FORWARD
	social.morph.sociability = 0.82
	# A canonical rare listener at the top of its authored size/count bounds,
	# selected so receptor presentation survives a gameplay-distance frame.
	social.morph.length = 0.13
	social.morph.wide = 0.13
	social.morph.tall = 0.12
	social.morph.feelers = 12
	social.unfold = 0.0
	solitary.pos = Vector3(-1.52, 1.20, 1.40)
	solitary.up = Vector3.UP
	solitary.fwd = Vector3.FORWARD
	solitary.morph.sociability = 0.18
	solitary.unfold = 0.0

	await _capture("00_control_A")
	await _capture("00_control_A_repeat")

	stage.hero._emit_contact_signal(at)
	await _capture("01_hero_secretes")

	var receptor: Dictionary = palps[0]
	receptor.target = at
	receptor.signal_target = at
	receptor.act = DreamPalpBehavior.Act.PROBE
	receptor.tip = at + Vector3(-0.16, 0.0, 0.0)
	receptor.aim = ((receptor.tip as Vector3) - (receptor.anchor as Vector3)).normalized()
	await _capture("02_palp_probes")

	receptor.tip = at
	receptor.aim = ((receptor.tip as Vector3) - (receptor.anchor as Vector3)).normalized()
	receptor.contact = 1.0
	stage.margin._recognize_signal_target(receptor, 0.0)
	await _capture("03_contact_recognized")

	stage.critters._answer_recognition_signal(social, 0.24)
	stage.critters._answer_recognition_signal(solitary, 0.24)
	await _capture("04_fauna_presents_receptors")

	stage.director._process(0.46)
	for i in [1, 2]:
		var neighbour: Dictionary = palps[i]
		var to_at: Vector3 = at - (neighbour.anchor as Vector3)
		neighbour.attend_override = at
		neighbour.local_look = true
		neighbour.act = DreamPalpBehavior.Act.WATCH
		neighbour.tip = (neighbour.anchor as Vector3) + to_at.normalized() * 0.78
		neighbour.aim = ((neighbour.tip as Vector3) - (neighbour.anchor as Vector3)).normalized()
	receptor.signal_orient_due = stage.director.signal_time()
	stage.margin._propagate_signal_answer(receptor)
	await _capture("05_neighbours_answer")

	var sampler: Dictionary = palps[2]
	stage.margin._sample_signal_with_cilia(sampler, 0.0)
	stage.director._process(DreamMarginController.CILIA_SIGNAL_SAMPLE_S * 0.5)
	stage.margin._sample_signal_with_cilia(sampler,
			DreamMarginController.CILIA_SIGNAL_SAMPLE_S * 0.5)
	await _capture("06_cilia_samples")
	stage.director._process(DreamMarginController.CILIA_SIGNAL_SAMPLE_S * 0.55)
	stage.margin._sample_signal_with_cilia(sampler,
			DreamMarginController.CILIA_SIGNAL_SAMPLE_S * 0.55)
	await _capture("07_cilia_returns_vascular_pulse")

	print("[organelle shot] DONE -> %s" % out_dir)
	get_tree().quit(0)
