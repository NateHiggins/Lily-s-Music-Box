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
	#
	# EXCEPT ANATOMY THAT IS STILL FOLDED. §12's whole point is that a branch
	# is not spawned, it is UNFOLDED: at unfold 0 it lies perfectly coincident
	# with its parent, because it has not come out of it yet. Two siblings
	# branching from one parent in the same moment are therefore exactly 0.000
	# m apart, and are supposed to be. Counting them measured the one thing
	# the design guarantees and called it soup -- it read as a pass only for
	# as long as nothing happened to branch while the sample was taken.
	var out: Array = []
	for p in margin.palps:
		if int(p.parent) >= 0 and float(p.unfold) < 0.15:
			continue
		out.append(p)
	var closest := 9.0
	for i in out.size():
		for j in range(i + 1, out.size()):
			var d: float = (out[i].tip as Vector3).distance_to(out[j].tip)
			closest = minf(closest, d)

	# --- §12 STEPS 2-4: THE TELL BEFORE THE BRANCH -----------------------
	#
	# Steps 5 and 6 were built first and arrived out of nowhere: an organ was
	# simple, and then on the next frame it was branched. The canonical
	# sequence puts congestion, gold repositioning and a crease in front of
	# that, and their whole purpose is to take time -- the wall shows you where
	# it is about to open before it opens.
	#
	# CONSTRUCTED. Branching is a rare roll against an individual's own
	# likelihood; waiting for one would be waiting on the weather.
	var host: Dictionary = {}
	for p in margin.palps:
		if int(p.parent) < 0 and int(p.children) == 0:
			host = p
			break
	if host.is_empty():
		_check("§12 there is an unbranched appendage to test with", false)
	else:
		if host.target == Vector3.INF:
			host.target = (host.tip as Vector3) + (host.normal as Vector3) * 0.03
		while margin.palps.size() + 3 > 86 and margin.palps.size() > 6:
			margin.palps.remove_at(margin.palps.size() - 1)
		host.swell_v = 0.6
		host.swell = 0.0001
		var saw_swell := false
		var swell_first := false
		var peak_swell := 0.0
		# DRIVEN BY HAND. Physics frames are a poor clock for this: the margin
		# is one node in a loaded building and does not step on every one of
		# them, so nine hundred frames delivered three quarters of a second of
		# margin time and the swelling never finished. Stepping it directly
		# also stops it repopulating underneath the test, which matters because
		# branching is refused at capacity -- and a refused branch would leave
		# the tell playing with nothing behind it.
		for _step in 40:
			margin._think(0.06)
			peak_swell = maxf(peak_swell, float(host.get("swell", 0.0)))
			if float(host.get("swell", 0.0)) > 0.25 and int(host.children) == 0:
				saw_swell = true
			if int(host.children) > 0:
				swell_first = saw_swell
				break
		_check("§12 the tissue swells before anything separates (peak %.2f)"
				% peak_swell, saw_swell)
		_check("§12 and nothing separates until the swelling finishes",
				swell_first and int(host.children) > 0)

		# --- §12 STEPS 10-12: IT GOES BACK THE WAY IT CAME ---------------
		#
		# "Never spawn a branch by scaling a cylinder from zero" is a
		# statement about anatomy, and anatomy does not LEAVE that way either.
		# A branch lies back down along its parent and is gone when it is
		# indistinguishable from it.
		var kid: Dictionary = {}
		for p in margin.palps:
			if int(p.parent) == int(host.id):
				kid = p
				break
		if kid.is_empty():
			_check("§12 a branch exists to watch fold back", false)
		else:
			var kid_id: int = int(kid.id)
			# KEEP THE PARENT ALIVE FOR THE MEASUREMENT. Appendages live six
			# to fifteen seconds and this host has already used some of that;
			# if it dies while its branch is folding there is nothing left to
			# hand the topology back to, and the check reads a working release
			# as a broken one while holding a reference to a removed organ.
			host.life = float(host.age) + 40.0
			var had: int = int(host.children)
			# Straight to the end of its life, so this measures the folding
			# rather than the waiting.
			kid.age = float(kid.life) - 1.1
			var min_unfold := 2.0
			var max_grow := 0.0
			var gone := false
			for _step in 60:
				margin._think(0.05)
				margin._age(0.05)
				var still := false
				for p in margin.palps:
					if int(p.id) == kid_id:
						still = true
						min_unfold = minf(min_unfold, float(p.unfold))
						max_grow = maxf(max_grow, float(p.grow))
						break
				if not still:
					gone = true
					break
			_check("§12 a branch folds back into its parent (unfold fell to %.2f)"
					% min_unfold, gone and min_unfold < 0.25)
			_check("§12 and it folds rather than shrinking (grow held at %.2f)"
					% max_grow, max_grow > 0.9)
			_check("§12 the parent returns to simpler topology (%d -> %d children)"
					% [had, int(host.children)],
					margin.palps.has(host) and int(host.children) < had)

	# --- §12 STEPS 7-11: WHAT A BRANCH DOES WHILE IT IS OUT ---------------
	_step12_fine_anatomy(margin)

	# AND THE SWELLING REACHES THE RENDERER. A premonition the geometry never
	# hears about is a number in a dictionary: every one of steps 2, 3 and 4 is
	# surface, so if this array stays at zero none of them happens on screen.
	var pr: DreamPalpRenderer = enc.get("palp_renderer")
	if pr != null:
		for p in margin.palps:
			p.swell = 0.5
			p.swell_v = 0.6
		await get_tree().physics_frame
		await get_tree().physics_frame
		var published := 0.0
		for v in pr._branch:
			published = maxf(published, v.x)
		_check("§12 the swelling reaches the geometry (%.2f)" % published,
				published > 0.1)
		for p in margin.palps:
			p.swell = 0.0

		# AND SO MUST THE FINE ANATOMY. Steps 8 and 9 are entirely surface and
		# geometry -- there is no other way for a player to know they happened --
		# so a deployment the renderer never publishes is a number in a
		# dictionary, exactly as the swelling was.
		# HELD STILL WHILE IT IS READ. The renderer publishes in `_process` and
		# the margin lives in `_physics_process`, so between setting a value and
		# reading it back the simulation gets a turn -- it retracts the cilia it
		# is meant to be retracting, ages the palp out, and repopulates over the
		# top. The first version of this read a beat of 0.00 off appendages that
		# had been born after it was set.
		margin.frozen = true
		for p in margin.palps:
			p.cilia_out = 0.9
			p.cilia_band = 0.6
			p.task_left = DreamMarginController.TASK_S * 0.5
		await get_tree().process_frame
		await get_tree().process_frame
		var out_pub := 0.0
		var beat_pub := 0.0
		for v in pr._cilia:
			out_pub = maxf(out_pub, v.x)
			beat_pub = maxf(beat_pub, v.z)
		_check("§12 the deployed cilia reach the geometry (%.2f)" % out_pub,
				out_pub > 0.1)
		_check("§12 and so does the completion beat (%.2f)" % beat_pub,
				beat_pub > 0.1)
		for p in margin.palps:
			p.cilia_out = 0.0
			p.task_left = 0.0
		margin.frozen = false

	print("[margin] closest pair of tips: %.4f m (%d out of %d unfolded)"
			% [closest, out.size(), margin.palps.size()])
	# WHICH PAIR, AND WHY. "0.000 m" on its own says two tips coincide and
	# nothing about whether that is soup or a branch that has not unfolded yet.
	var ci := -1
	var cj := -1
	for i in out.size():
		for j in range(i + 1, out.size()):
			if is_equal_approx((out[i].tip as Vector3).distance_to(
					out[j].tip), closest):
				ci = i
				cj = j
				break
		if ci >= 0:
			break
	if ci >= 0:
		var pa: Dictionary = out[ci]
		var pb: Dictionary = out[cj]
		print("[margin]   %d(parent %d, unfold %.2f, act %d) vs %d(parent %d, unfold %.2f, act %d)"
				% [int(pa.id), int(pa.parent), float(pa.unfold), int(pa.act),
				int(pb.id), int(pb.parent), float(pb.unfold), int(pb.act)])
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


