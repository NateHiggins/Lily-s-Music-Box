extends Node
## MBIO-1 production-root ownership and recipient proof.

const MicroLight := preload("res://scripts/dream/dream_microbiology_light.gd")

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
	var margin = enc.get("margin") if enc != null else null
	var renderer = enc.get("palp_renderer") if enc != null else null
	var critters = enc.get("critters") if enc != null else null
	_check("production owns the player, margin, renderer and fauna recipients",
			player != null and margin != null and renderer != null and critters != null)
	if player == null or margin == null or renderer == null or critters == null:
		return _finish()
	_check("both recipients read one existing field lamp owner",
			margin.field == critters.field and margin.field.player != null
			and margin.field.player.has_method("lamp_pose")
			and not margin.field.player.lamp_pose().is_empty())
	_check("production populated both recipient families",
			margin.palps.size() > 0 and critters.critters.size() > 0)
	if margin.palps.is_empty() or critters.critters.is_empty():
		return _finish()

	var nodes_before := _node_count(root)
	var cases_before := var_to_bytes(RealityState.data.get("cases", {}))
	var pose: Dictionary = player.lamp_pose()
	_check("the real hand lamp publishes a live spatial pose",
			not pose.is_empty() and float(pose.energy) > 0.0
			and pose.has("origin") and pose.has("splash"))
	var target: Vector3 = (pose.origin as Vector3).lerp(pose.splash as Vector3, 0.82)

	# A real, already-deployed cilium carpet. Staging anatomy in the test does
	# not bypass the recipient: the production controller samples, adapts and
	# writes the production renderer's existing one-draw buffer.
	margin.set_physics_process(false)
	var palp: Dictionary = margin.palps[0]
	palp.morph = DreamPalpMorphology.generate(
			DreamPalpMorphology.Kind.CILIATED_WHISKER, 81041)
	palp.cilia_out = 1.0
	palp.tip = target
	palp.photo = MicroLight.state()
	var admitted_slow := 0
	for i in 36:
		var slow_pose := pose.duplicate()
		slow_pose.energy = float(pose.energy) * float(i + 1) / 36.0
		margin._lamp_pose = slow_pose
		var before := int(palp.photo.shocks)
		margin._update_photoreception(palp, 0.05)
		admitted_slow += int(palp.photo.shocks) - before
	_check("slow beam entry makes the cilium carpet scan without photoshock",
			admitted_slow == 0 and float(palp.photo.scan) > 0.0
			and float(palp.photo.adapted) > 0.05)
	palp.photo = MicroLight.state()
	margin._lamp_pose = pose
	margin._update_photoreception(palp, 0.05)
	_check("abrupt production-lamp onset photoshocks the deployed carpet",
			int(palp.photo.shocks) == 1 and float(palp.photo.shock) > 0.5)

	# The crystal listener answers through its own established impossible law:
	# the resonator reverses inside a shell that does not rotate.
	critters.set_physics_process(false)
	var listener: Dictionary = critters.critters[0]
	listener.morph = DreamCritterGenerator.generate(
			DreamCritterSpecies.Kind.CRYSTAL_LISTENER, 81042)
	listener.pos = target
	listener.photo = MicroLight.state()
	listener.spin = 1.0
	listener.moving = true
	var spin_before := float(listener.spin)
	critters._lamp_pose = pose
	critters._apply_law(listener, 0.05)
	_check("the listener reverses its internal resonator and arrests",
			float(listener.spin) < spin_before and not bool(listener.moving)
			and float(listener.unfold) > 0.3)
	var first_peak := float(listener.photo.shock)
	critters._lamp_pose = {}
	critters._apply_law(listener, 0.08)
	critters._lamp_pose = pose
	critters._apply_law(listener, 0.08)
	_check("immediate unreliable-lamp flicker is refractory",
			int(listener.photo.shocks) == 1)
	for i in 70:
		critters._apply_law(listener, 0.05)
	_check("sustained light adapts instead of becoming an endless alarm",
			float(listener.photo.adapted) > 0.45
			and float(listener.photo.response) < first_peak)
	for i in 34:
		critters._lamp_pose = {}
		critters._apply_law(listener, 0.05)
	critters._lamp_pose = pose
	critters._apply_law(listener, 0.05)
	_check("a later lamp step returns as a weaker photoshock",
			int(listener.photo.shocks) == 2
			and float(listener.photo.shock) < first_peak)

	critters._push()
	renderer._process(0.0)
	var palp_photo = renderer.material.get_shader_parameter("palp_photo")
	var critter_photo = critters.material.get_shader_parameter("critter_photo")
	_check("both responses reach their existing one-draw shader buffers",
			palp_photo is PackedVector4Array and critter_photo is PackedVector4Array
			and palp_photo.size() == 40 and critter_photo.size() == 12)
	_check("MBIO-1 creates no node, draw owner, case fact or save seam",
			_node_count(root) == nodes_before
			and renderer.census().surfaces == 1
			and critters.mesh_instance.mesh.get_surface_count() == 1
			and cases_before == var_to_bytes(RealityState.data.get("cases", {}))
			and not RealityState.persistence_enabled)
	_finish()


func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _node_count(child)
	return total


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[MBIO-1 LIVE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[MBIO-1 LIVE] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
