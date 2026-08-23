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
## critter proximity. The first four are here; the rest need systems that do
## not exist yet, and are named in `neighbours_of` rather than faked.
##
## The traits decide who does what. A territorial palp defends its space; a
## sociable one joins in; an incurious one ignores the whole thing. That is
## why §8 insisted personality be stable — a society of individuals who
## reshuffle their character every second is just noise with extra steps.

## How far apart two tips must be before they stop minding each other.
const PERSONAL_M := 0.16
## How far a palp can notice a neighbour's discovery from.
const NOTICE_M := 0.85


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

	return push