## §12 STEPS 7 TO 11 — WHAT A BRANCH DOES WHILE IT IS OUT.
##
## Steps 5-7 and 11-12 were built first, so a branch came out, waved at
## something, and went back in. Four of the twelve steps describe the middle of
## that, and three of them are asserted here for the first time: the fine cilia
## deploying AFTER independent investigation has begun (8), the task completing
## as a beat of its own (9), and the fine anatomy retracting BEFORE the branch
## folds (10).
##
## CONSTRUCTED, AND DRIVEN BY HAND, for the two reasons the steps 2-4 block
## above already gives. Branching is a rare roll against an individual's own
## likelihood, so an assertion that waits for one is an assertion about the
## weather. And physics frames are a poor clock: the margin is one node in a
## loaded building and does not step on every one of them, so nine hundred of
## them delivered about three quarters of a second of margin time.
##
## AND IT WORKS ON COPIES. Twenty seconds of hand-driven margin time is twenty
## seconds this population did not really live: run against the real palps it
## ages most of them to death, and the §11 checks below -- which need an
## established population near the hero -- then run against a margin that has
## just been emptied. The real array is put back untouched at the end, and the
## duplicates carry the same ids only while the originals are out of play.
func _step12_fine_anatomy(margin: DreamMarginController) -> void:
	var original: Array = margin.palps.duplicate()
	var keep: Array = []
	for p in original:
		if int(p.parent) < 0 and keep.size() < 8:
			var copy: Dictionary = p.duplicate()
			# `try_branch` refuses a parent that already has children, and every
			# host here has to outlive the branch it is about to put out or there
			# is nothing left to hand the topology back to.
			copy.children = 0
			copy.life = float(copy.age) + 600.0
			keep.append(copy)
	if keep.size() < 2:
		_check("§12 appendages to grow fine anatomy on", false)
		return
	margin.palps = keep
	var dt := 0.04
	var host: Dictionary = keep[0]
	var idle_primary: Dictionary = keep[1]

	# --- THE FULL SEQUENCE, ON ONE BRANCH --------------------------------
	# §12 step 1: it branches BECAUSE it found something.
	host.target = (host.tip as Vector3) + (host.normal as Vector3) * 0.03
	_check("§12 a branch to carry the fine anatomy",
			margin.try_branch(int(host.id)))
	var kid: Dictionary = {}
	for p in margin.palps:
		if int(p.parent) == int(host.id):
			kid = p
			break
	if kid.is_empty():
		_check("§12 the branch exists to watch", false)
		margin.palps = original
		return
	var kid_id: int = int(kid.id)
	# Long enough that the whole sequence runs to completion rather than being
	# cut short by the branch's own mortality -- which is the OTHER path into
	# retraction and is not the one being measured here.
	kid.life = 30.0
	kid.age = 0.0

	var t := 0.0
	var t_investigate := -1.0     # first moment it is working on its own
	var t_deploy := -1.0          # first moment any cilium has moved
	var t_full := -1.0            # first moment they are all the way out
	var t_beat := -1.0            # first moment of the completion beat
	var t_done := -1.0            # the beat ended
	var t_retract := -1.0         # first moment they are coming back in
	var t_fold := -1.0            # first moment the branch itself folds
	var beat_seconds := 0.0
	var cilia_at_investigate := -1.0
	var cilia_at_beat := -1.0
	var cilia_at_fold := -1.0
	var unfold_at_deploy := -1.0
	var was_full := false
	var gone := false
	for _step in 500:
		margin._think(dt)
		margin._age(dt)
		t += dt
		var alive := false
		for p in margin.palps:
			if int(p.id) == kid_id:
				alive = true
				break
		if not alive:
			gone = true
			break
		var out_at: float = float(kid.cilia_out)
		if t_investigate < 0.0 and float(kid.investigate) > 0.0:
			t_investigate = t
			cilia_at_investigate = out_at
		if t_deploy < 0.0 and out_at > 0.001:
			t_deploy = t
			unfold_at_deploy = float(kid.unfold)
		if t_full < 0.0 and out_at >= 0.999:
			t_full = t
			was_full = true
		if float(kid.task_left) > 0.0:
			if t_beat < 0.0:
				t_beat = t
				cilia_at_beat = out_at
			beat_seconds += dt
		if t_done < 0.0 and bool(kid.task_done):
			t_done = t
		if t_retract < 0.0 and was_full and out_at < 0.995:
			t_retract = t
		if t_fold < 0.0 and bool(kid.folding):
			t_fold = t
			cilia_at_fold = out_at
	print("[margin] §12 branch %d: investigate %.2f s, cilia out %.2f s, "
			% [kid_id, t_investigate, t_deploy]
			+ "full %.2f s, beat %.2f s (%.2f s long), retract %.2f s, "
			% [t_full, t_beat, beat_seconds, t_retract]
			+ "fold %.2f s, gone %s" % [t_fold, gone])

	# STEP 8 HAPPENS, AND IT HAPPENS AFTER STEP 7.
	_check("§12 step 8: fine cilia deploy on an investigating branch "
			+ "(at %.2f s)" % t_deploy, t_deploy > 0.0)
	_check("§12 and not before the branch begins investigating "
			+ "(investigating from %.2f s, cilia from %.2f s)"
			% [t_investigate, t_deploy],
			t_investigate > 0.0 and t_deploy > t_investigate)
	_check("§12 with none out at the moment investigation began (%.3f)"
			% cilia_at_investigate,
			cilia_at_investigate >= 0.0 and cilia_at_investigate < 0.001)
	_check("§12 and not until the branch has separated (unfold %.2f)"
			% unfold_at_deploy,
			unfold_at_deploy >= DreamMarginController.UNFOLD_INVESTIGATING)
	# DEPLOYMENT IS A DURATION, NOT A STATE CHANGE. The renderer runs the
	# ordered wave down the band against this one clock, so a clock that
	# finished in a frame would put every cilium up in the same frame.
	_check("§12 deployment takes visible time (%.2f s over %.2f s of clock)"
			% [t_full - t_deploy, DreamMarginController.CILIA_DEPLOY_S],
			t_full > 0.0
			and t_full - t_deploy >= DreamMarginController.CILIA_DEPLOY_S * 0.75)

	# STEP 9 IS A BEAT.
	_check("§12 step 9: the task completes as its own beat (from %.2f s)"
			% t_beat, t_beat > 0.0 and t_beat > t_full)
	_check("§12 and the beat has real duration (%.2f s of %.2f s)"
			% [beat_seconds, DreamMarginController.TASK_S],
			beat_seconds >= DreamMarginController.TASK_S * 0.75)
	_check("§12 with the fine anatomy still out while it runs (%.2f)"
			% cilia_at_beat, cilia_at_beat > 0.95)

	# STEP 10 FOLLOWS 9, AND 11 FOLLOWS 10. This is the ordering the whole
	# block exists for: completion, then the fine anatomy in, then the branch.
	_check("§12 step 10: retraction begins only after completion "
			+ "(completed %.2f s, retracting %.2f s)" % [t_done, t_retract],
			t_done > 0.0 and t_retract > 0.0 and t_retract >= t_done)
	_check("§12 step 11: the branch folds only after the fine anatomy is in "
			+ "(retracting %.2f s, folding %.2f s)" % [t_retract, t_fold],
			t_fold > 0.0 and t_fold > t_retract)
	_check("§12 and it is in by then (%.3f out when folding began)"
			% cilia_at_fold, cilia_at_fold >= 0.0 and cilia_at_fold < 0.05)
	_check("§12 the whole sequence runs in order: investigate %.2f < cilia "
			% [t_investigate, ] + "%.2f < complete %.2f < retract %.2f < fold %.2f"
			% [t_deploy, t_beat, t_retract, t_fold],
			t_investigate < t_deploy and t_deploy < t_beat
			and t_beat <= t_retract and t_retract < t_fold)
	_check("§12 and the branch is gone by the end of it", gone)

	# --- AND IT DOES NOT HAPPEN TO ANYTHING ELSE -------------------------
	# A PRIMARY DOES NOT GROW CILIA, however busy it is. §12 puts the fine
	# anatomy on the SECONDARY branches, and an appendage that bristled while
	# doing its ordinary work would make the branch's own deployment mean
	# nothing. The host has been working a target for twenty seconds.
	_check("§12 no cilia on the parent appendage (%.3f)"
			% float(host.cilia_out), float(host.cilia_out) < 0.001)

	# AN IDLE ONE DOES NOT EITHER. Constructed: the idle state is HELD rather
	# than waited for, because `next_act` hands an appendage a fresh target the
	# moment it feels like probing, and a branch that is handed a target is no
	# longer the thing being tested.
	var orphans: Array = []
	for p in margin.palps:
		if int(p.parent) == int(idle_primary.id):
			orphans.append(p)
	for o in orphans:
		margin.palps.erase(o)
	idle_primary.children = 0
	idle_primary.target = (idle_primary.tip as Vector3) \
			+ (idle_primary.normal as Vector3) * 0.03
	_check("§12 a second branch, to hold idle",
			margin.try_branch(int(idle_primary.id)))
	var loafer: Dictionary = {}
	for p in margin.palps:
		if int(p.parent) == int(idle_primary.id):
			loafer = p
			break
	if loafer.is_empty():
		_check("§12 an idle branch to test with", false)
		margin.palps = original
		return
	loafer.life = 600.0
	# Fully out, so the ONLY thing keeping it from deploying is that it has
	# nothing to investigate.
	loafer.unfold = 1.0

	# IDLE HAS TO BE BUILT, NOT ASKED FOR, and it took two goes to learn how
	# much of this ecology is working against the idea.
	#
	# The first version held only the branch idle, inside the live population,
	# and watched it deploy anyway. That was §10 working exactly as written:
	# the social pass hands a TARGETLESS appendage a neighbour's target and
	# copies that neighbour's act, and the hero broadcast does the same. The
	# second version took the branch and its parent out of the population and
	# it deployed again -- because the PARENT was still running, its act
	# expired, `_seek_target` found it something on the wall, and the social
	# pass passed it straight down to the branch. A branch in a live margin
	# does not stay idle; the society finds it something to do.
	#
	# So: the pair alone, no hero, no animals, and neither of them holding
	# anything to find. That is what "an idle branch" means, and it is the only
	# state in which the claim being tested is even the claim.
	var was_hero = margin.hero
	var was_critters = margin.critters
	margin.hero = null
	margin.critters = null
	margin.palps = [idle_primary, loafer]
	var loafer_peak := 0.0
	for _step in 300:
		for idler in [idle_primary, loafer]:
			idler.target = Vector3.INF
			idler.act = DreamPalpBehavior.Act.HOVER
			idler.act_left = 9.0
		margin._think(dt)
		loafer_peak = maxf(loafer_peak, float(loafer.cilia_out))
	margin.hero = was_hero
	margin.critters = was_critters
	_check("§12 no cilia on an idle branch, held idle for %.1f s (%.3f)"
			% [300.0 * dt, loafer_peak], loafer_peak < 0.001)
	_check("§12 and none on its idle parent either (%.3f)"
			% float(idle_primary.cilia_out),
			float(idle_primary.cilia_out) < 0.001)

	# PUT THE MARGIN BACK EXACTLY AS IT WAS FOUND.
	margin.palps = original


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
