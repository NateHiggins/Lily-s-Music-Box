extends Node
## LC-6C production ownership proof: the real Orison encroachment connects the
## modelled hero's cross-sectional death to the existing residue owner.

var checks := 0
var failures := 0
var root: Node3D


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[LC6C LIVE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


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
	_check("the production encroachment exists", enc != null)
	if enc == null:
		return _finish()
	var hero = enc.get("hero")
	var residue = enc.get("residue")
	_check("production owns the modelled hero and shared residue",
			hero != null and residue != null)
	if hero == null or residue == null:
		return _finish()
	var case_before := JSON.stringify(RealityState.case_state("mina"))
	var root_nodes := _node_count(root)
	var surfaces: int = hero.materials.size()
	var memories_before := int(residue.census().get("memories", 0))
	hero.set_process(false)
	residue.set_process(false)
	hero._exchanged_this_life = true
	hero._complete_lifecycle()
	var c: Dictionary = hero.census()
	var rc: Dictionary = residue.census()
	_check("the live hero reports pansexual cross-class exchange",
			str(c.lifecycle_reproduction) == "pansexual")
	_check("production routes one death to one architectural sheath",
			int(c.lifecycle_deaths) == 1 and int(c.lifecycle_stains) == 1
			and int(rc.memories) == memories_before + 1)
	residue._process(10000.0)
	_check("the production sheath persists for the visit",
			int(residue.census().memories) == memories_before + 1)
	_check("the exchange creates no node or surface owner",
			_node_count(root) == root_nodes and hero.materials.size() == surfaces)
	_check("the exchange changes no waking case or save owner",
			JSON.stringify(RealityState.case_state("mina")) == case_before
			and not RealityState.persistence_enabled)
	_finish()


func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _node_count(child)
	return total


func _finish() -> void:
	print("[LC6C LIVE] %d/%d PASS" % [checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
