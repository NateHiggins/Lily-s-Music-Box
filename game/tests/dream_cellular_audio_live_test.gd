extends Node
## MBIO-5 through the production Orison root.

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
	var director: DreamEcologyDirector = enc.get("ecology") if enc != null else null
	var pool: DreamCellularAudioPool = director.cellular_audio \
			if director != null else null
	_check("production owns one cellular layer for the encroachment",
			director != null and pool != null and pool.get_parent() == director)
	if pool == null:
		return _finish()
	var voices := pool.find_children("*", "AudioStreamPlayer3D", true, false)
	_check("the production layer contains four pooled positional voices",
			voices.size() == DreamCellularAudioPool.VOICE_CAP)
	var cases_before := var_to_bytes(RealityState.data.get("cases", {}))
	var nodes_before := _node_count(root)
	var presented_before := int(pool.census().presented)
	var at := Vector3(-8.0, 4.2, 2.4)
	director.emit_mechanical_packet(8500, at, 2.0, 0.8,
			DreamEcologyDirector.Carrier.IMPULSE, Vector3.RIGHT, 2.0,
			DreamEcologyDirector.Substrate.FLOOR, 2.0)
	_check("a real production mechanical packet makes no playback by itself",
			int(pool.census().presented) == presented_before)
	director.emit_signal_packet(8501, DreamEcologyDirector.SrcClass.CILIA,
			DreamEcologyDirector.Fn.PULSE, at + Vector3.RIGHT, 1.0, 0.8,
			DreamEcologyDirector.Chem.VASCULAR, 1.0, 1.0,
			DreamEcologyDirector.SrcClass.ARCHITECTURE)
	director.emit_signal_packet(8502, DreamEcologyDirector.SrcClass.HERO_LIMB,
			DreamEcologyDirector.Fn.SECRETE, at + Vector3.RIGHT * 2.0, 1.0, 0.9,
			DreamEcologyDirector.Chem.SECRETION, 1.0, 1.0,
			DreamEcologyDirector.SrcClass.PALP)
	var census: Dictionary = pool.census()
	_check("accepted production cellular facts use two voices and two languages",
			int(census.presented) == presented_before + 2
			and int(census.by_kind.get(&"cilia", 0)) >= 1
			and int(census.by_kind.get(&"vesicle", 0)) >= 1)
	_check("sonification adds no organelle node, case fact or save seam",
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
	print("[MBIO-5 LIVE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[MBIO-5 LIVE] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
