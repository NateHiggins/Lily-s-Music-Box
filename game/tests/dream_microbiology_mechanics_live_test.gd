extends Node
## MBIO-2 through the production root: real travel, shared bed, real organs.

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
	var director = enc.get("ecology") if enc != null else null
	var margin = enc.get("margin") if enc != null else null
	var critters = enc.get("critters") if enc != null else null
	_check("production owns the physical publisher and both recipients",
			player != null and director != null and margin != null and critters != null
			and player.has_signal("mechanical_stimulus"))
	if player == null or director == null or margin == null or critters == null:
		return _finish()
	_check("the ecology connected to physical contact independently of attention",
			player.mechanical_stimulus.is_connected(director.on_mechanical_stimulus)
			and player.world_modified.is_connected(director.on_world_modified))

	var cases_before := var_to_bytes(RealityState.data.get("cases", {}))
	var nodes_before := _node_count(root)
	var attention_before: Vector3 = director.attending
	var contacts: Array = []
	player.mechanical_stimulus.connect(func(where, carrier, strength, direction,
			duration, substrate): contacts.append({"where": where, "carrier": carrier,
			"strength": strength, "direction": direction, "duration": duration,
			"substrate": substrate}))
	var start: Vector3 = player.global_position
	player.autopilot = Vector3.RIGHT
	for _i in 180:
		await get_tree().physics_frame
		if not contacts.is_empty():
			break
	player.autopilot = Vector3.ZERO
	_check("actual collision-resolved travel produces a floor impulse",
			not contacts.is_empty() and player.global_position.distance_to(start) > 0.4
			and contacts[0].carrier == &"impulse"
			and contacts[0].substrate == &"floor")
	_check("the footfall enters the shared fixed signal bed",
			int(director.signal_census().by_function.get("pulse", 0)) >= 1)
	_check("walking never invokes the rare whole-body attention owner",
			director.attending == attention_before)

	if margin.palps.is_empty() or critters.critters.size() < 2:
		_check("production populated a cilium carpet and two fauna", false)
		return _finish()
	margin.set_physics_process(false)
	critters.set_physics_process(false)
	director.set_process(false)
	var at := Vector3(-9.0, 4.2, 3.2)
	var palp: Dictionary = margin.palps[0]
	palp.morph = DreamPalpMorphology.generate(
			DreamPalpMorphology.Kind.CILIATED_WHISKER, 82041)
	palp.cilia_out = 1.0
	palp.tip = at + Vector3(1.0, 0.0, 0.0)
	palp.normal = Vector3.UP
	palp.mechanical = Mechanics.state()
	var listener: Dictionary = critters.critters[0]
	listener.morph = DreamCritterGenerator.generate(
			DreamCritterSpecies.Kind.CRYSTAL_LISTENER, 82042)
	listener.pos = palp.tip
	listener.up = Vector3.UP
	listener.mechanical = Mechanics.state()
	listener.moving = true
	var crab: Dictionary = critters.critters[1]
	crab.morph = DreamCritterGenerator.generate(
			DreamCritterSpecies.Kind.FOLD_CRAB, 82043)
	crab.pos = palp.tip
	crab.up = Vector3.UP
	crab.mechanical = Mechanics.state()
	director.emit_mechanical_packet(91, at, 2.0, 0.75,
			DreamEcologyDirector.Carrier.IMPULSE, Vector3.RIGHT, 2.0,
			DreamEcologyDirector.Substrate.FLOOR, 2.0)
	margin._update_mechanoreception(palp, 0.05)
	critters._update_mechanoreception(listener, 0.05)
	_check("neither organ answers before the finite wavefront arrives",
			int(palp.mechanical.received) == 0
			and int(listener.mechanical.received) == 0)
	director._process(0.51)
	margin._update_mechanoreception(palp, 0.05)
	critters._update_mechanoreception(listener, 0.05)
	critters._update_mechanoreception(crab, 0.05)
	_check("deployed cilia feel the arrived floor impulse",
			int(palp.mechanical.received) == 1)
	_check("a crystal listener feels it and arrests its shell",
			int(listener.mechanical.received) == 1 and not bool(listener.moving))
	_check("a fold crab genuinely ignores the same packet",
			int(crab.mechanical.received) == 0)
	margin._update_mechanoreception(palp, 0.05)
	critters._update_mechanoreception(listener, 0.05)
	_check("held disturbance is refractory in both recipient families",
			int(palp.mechanical.received) == 1
			and int(listener.mechanical.received) == 1)
	_check("MBIO-2 creates no nodes, case fact or save seam",
			_node_count(root) == nodes_before
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
	print("[MBIO-2 LIVE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[MBIO-2 LIVE] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
