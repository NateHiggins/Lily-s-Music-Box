class_name DreamPalpNeighborSystem
extends RefCounted
## PHASE 6 — THE MARGIN IS A SOCIETY (ecology architecture §10).
##
##     "Clusters can form temporary arthropod-mouthpart-like arrangements.
##      They should look purposeful, not chaotic."
##
## Until now every appendage was a soloist: it found its own target, did its
## own thing, and could have been alone on the wall. What makes a margin read
## as one distributed organism rather than as forty independent props is that
## they KNOW ABOUT EACH OTHER — they get out of each other's way, they notice
## what a neighbour has found, and occasionally several of them work the same
## thing at once.
##
## §10 lists what each broadcasts: tip position, body occupancy, target,
## interest level, contact state, startle state, branch state, hero proximity,
## critter proximity. ALL NINE are here now, and each of the last five earns
## its place by being consumed by a behaviour -- a broadcast nothing listens to
## is a field on a dictionary, not a society.
##
## The traits decide who does what. A territorial palp defends its space; a
## sociable one joins in; an incurious one ignores the whole thing. That is
## why §8 insisted personality be stable — a society of individuals who
## reshuffle their character every second is just noise with extra steps.

## The act names are an enum, not numbers. Writing 7 and 8 inline works right
## up until somebody inserts an act in the middle of the list, and then the
## margin quietly starts watching when it means to withdraw.
const BehaviorScript := preload("res://scripts/dream/margin/dream_palp_behavior.gd")

## How far apart two tips must be before they stop minding each other.
const PERSONAL_M := 0.16
## How far a palp can notice a neighbour's discovery from.
const NOTICE_M := 0.85
## §11 — the hero is a high-priority neighbour, and it is felt further off
## than any palp. It is the largest thing in the ecology and the one every
## other appendage has an opinion about.
const HERO_NOTICE_M := 2.4


## Everyone's current broadcast. Rebuilt at the system's own cadence rather
## than every frame: sixty-five appendages is 2,080 pairs and none of this
## changes fast enough to need it at 60 Hz.
static func broadcast(palps: Array) -> Array:
	var out: Array = []
	for p in palps:
		out.append({
			"id": int(p.id),
			"tip": p.tip,
			"target": p.target,
			"act": int(p.act),
			# Interest: how worth joining this individual's discovery is.
			"interest": (0.0 if p.target == Vector3.INF
					else 0.35 + 0.65 * float(p.traits.object_interest)),
			"tier": int(p.tier),
			# How firmly it is on the thing, as opposed to reaching for it.
			"contact": float(p.get("contact", 0.0)),
			# How recently something frightened it.
			"startle": float(p.get("startle", 0.0)),
			# Branch state: whether this is folded anatomy, whose, and how far
			# out of its parent it has come.
			"parent": int(p.get("parent", -1)),
			"children": int(p.get("children", 0)),
			"unfold": float(p.get("unfold", 1.0)),
			# What the two other levels of the ecology are doing to it.
			"hero_near": float(p.get("hero_near", 0.0)),
			"critter_near": float(p.get("critter_near", 0.0)),
		})
	return out


## Who each palp can currently feel. Returns ids, nearest first.
static func neighbours(p: Dictionary, board: Array) -> Array:
	var me: int = int(p.id)
	var tip: Vector3 = p.tip
	var found: Array = []
	for other in board:
		if int(other.id) == me:
			continue
		var d: float = tip.distance_to(other.tip)
		if d < NOTICE_M:
			found.append({"id": int(other.id), "d": d, "rec": other})
	found.sort_custom(func(a, b): return float(a.d) < float(b.d))
	return found


## §11 — THE HERO PARTICIPATES.
##
##     "This makes the hero limb feel like a dominant member/organ of the same
##      living system rather than a special effect dropped into it."
##
## It is not a neighbour like the others. It is felt from three times as far,
## and what an appendage does about it is decided almost entirely by that
## individual's `hero_affinity`: the bold collect around it and inspect what
## it inspects, the timid get out of its way. Both are reactions; a palp with
## no opinion about the hero is the one thing that would read as a prop.
static func consider_hero(p: Dictionary, hero, rng: RandomNumberGenerator,
		delta: float) -> Vector3:
	if hero == null or not is_instance_valid(hero):
		p.hero_near = 0.0
		return Vector3.ZERO
	var tip: Vector3 = p.tip
	var hero_tip: Vector3 = hero.tip_world()
	var d: float = tip.distance_to(hero_tip)
	var to_root: float = tip.distance_to(hero.global_position)
	var nearest: float = minf(d, to_root)
	p.hero_near = clampf(1.0 - nearest / HERO_NOTICE_M, 0.0, 1.0)
	if p.hero_near <= 0.0:
		return Vector3.ZERO
	var tr: Dictionary = p.traits
	var affinity: float = float(tr.hero_affinity)
	var push := Vector3.ZERO
	if affinity > 0.55:
		# Collect around it, and inspect what it inspects.
		var toward: Vector3 = (hero.global_position - tip)
		if toward.length() > 0.02:
			push += toward.normalized() * p.hero_near * (affinity - 0.55) * 0.55
		if hero.target != Vector3.INF and p.target == Vector3.INF:
			if rng.randf() < affinity * delta * 1.6:
				p.target = hero.target
				p.joined = -2   # -2 reads as "joined the hero"
	else:
		# Make room. §11: margin tentacles make room when it emerges.
		var away: Vector3 = (tip - hero_tip)
		if away.length() > 0.02:
			push += away.normalized() * p.hero_near * (0.55 - affinity) * 0.85
	return push


