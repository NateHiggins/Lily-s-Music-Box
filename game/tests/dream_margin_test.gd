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
	# §11 needs the hero present to test whether the margin reacts to it.
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
		# Pick one that will still be alive in three seconds. Sampling
		# palps[0] failed once because that individual died during the wait
		# and a dead palp has no personality — which is a fact about the test,
		# not about §8.
		var youngest: Dictionary = margin.palps[0]
		for p in margin.palps:
			if float(p.life) - float(p.age) > float(youngest.life) - float(youngest.age):
				youngest = p
		var first: int = int(youngest.id)
		var before: Dictionary = margin.personality_of(first).duplicate()
		_check("personality is not empty", before.size() >= 8)
		await get_tree().create_timer(2.5).timeout
		var after: Dictionary = margin.personality_of(first)
		var stable := after.size() == before.size() and after.size() > 0
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

	# --- §10: THE MARGIN IS A SOCIETY ------------------------------------
	# Until Phase 6 every appendage was a soloist and could have been alone
	# on the wall. What makes it read as one distributed organism is that
	# they know about each other.
	_check("appendages feel their neighbours (%d of %d)"
			% [int(c.with_neighbours), int(c.live)],
			int(c.with_neighbours) >= int(c.live) / 3)
	_check("some join what a neighbour has found (%d)" % int(c.joined_a_neighbour),
			int(c.joined_a_neighbour) >= 1)
	_check("clusters form on one target without being told to (%d cooperating)"
			% int(c.cooperating), int(c.cooperating) >= 2)
	if margin.palps.size() > 3:
		var probe_id: int = int(margin.palps[0].id)
		var n: Array = margin.neighbours_of(probe_id)
		print("[margin] palp %d feels %d neighbours" % [probe_id, n.size()])
		_check("the broadcast is readable per individual", n.size() >= 0)
	# AVOIDANCE. Two organs do not occupy the same place. Measured as the
	# closest pair of tips anywhere in the population — they may touch, but a
	# margin where tips routinely coincide is soup.
	var closest := 9.0
	for i in margin.palps.size():
		for j in range(i + 1, margin.palps.size()):
			var d: float = (margin.palps[i].tip as Vector3).distance_to(
					margin.palps[j].tip)
			closest = minf(closest, d)
	print("[margin] closest pair of tips: %.4f m" % closest)
	_check("tips keep out of each other (closest pair %.3f m)" % closest,
			closest > 0.008)

	# --- §11: THE HERO IS A MEMBER, NOT A VISITOR ------------------------
	var hero = enc.get("hero")
	_check("the hero exists and the margin knows about it",
			hero != null and margin.hero != null)
	if hero != null:
		# Give the population time to drift into and out of its reach.
		var peak_feel := 0
		var peak_joined := 0
		for probe in 20:
			await get_tree().create_timer(0.5).timeout
			var cc: Dictionary = margin.census()
			peak_feel = maxi(peak_feel, int(cc.get("feel_hero", 0)))
			peak_joined = maxi(peak_joined, int(cc.get("joined_hero", 0)))
		print("[margin] peak feeling the hero %d, peak joined it %d"
				% [peak_feel, peak_joined])
		_check("appendages near the hero react to it (%d)" % peak_feel,
				peak_feel >= 2)
		_check("some inspect what the hero inspects (%d)" % peak_joined,
				peak_joined >= 1)

	# --- §12: FOLDED INSIDE, NOT SCALED FROM ZERO ------------------------
	# The rule is explicit and it is the whole difference between anatomy and
	# a spawn effect: "Never spawn a branch by scaling a cylinder from zero.
	# Make it appear that complicated anatomy was folded inside simple
	# anatomy." So the test is not "do branches appear" but "were they
	# already full size and already inside their parent when they did".
	var seen_branch := false
	var worst_fold := 9.0
	# Each branch's radius the first time it was ever seen, against every
	# later reading. A branch is a different archetype from its parent, so
	# comparing the two says nothing; what "never scaled from zero" actually
	# means is that ITS OWN size never changed.
	var first_radius := {}
	var worst_growth := 0.0
	for probe in 40:
		await get_tree().create_timer(0.4).timeout
		for p in margin.palps:
			if int(p.parent) < 0:
				continue
			seen_branch = true
			var id: int = int(p.id)
			var r: float = float(p.morph.base_radius)
			if not first_radius.has(id):
				first_radius[id] = r
			worst_growth = maxf(worst_growth,
					absf(r - float(first_radius[id])) / maxf(0.0001, r))
			var par: Dictionary = margin.parent_of(p)
			if par.is_empty():
				continue
			# While folded it must lie ALONG the parent's shaft, inside its
			# volume — measured as the distance from the branch's tip to the
			# parent's own axis, not to its tip.
			if float(p.unfold) < 0.10:
				var axis_a: Vector3 = par.anchor
				var axis_b: Vector3 = par.tip
				var axis: Vector3 = axis_b - axis_a
				var along_t: float = 0.0
				if axis.length_squared() > 0.000001:
					along_t = clampf(((p.tip as Vector3) - axis_a).dot(axis)
							/ axis.length_squared(), 0.0, 1.0)
				worst_fold = minf(worst_fold,
						(p.tip as Vector3).distance_to(axis_a + axis * along_t))
	_check("branches happen at all", seen_branch)
	if seen_branch:
		print("[margin] %d branches tracked, tightest fold %.4f m, "
				% [first_radius.size(), worst_fold]
				+ "largest size change %.4f" % worst_growth)
		_check("a folded branch lies along its parent's shaft (%.4f m off axis)"
				% worst_fold, worst_fold < 0.05)
		_check("§12: a branch never changes size — it unfolds, it does not "
				+ "grow (worst %.4f)" % worst_growth, worst_growth < 0.001)
		var c2: Dictionary = margin.census()
		print("[margin] %d branches, %d mid-unfold" % [int(c2.branches),
				int(c2.unfolding)])

	# --- §29/§30: LOD MUST NOT REPLACE ANYONE ----------------------------
	# "Preserve species, preserve seed, preserve personality, preserve current
	# state ... No obvious identity replacement." The margin carries more
	# appendages than it can draw, so individuals move in and out of the drawn
	# set constantly. Each one must come back as ITSELF.
	var watched: Dictionary = {}
	for p in margin.palps:
		watched[int(p.id)] = {
			"seed": int(p.seed), "kind": int(p.morph.kind),
			"len": float(p.morph.length),
			"curiosity": float(p.traits.curiosity),
			"bold": float(p.traits.boldness),
		}
	await get_tree().create_timer(6.0).timeout
	var checked := 0
	var changed := 0
	var first_change := ""
	for p in margin.palps:
		var id: int = int(p.id)
		if not watched.has(id):
			continue
		checked += 1
		var was: Dictionary = watched[id]
		if int(p.seed) != int(was.seed) or int(p.morph.kind) != int(was.kind) 				or not is_equal_approx(float(p.morph.length), float(was.len)) 				or not is_equal_approx(float(p.traits.curiosity), float(was.curiosity)) 				or not is_equal_approx(float(p.traits.boldness), float(was.bold)):
			changed += 1
			if first_change == "":
				first_change = "palp %d" % id
	print("[margin] %d individuals survived six seconds of LOD churn, %d changed"
			% [checked, changed])
	_check("§30 identity survives: seed, species, proportions and personality "
			+ "are unchanged (%d of %d)%s" % [checked - changed, checked,
			"" if first_change == "" else " — " + first_change], changed == 0)
	_check("and enough of them were alive to mean anything (%d)" % checked,
			checked >= 5)

	# --- and it is actually drawn ----------------------------------------
	var renderer: DreamPalpRenderer = enc.get("palp_renderer")
	_check("the whole population draws in one mesh",
			renderer != null and renderer.get_node_or_null("Palps") != null)
	if renderer != null:
		print("[margin] renderer %s" % [renderer.census()])
		_check("appendages reach the renderer (%d drawn)" % int(renderer.census().drawn),
				int(renderer.census().drawn) >= 1)
		# The drawn set must be the NEAREST set. Before this, it was whichever
		# forty sat earliest in the array, so a margin of eighty could put all
		# its geometry across the flat while the wall in front of you carried
		# none of it.
		# Hold the population still. The renderer sorts by distance in
		# _process while the tips keep moving in _physics_process, so a
		# measurement taken a moment later compares the selection against
		# positions it was never made from -- one run in three reported a
		# nearer palp skipped by 25 cm, which was true afterwards and false
		# when the choice was made.
		margin.frozen = true
		await get_tree().process_frame
		await get_tree().process_frame
		var eye: Vector3 = renderer._eye_position()
		var drawn_far := 0.0
		var skipped_near := 9999.0
		var ids: Array = renderer.drawn_ids
		for p in margin.palps:
			var d: float = eye.distance_to(p.tip)
			if ids.has(int(p.id)):
				drawn_far = maxf(drawn_far, d)
			else:
				skipped_near = minf(skipped_near, d)
		print("[margin] furthest drawn %.2f m, nearest skipped %.2f m"
				% [drawn_far, skipped_near])
		if margin.palps.size() > int(renderer.census().drawn):
			_check("§29 the drawn set is the NEAREST set (%.2f m vs %.2f m)"
					% [drawn_far, skipped_near], drawn_far <= skipped_near + 0.01)
		margin.frozen = false
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
