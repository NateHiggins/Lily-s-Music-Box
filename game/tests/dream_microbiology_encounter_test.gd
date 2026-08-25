extends Node
## MBIO-6: one production-root observation and communication sequence.

const MicroLight := preload("res://scripts/dream/dream_microbiology_light.gd")
const Mechanics := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(8.0).timeout
	var enc = root.get("apartment_encroachment")
	var player = root.get("player")
	var director: DreamEcologyDirector = enc.get("ecology") if enc != null else null
	var margin: DreamMarginController = enc.get("margin") if enc != null else null
	var renderer: DreamPalpRenderer = enc.get("palp_renderer") if enc != null else null
	var hero: DreamHeroTentacle = enc.get("hero") if enc != null else null
	_check("the production root supplies every established encounter owner",
			player != null and director != null and margin != null
			and renderer != null and hero != null and not enc.fields.is_empty())
	if player == null or director == null or margin == null or renderer == null \
			or hero == null or margin.palps.is_empty():
		return _finish()
	var cases_before := var_to_bytes(RealityState.data.get("cases", {}))
	var attention_before: Vector3 = director.attending
	var audio_before := int(director.cellular_audio.census().presented)

	# Put the real player on F02, a storey whose existing LivingField can receive
	# the later cilium answer. PlayerController's origin is at the feet.
	root.teleport_player("F02")
	for _i in 8:
		await get_tree().physics_frame
	player.set_lamp_enabled(true)
	player.pin_lamp_gutter_for_proof(1.0)
	for _i in 40:
		await get_tree().process_frame
	var settled_pose: Dictionary = player.lamp_pose()
	var target: Vector3 = (settled_pose.origin as Vector3).lerp(
			settled_pose.splash as Vector3, 0.42)

	margin.frozen = true
	var palp: Dictionary = margin.palps[0]
	palp.morph = DreamPalpMorphology.generate(
			DreamPalpMorphology.Kind.CILIATED_WHISKER, 8601)
	palp.morph.cilia = 1.0
	palp.cilia_out = 1.0
	palp.grow = 1.0
	palp.unfold = 1.0
	palp.tip = target
	palp.last_tip = target
	palp.normal = Vector3.UP
	palp.photo = MicroLight.state()
	palp.mechanical = Mechanics.state()

	# Darkness, then a slow scan made from the real lamp's spatial pose. The
	# gradual level lets adaptation follow, so it may steer but cannot shock.
	player.set_lamp_enabled(false)
	for _i in 60:
		await get_tree().process_frame
		if not player.flashlight.visible:
			break
	palp.photo = MicroLight.state()
	margin._lamp_pose = player.lamp_pose()
	margin._update_photoreception(palp, 0.08)
	_check("the encounter begins with a quiet dark receptor",
			not player.lamp_is_enabled() and not player.flashlight.visible
			and int(palp.photo.shocks) == 0 and float(palp.photo.level) < 0.001)
	for i in 36:
		var scan_pose := settled_pose.duplicate()
		scan_pose.energy = float(settled_pose.energy) * float(i + 1) / 36.0
		margin._lamp_pose = scan_pose
		margin._update_photoreception(palp, 0.05)
	_check("slow beam entry produces scanning without photoshock",
			int(palp.photo.shocks) == 0 and float(palp.photo.scan) > 0.0
			and float(palp.photo.adapted) > 0.05)
	for _i in 80:
		margin._lamp_pose = {}
		margin._update_photoreception(palp, 0.05)
	player.set_lamp_enabled(true)
	margin._lamp_pose = settled_pose
	margin._update_photoreception(palp, 0.05)
	var first_peak := float(palp.photo.shock)
	_check("the real lamp switch admits one abrupt photoshock",
			int(palp.photo.shocks) == 1 and first_peak > 0.5)
	for _i in 80:
		margin._update_photoreception(palp, 0.05)
	_check("sustained exposure adapts instead of holding alarm",
			float(palp.photo.adapted) > 0.45
			and float(palp.photo.response) < first_peak)

	# Let the real collision-resolved gait publish the next phase. Stop on the
	# first foot plant so the finite wavefront cannot cross our receptor while
	# the harness is waiting.
	var contacts: Array = []
	player.mechanical_stimulus.connect(func(where, carrier, strength, direction,
			duration, substrate): contacts.append({"where": where, "carrier": carrier,
			"strength": strength, "direction": direction, "duration": duration,
			"substrate": substrate}))
	player.autopilot = Vector3.RIGHT
	for _i in 180:
		await get_tree().physics_frame
		if not contacts.is_empty():
			break
	player.autopilot = Vector3.ZERO
	director.set_process(false)
	player.set_physics_process(false)
	_check("collision-resolved travel publishes a real floor impulse",
			not contacts.is_empty() and contacts[0].carrier == &"impulse"
			and contacts[0].substrate == &"floor")
	if contacts.is_empty():
		return _finish()
	var contact_at: Vector3 = contacts[0].where
	palp.tip = contact_at + Vector3.RIGHT
	palp.last_tip = palp.tip
	palp.normal = Vector3.UP
	palp.mechanical = Mechanics.state()
	margin._update_mechanoreception(palp, 0.02)
	_check("the cilium cannot answer ahead of the footfall wavefront",
			int(palp.mechanical.received) == 0)
	director._process(0.20)
	margin._update_mechanoreception(palp, 0.02)
	_check("the arrived impulse recruits one local cilium answer",
			int(palp.mechanical.received) == 1
			and float(palp.mechanical.response) > 0.1)
	var architecture_before := _vascular_response_total(enc)
	enc._receive_architecture_signals()
	_check("the cilium's finite answer enters existing living architecture",
			_vascular_response_total(enc) == architecture_before + 1)
	var audio_after_cilia := int(director.cellular_audio.census().presented)
	_check("only the biological answer, not the footfall, is sonified",
			audio_after_cilia == audio_before + 1
			and int(director.cellular_audio.census().by_kind.get(&"cilia", 0)) >= 1)

	var secretion_before := hero.secretion_events
	hero._emit_contact_signal(palp.tip)
	_check("later contact produces the real bounded vesicle sequence",
			hero.secretion_events == secretion_before + 1
			and hero.secretion_phase == 0.0
			and int(director.cellular_audio.census().by_kind.get(&"vesicle", 0)) >= 1)
	renderer._process(0.0)
	_check("the integrated order remains observation and communication",
			director.attending == attention_before
			and cases_before == var_to_bytes(RealityState.data.get("cases", {}))
			and not RealityState.persistence_enabled
			and root.find_children("*", "DreamPursuer", true, false).is_empty()
			and root.find_children("*", "DreamHazardGrowth", true, false).is_empty())
	print("[MBIO-6 TIMELINE] dark < scan < shock < adapt < footfall < cilia < architecture < vesicle")
	_finish()


func _vascular_response_total(enc) -> int:
	var total := 0
	for field in enc.fields.values():
		total += int(field.vascular_responses)
	return total


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[MBIO-6] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[MBIO-6] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