## The social pass. Returns a steering offset for this palp's tip, and may
## change what it is attending to.
##
## Deliberately small: §10 warns that clusters must look purposeful rather
## than chaotic, and the fastest way to chaos is for everyone to react to
## everyone at full strength.
static func socialise(p: Dictionary, board: Array, rng: RandomNumberGenerator,
		delta: float) -> Vector3:
	var near: Array = neighbours(p, board)
	p.neighbour_count = near.size()
	if near.is_empty():
		return Vector3.ZERO
	var tr: Dictionary = p.traits
	var tip: Vector3 = p.tip
	var push := Vector3.ZERO

	# AVOIDANCE. Two organs do not occupy the same place, and a territorial
	# one insists on more room than a tolerant one.
	var personal: float = PERSONAL_M * (0.6 + 0.9 * float(tr.territoriality))
	for n in near:
		var d: float = float(n.d)
		if d >= personal or d < 0.0001:
			continue
		var away: Vector3 = (tip - (n.rec.tip as Vector3)) / d
		push += away * (personal - d) * 2.4

	# INVESTIGATION AND COOPERATIVE INSPECTION. A sociable palp that has found
	# nothing itself will join whatever its most interested neighbour is
	# working on — which is how a mouthpart cluster forms without anything
	# ever being told to form one.
	if p.target == Vector3.INF and float(tr.social_affinity) > 0.45:
		for n in near:
			var rec: Dictionary = n.rec
			if rec.target == Vector3.INF:
				continue
			if rng.randf() < float(rec.interest) * float(tr.social_affinity) * delta * 2.5:
				p.target = rec.target
				p.joined = int(rec.id)
				break

	# MIMICRY. Rarely, and only among the sociable: doing what the thing next
	# to you is doing.
	if rng.randf() < 0.04 * float(tr.social_affinity) * delta * 60.0 / 60.0:
		p.act = int(near[0].rec.act)
		p.act_clock = 0.0

	# WARNING SIGNALS (§10). Startle SPREADS. This is the behaviour that makes
	# the margin read as one animal rather than as forty: something frightens
	# one appendage in a corner and the alarm runs outward across the wall,
	# arriving late and weaker the further it goes, instead of the whole margin
	# switching on together. A jumpy individual -- a LOW threshold -- catches
	# it from further off and passes it on harder.
	var caught := 0.0
	for n in near:
		var their: float = float(n.rec.get("startle", 0.0))
		if their <= 0.05:
			continue
		# Falls off with distance, so the wave has a front.
		var reach: float = 1.0 - float(n.d) / NOTICE_M
		caught = maxf(caught, their * reach * (1.2 - float(tr.startle_threshold)))
	if caught > float(p.startle):
		# It only ever rises here. Coming down is the individual's own nerve,
		# in the controller -- otherwise a calm neighbour would talk a
		# frightened one down, and alarm does not work that way.
		p.startle = minf(1.0, caught * 0.82)
		if float(p.startle) > 0.55:
			p.act = BehaviorScript.Act.WITHDRAW
			p.act_clock = 0.0
			p.act_left = 0.5 + float(p.startle) * 1.1

	# COMPETITION (§10). Two appendages on the same find. Contact settles it:
	# the one already ON the thing keeps it, and the one still reaching gives
	# up -- unless it is the more territorial of the two, in which case it
	# holds on and they work it together, which is how the mouthpart clusters
	# form with something at stake instead of by agreement.
	p.contested = false
	if p.target != Vector3.INF and float(p.contact) < 0.5:
		for n in near:
			var rec: Dictionary = n.rec
			if rec.target == Vector3.INF:
				continue
			if (rec.target as Vector3).distance_to(p.target) > 0.09:
				continue
			p.contested = true
			if float(rec.get("contact", 0.0)) > 0.5 					and float(tr.territoriality) < 0.6:
				p.target = Vector3.INF
				p.joined = -1
			break

	# BRACING (§10). An appendage that IS on something is a fixed point, and a
	# neighbour reaching past it steadies itself against it. Small, and only
	# toward one that has actually made contact -- bracing against something
	# that is itself waving about is not bracing.
	for n in near:
		var solid: float = float(n.rec.get("contact", 0.0))
		if solid < 0.6 or float(n.d) > PERSONAL_M * 2.2:
			continue
		var toward: Vector3 = (n.rec.tip as Vector3) - tip
		if toward.length() > 0.01:
			push += toward.normalized() * solid * 0.18 * (1.0 - float(tr.territoriality))
		break

	# THE SMALLEST THING IN THE ECOLOGY, INVESTIGATED (§10's ninth broadcast,
	# §21's biome). A curious appendage with nothing of its own to do turns
	# toward an animal that has come within reach. A timid one does not, and
	# neither does one already working on something.
	if float(p.get("critter_near", 0.0)) > 0.35 and p.target == Vector3.INF:
		if float(tr.object_interest) > 0.5 and float(p.startle) < 0.3:
			if rng.randf() < float(tr.object_interest) * delta * 1.4:
				p.act = BehaviorScript.Act.WATCH
				p.act_clock = 0.0
				p.act_left = 0.8 + float(tr.object_interest) * 1.4

	return push
