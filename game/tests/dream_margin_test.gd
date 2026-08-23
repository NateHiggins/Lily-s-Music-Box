extends Node
## Ecology architecture §4, §5, §6, §7, §37 — the margin is a living border.
##     godot --headless --path game res://tests/DreamMarginTest.tscn
var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var enc: Node = root.get("apartment_encroachment")
	_check("the encroachment exists", enc != null)
	if enc == null:
		return _finish()
	var margin: DreamMarginController = enc.get("margin")
	_check("the field carries a DreamMarginController", margin != null)
	if margin == null:
		return _finish()
	# Let the border populate.
	await get_tree().create_timer(9.0).timeout
	var c: Dictionary = margin.census()
	print("[margin] %s" % [c])
	_check("appendages are born on real surfaces (%d live, %d born)"
			% [int(c.live), int(c.born)], int(c.born) >= 6)
	# --- §29: the population is TIERED, not uniform ----------------------
	var tiers: Array = c.tiers
	_check("the population is tiered, not one size (%s)" % [tiers],
			int(tiers[0]) <= DreamMarginController.TIER_CAPS[0]
			and int(tiers[1]) <= DreamMarginController.TIER_CAPS[1]
			and int(tiers[2]) <= DreamMarginController.TIER_CAPS[2])
	# --- §5/§37: ARCHETYPES ARE DISTINCT ---------------------------------
	# The acceptance test is that appendages differ in silhouette and
	# function, NOT in colour. So compare the things that make a silhouette:
	# the authored cross-section progression, and the distal specialisation.
	var seen := {}
	for p in margin.palps:
		seen[p.morph.name_of_kind()] = true
	print("[margin] archetypes present: %s" % [seen.keys()])
	_check("several different archetypes are alive at once (%d)" % seen.size(),
			seen.size() >= 3)
	# Every archetype must be generable and must differ from every other in
	# its section progression — this is the "no procedural oatmeal" rule.
	var sigs := {}
	for kind in DreamPalpMorphology.Kind.values():
		var m = DreamPalpMorphology.generate(kind, 4242 + kind)
		var sig := ""
		for s in m.sections:
			sig += "%.2f/%.0f/%.2f " % [s.x, s.y, s.z]
		sigs[m.name_of_kind()] = sig
	var distinct := {}
	for k in sigs:
		distinct[sigs[k]] = true
	_check("all %d archetypes have distinct cross-section progressions (%d unique)"
			% [sigs.size(), distinct.size()], distinct.size() == sigs.size())
	# --- §10 of the menagerie brief: the far end is specialised ----------
	var distals := {}
	for kind in DreamPalpMorphology.Kind.values():
		var m = DreamPalpMorphology.generate(kind, 99 + kind)
		distals[m.distal_specialisation()] = true
	print("[margin] distal specialisations: %s" % [distals.keys()])
	_check("archetypes specialise their far ends differently (%d kinds)"
			% distals.size(), distals.size() >= 5)
	# --- §6: variation inside the archetype, never across it -------------
	var lens: Array = []
	var flats: Array = []
	for i in 12:
		var m = DreamPalpMorphology.generate(DreamPalpMorphology.Kind.FLAT_RIBBON, 700 + i)
		lens.append(m.length)
		flats.append(float(m.sections[2].x))
	var lo: float = lens.min()
	var hi: float = lens.max()
	_check("individuals of one archetype vary (%.3f .. %.3f m)" % [lo, hi],
			hi - lo > 0.02)
	var f_lo: float = flats.min()
	var f_hi: float = flats.max()
	_check("but never stop being that archetype: ribbons stay flat (%.2f .. %.2f)"
			% [f_lo, f_hi], f_lo > 0.6)
	# --- §30: identity survives, because seeds are stable ----------------
	var a = DreamPalpMorphology.generate(DreamPalpMorphology.Kind.GOLD_FINGER, 31337)
	var b = DreamPalpMorphology.generate(DreamPalpMorphology.Kind.GOLD_FINGER, 31337)
	_check("the same seed always makes the same individual",
			is_equal_approx(a.length, b.length) and is_equal_approx(a.gold, b.gold))
	# --- §8, §9: PERSONALITY AND INTENT ----------------------------------
	# Stable traits, distinct individuals, and many different things being
	# done at once. A margin where everyone is doing the same thing is a
	# wave, not an ecology.
	var acts: Dictionary = c.get("acts", {})
	print("[margin] acts: %s" % [acts])
	_check("many primitives run at once, not one global motion (%d kinds)"
			% acts.size(), acts.size() >= 4)
	_check("the characterful acts actually fire, not just probe/hover",
			int(acts.get("trace", 0)) + int(acts.get("touch", 0))
			+ int(acts.get("taste", 0)) + int(acts.get("brace", 0)) >= 3)
	if margin.palps.size() >= 4:
		var first: int = int(margin.palps[0].id)
		var before: Dictionary = margin.personality_of(first).duplicate()
		_check("personality is not empty", before.size() >= 8)
		await get_tree().create_timer(2.5).timeout
		var after: Dictionary = margin.personality_of(first)
		var stable := after.size() == before.size()
		if stable:
			for k in before:
				if not is_equal_approx(float(before[k]), float(after.get(k, -9.0))):
					stable = false
					break
		_check("§8: traits are stable for life, never reshuffled", stable)
		# Individuals must differ, or personality is decoration.
		var spread := 0.0
		var seen_curiosity: Array = []
		for p in margin.palps:
			seen_curiosity.append(float(p.traits.curiosity))
		if seen_curiosity.size() >= 2:
			spread = seen_curiosity.max() - seen_curiosity.min()
		_check("individuals differ from each other (curiosity spread %.2f)" % spread,
				spread > 0.25)

	# --- and it is actually drawn ----------------------------------------
	var renderer: DreamPalpRenderer = enc.get("palp_renderer")
	_check("the whole population draws in one mesh",
			renderer != null and renderer.get_node_or_null("Palps") != null)
	if renderer != null:
		print("[margin] renderer %s" % [renderer.census()])
		_check("appendages reach the renderer (%d drawn)" % int(renderer.census().drawn),
				int(renderer.census().drawn) >= 1)
	_finish()


func _finish() -> void:
	print("DREAM MARGIN TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[margin ok] " + label)
	else:
		failures += 1
		printerr("[MARGIN FAIL] " + label)
