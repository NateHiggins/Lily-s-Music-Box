class_name DreamMarginController
extends Node3D
## THE DREAM MARGIN — a living anatomical border (ecology architecture §4).
##
##     "The violet Dream field does not end in a shader fade. Its boundary is
##      populated with independently behaving appendages."
##
## From a distance a crawling edge; closer, individual feelers; closer,
## several anatomical types; closer, social interaction. This owns that
## population: where the margin IS, how many appendages it carries at each
## tier (§29), which archetypes they are, and their per-individual seeds.
##
## It does not draw them and it does not decide what any one of them is doing.
## Drawing belongs to the palp renderer, which keeps the whole population in
## one mesh and one draw because the frame is submission-bound
## (`design/DT4_PERFORMANCE_REAUDIT.md`). Intent belongs to the behavior layer.
##
## This is Phase 2 of §35. Phases 5, 6, 8 and 12 hang off the hooks below and
## are not implemented: personality, neighbour interaction, recursive
## branching and hero/critter cross-interaction. Where a hook exists but does
## nothing it says so, rather than pretending.

const MorphologyScript := preload("res://scripts/dream/margin/dream_palp_morphology.gd")
const BehaviorScript := preload("res://scripts/dream/margin/dream_palp_behavior.gd")
const NeighborScript := preload("res://scripts/dream/margin/dream_palp_neighbors.gd")

## §29's population tiers. Counts are ceilings, not targets: the margin only
## carries what the field's cross-section actually reaches.
const TIER_PRIMARY := 0
const TIER_SECONDARY := 1
const TIER_TERTIARY := 2
const TIER_CAPS := [6, 20, 60]

## How long §12's steps 2 to 4 take -- the congestion, the gold moving aside
## and the crease. Long enough to be seen coming, short enough that a player
## already looking at it does not lose interest before anything happens.
const SWELL_S := 1.6

## §3's scale language, as multipliers on an archetype's authored length.
## The primaries run large: they are the ones the player walks up to, they
## carry the whole archetype library between them, and photographed at 1.0
## they were slivers on a wall at gameplay distance. §3 puts primary palps at
## 10-60 cm and this lands them there.
const TIER_SCALE := [1.35, 0.55, 0.24]

## Which archetypes each tier draws from. The primaries are the ones the
## player gets close to, so they carry the most distinct anatomy; the
## tertiaries are distributed sensing and do not need a crystal organ each.
const TIER_ARCHETYPES := [
	[MorphologyScript.Kind.SOFT_PALP, MorphologyScript.Kind.FLAT_RIBBON,
		MorphologyScript.Kind.SUCKER_PROBE, MorphologyScript.Kind.GOLD_FINGER,
		MorphologyScript.Kind.CRYSTAL_FEELER, MorphologyScript.Kind.CILIATED_WHISKER],
	[MorphologyScript.Kind.SOFT_PALP, MorphologyScript.Kind.SUCKER_PROBE,
		MorphologyScript.Kind.FLAT_RIBBON, MorphologyScript.Kind.CILIATED_WHISKER],
	[MorphologyScript.Kind.CILIATED_WHISKER, MorphologyScript.Kind.SOFT_PALP],
]

signal palp_born(index: int, tier: int, kind: int)
signal palp_died(index: int)
## §12 — anatomy that was folded inside simpler anatomy has separated.
signal branched(parent_id: int, children: int)

var field: DreamFieldController = null
## §11 — the hero is a participant in this society, not a visitor.
var hero = null
## §10's ninth broadcast needs something to be near. The margin does not own
## the critters, it only has to be able to feel them.
var critters = null
## §32 — the area's weather. Read, not obeyed: it scales probabilities.
var director = null
var enabled := true
## Every live appendage. Index is stable for its lifetime, and the seed is
## preserved across LOD promotion (§30) because identity must survive it.
var palps: Array = []

var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D = null
var _next_id := 0
var _spawn_clock := 0.0
var _clock := 0.0
var _social_clock := 0.0
var _board: Array = []
var _seed_base := 0


func setup(controller: DreamFieldController, seed_v: int) -> void:
	name = "DreamMarginController"
	enabled = OS.get_environment("DREAM_MARGIN") != "0"
	field = controller
	_seed_base = seed_v
	_rng.seed = seed_v
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world != null:
		_space = world.direct_space_state


## Set while §37's review arrangement is on display, so the simulation does
## not immediately spawn over it.
var frozen := false


func _physics_process(delta: float) -> void:
	if not enabled or field == null or field.state == null:
		return
	if frozen:
		# The arrangement holds exactly as placed. §24 wants a neutral review
		# sheet, and letting the behaviour loop keep working leaves every
		# appendage at roughly half extension, which is what a palp doing its
		# job looks like but not what a contact sheet is for.
		return
	_clock += delta
	_spawn_clock += delta
	if _spawn_clock >= 0.12:
		_spawn_clock = 0.0
		_populate()
	_think(delta)
	if _social_clock >= 0.18:
		_social_clock = 0.0
	_age(delta)


## Keep each tier stocked, cheapest first. Nothing is spawned in mid-air: an
## appendage is born where a ray from inside a live lobe strikes real matter,
## so the margin grows out of the architecture it is eating.
func _populate() -> void:
	if _space == null:
		return
	for tier in 3:
		if _count_in_tier(tier) >= TIER_CAPS[tier]:
			continue
		# §37 wants six NEARBY appendages that are clearly different, and the
		# six primaries carry the whole archetype library between them. Spread
		# across a storey they are never near anything, and the densest lit
		# cluster came out three. So primaries congregate: the first one picks
		# the spot and the rest join it. Anatomically this is also the right
		# reading of §4 — a mouthpart cluster is a group, not a scatter.
		var anchor: Dictionary = {}
		if tier == TIER_PRIMARY:
			anchor = _find_near_primaries()
		if anchor.is_empty():
			anchor = _find_surface()
		if anchor.is_empty():
			return
		_birth(tier, anchor["position"], anchor["normal"])
		break


## Somewhere on the same patch of wall as the primaries already out.
func _find_near_primaries() -> Dictionary:
	var seed_p: Dictionary = {}
	for p in palps:
		if int(p.tier) == TIER_PRIMARY:
			seed_p = p
			break
	if seed_p.is_empty():
		return {}
	var at: Vector3 = seed_p.anchor
	var nrm: Vector3 = seed_p.normal
	var side: Vector3 = seed_p.side
	var up := nrm.cross(side)
	for attempt in 8:
		var a := _rng.randf_range(0.0, TAU)
		var d := _rng.randf_range(0.22, 0.95)
		var from: Vector3 = at + (side * cos(a) + up * sin(a)) * d + nrm * 0.20
		var q := PhysicsRayQueryParameters3D.create(from, from - nrm * 0.45)
		var hit: Dictionary = _space.intersect_ray(q)
		if hit.is_empty():
			continue
		return {"position": hit.position,
				"normal": (hit.normal as Vector3).normalized()}
	return {}


func _find_surface() -> Dictionary:
	var st := field.state
	var live: Array = []
	for i in st.lobes.size():
		if st.lobe_present(i):
			live.append(i)
	if live.is_empty():
		return {}
	var l: Dictionary = st.lobes[live[_rng.randi() % live.size()]]
	var r := st.slice_radius(float(l.radius), float(l.w_offset))
	var centre: Vector3 = l.centre
	# Mostly horizontal: the margin lives on walls, where a player sees it.
	var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.30, 0.18),
			_rng.randf_range(-1.0, 1.0)).normalized()
	var query := PhysicsRayQueryParameters3D.create(centre, centre + dir * (r + 2.4))
	var hit: Dictionary = _space.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {"position": hit.position, "normal": (hit.normal as Vector3).normalized()}


func _birth(tier: int, at: Vector3, nrm: Vector3) -> void:
	var choices: Array = TIER_ARCHETYPES[tier]
	var archetype: int = choices[_rng.randi() % choices.size()]
	# §37: at least six nearby appendages must be clearly different. Rolling
	# dice does not deliver that — photographed, the first population came out
	# 29 whiskers of 64, and the closest cluster held two archetypes between
	# six members. The PRIMARY tier is the one the player walks up to, so it
	# takes each archetype in turn and is guaranteed to show the whole
	# library. The lower tiers stay random: distributed sensing genuinely is
	# mostly whiskers.
	if tier == TIER_PRIMARY:
		var used := {}
		for p in palps:
			if int(p.tier) == TIER_PRIMARY:
				used[int(p.morph.kind)] = true
		for candidate in choices:
			if not used.has(int(candidate)):
				archetype = candidate
				break
	# The individual's seed. It is kept for the appendage's whole life and
	# would survive a promotion or demotion (§30), so an appendage the player
	# walks up to is the same individual they saw from across the room.
	var indiv_seed := _seed_base + _next_id * 7919
	var morph = MorphologyScript.generate(archetype, indiv_seed)
	morph.length *= TIER_SCALE[tier]
	morph.base_radius *= TIER_SCALE[tier]
	var any := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
	var side := any.cross(nrm).normalized()
	palps.append({
		"id": _next_id,
		"tier": tier,
		"seed": indiv_seed,
		"morph": morph,
		"anchor": at,
		"normal": nrm,
		"side": side,
		# Where it currently intends to reach. §9 says movement comes from
		# intent, so even at this stage nothing here is a sine wave: the
		# behavior layer will own this and drive it toward real targets.
		"aim": (nrm + side * _rng.randf_range(-0.6, 0.6)
				+ nrm.cross(side) * _rng.randf_range(-0.6, 0.6)).normalized(),
		"age": 0.0,
		"life": _rng.randf_range(6.0, 15.0),
		"grow": 0.0,
		# §8 — stable for life, from this individual's own seed.
		"traits": BehaviorScript.personality(indiv_seed),
		# §9 — what it is doing about the world, and for how long.
		"act": BehaviorScript.Act.PROBE,
		"act_clock": 0.0,
		"act_left": 0.9,
		"target": Vector3.INF,
		"trace_angle": _rng.randf_range(0.0, TAU),
		"tip": at + nrm * 0.02,
		"last_tip": at + nrm * 0.02,
		"neighbour_count": 0,
		"joined": -1,
		"hero_near": 0.0,
		# §10's remaining broadcasts. Contact is how firmly this tip is on a
		# surface; startle is how recently something frightened it, which
		# spreads between neighbours; critter_near is the smallest thing in
		# the ecology being close enough to matter.
		"contact": 0.0,
		"startle": 0.0,
		"critter_near": 0.0,
		"critter_at": Vector3.INF,
		"contested": false,
		# §22's local look owns its own clock. Hanging it off `act_left` meant
		# anything that started a new act -- an alarm spreading through the
		# margin, an animal wandering into reach -- re-armed the look as a
		# side effect, and an appendage could go on staring at an old event
		# indefinitely through no decision of its own.
		"look_left": 0.0,
		# §13 — set only while the whole ecology is looking at one thing.
		"attend_override": Vector3.INF,
		# Phase 8. A branch is not a new thing: it is anatomy that was already
		# there, lying folded along its parent. `unfold` 0 means perfectly
		# coincident with the parent and therefore invisible inside it.
		"parent": -1,
		"unfold": 1.0,
		"children": 0,
	})
	palps[palps.size() - 1].merge(_shared_state(), false)
	palp_born.emit(_next_id, tier, archetype)
	_next_id += 1


## §9 — INTENT, not waving. Each palp advances its own act, finds its own
## target on real architecture, and asks the behaviour layer where its tip
## wants to be. The renderer solves the spine toward that.
func _think(delta: float) -> void:
	# §10 — the social pass, at its own cadence. Sixty-five appendages is
	# 2,080 pairs and none of this changes fast enough to need 60 Hz.
	_social_clock += delta
	var socialise: bool = _social_clock >= 0.18
	if socialise:
		_board = NeighborScript.broadcast(palps)
	for p in palps:
		if socialise:
			var push: Vector3 = NeighborScript.socialise(p, _board, _rng, _social_clock)
			push += NeighborScript.consider_hero(p, hero, _rng, _social_clock)
			if push.length_squared() > 0.0:
				p.tip = (p.tip as Vector3) + push * _social_clock
		p.act_clock += delta
		p.act_left -= delta
		# A LOCAL LOOK ENDS BY ITSELF, ON ITS OWN CLOCK. §22's orientation
		# borrows the same override the director uses, and the director clears
		# it in a release pass that only runs during an attention event -- so
		# without this a palp that turned to watch the hero touch a critter
		# would stare at that spot for the rest of its life.
		if bool(p.get("local_look", false)):
			p.look_left = float(p.look_left) - delta
			if float(p.look_left) <= 0.0:
				p.attend_override = Vector3.INF
				p.local_look = false
		if p.act_left <= 0.0:
			# §32 — the area state biases how long things are done for and how
			# readily attention is given, without commanding any of it.
			var bias: Dictionary = director.bias() if director != null else {}
			var move_bias: float = float(bias.get("move", 1.0))
			var orient_bias: float = float(bias.get("orient", 1.0))
			# A new act. Probing is when it goes looking for something.
			var nxt: int = BehaviorScript.next_act(p, _rng)
			if nxt == BehaviorScript.Act.PROBE:
				_seek_target(p)
			p.act = nxt
			p.act_clock = 0.0
			p.act_left = BehaviorScript.duration(nxt, p.traits, _rng) 					/ maxf(0.2, move_bias)
			# When the area is watching, an appendage is likelier to be
			# watching too.
			if orient_bias > 1.3 and _rng.randf() < (orient_bias - 1.0) * 0.35:
				p.act = BehaviorScript.Act.WATCH
				p.act_left = BehaviorScript.duration(BehaviorScript.Act.WATCH,
						p.traits, _rng)
		# §12 STEPS 1-5, IN ORDER AND WITH TIME BETWEEN THEM.
		#
		# Step 1 is interest. Steps 2, 3 and 4 -- congestion, the gold moving
		# aside, the crease -- are the tell, and they take about a second and a
		# half, which is the whole point of them: the wall shows you where it
		# is about to open before it opens. Only then does step 5 happen.
		#
		# Branching used to fire on the same frame it was rolled, so an organ
		# was simple and then it was branched, with nothing in between. The
		# roll now starts the swelling instead.
		if float(p.get("swell", 0.0)) > 0.0:
			p.swell = float(p.swell) + delta / SWELL_S
			if float(p.swell) >= 1.0:
				p.swell = 0.0
				try_branch(int(p.id))
		elif int(p.parent) < 0 and int(p.children) == 0 and p.target != Vector3.INF:
			if _rng.randf() < float(p.traits.branch_likelihood) * delta * 0.06:
				# It opens where it is thickest and best supplied, which is
				# nearer the base than the tip.
				p.swell_v = _rng.randf_range(0.42, 0.72)
				p.swell = 0.0001
		if int(p.parent) >= 0 and float(p.unfold) < 1.0:
			p.unfold = minf(1.0, float(p.unfold) + delta * 0.75)
		var want: Vector3 = BehaviorScript.desired_tip(p, _clock)
		# §13 overrides local intent, which is the entire point of it: a
		# margin that merely leaned toward the stimulus would read as weather.
		if p.attend_override != Vector3.INF:
			var to_it: Vector3 = (p.attend_override as Vector3) - (p.anchor as Vector3)
			if to_it.length() > 0.01:
				want = (p.anchor as Vector3) + to_it.normalized() 						* float(p.morph.length) * 0.9
		# The tip eases toward what it wants rather than teleporting: the
		# stiffer the organ, the more directly it gets there.
		var rate: float = 4.0 + 9.0 * float(p.morph.stiffness)
		p.last_tip = p.tip
		p.tip = (p.tip as Vector3).lerp(want, 1.0 - exp(-rate * delta))
		# §10 — CONTACT STATE. Not a flag on an act: a palp can be in the
		# TOUCH act and still be reaching, and the difference between reaching
		# for a thing and being on it is exactly what a neighbour needs to
		# know before it braces against you or takes your target off you.
		var on_it := 0.0
		if p.target != Vector3.INF:
			on_it = 1.0 - smoothstep(0.012, 0.055,
					(p.tip as Vector3).distance_to(p.target))
		p.contact = maxf(on_it, float(p.contact) - delta * 2.2)
		# §10 — STARTLE STATE, which decays on the individual's own nerve.
		p.startle = maxf(0.0, float(p.startle)
				- delta * (0.35 + 0.9 * float(p.traits.startle_threshold)))
		# §10 — CRITTER PROXIMITY.
		if critters != null and is_instance_valid(critters):
			var nearest := 9.0
			var nearest_at := Vector3.INF
			for c in critters.critters:
				var cd: float = (p.tip as Vector3).distance_to(c.pos)
				if cd < nearest:
					nearest = cd
					nearest_at = c.pos
			p.critter_near = clampf(1.0 - nearest / 0.45, 0.0, 1.0)
			p.critter_at = nearest_at
			# §21 — BE INSPECTED BY A BRANCH.
			#
			# A branch is anatomy that was folded inside its parent and has
			# come out for a reason. An animal within reach of one is the most
			# interesting thing on that stretch of wall, and a branch with
			# nothing else to do goes and looks at it -- which reads very
			# differently from the parent doing it, because the branch was not
			# there a moment ago.
			if int(p.parent) >= 0 and float(p.unfold) > 0.6 					and p.target == Vector3.INF and float(p.critter_near) > 0.4:
				p.target = nearest_at
				p.act = BehaviorScript.Act.TOUCH
				p.act_clock = 0.0
				p.act_left = 1.2 + float(p.traits.object_interest) * 2.0
		# The renderer lays the spine from anchor along `aim`, so intent
		# reaches the geometry as a direction and a length.
		if int(p.parent) >= 0:
			var par: Dictionary = parent_of(p)
			if par.is_empty():
				# The parent is gone; the branch folds away with it.
				p.life = minf(float(p.life), float(p.age) + 0.8)
			else:
				# IT LIES ALONG THE PARENT, AT FULL LENGTH.
				#
				# The first version put a folded branch's tip on its parent's
				# tip -- so its anchor and tip coincided, the renderer had a
				# zero-length organ to draw, and it collapsed to a point. The
				# data said "full size" and the picture said "scaled from
				# zero", which is the banned thing wearing the right numbers.
				#
				# A folded branch now starts partway down the parent's shaft
				# and runs ALONG it, at its own full length and half the
				# parent's radius, so it is inside the parent's own volume and
				# invisible. Unfolding rotates it out; nothing resizes.
				var pside: Vector3 = par.side
				var pup: Vector3 = (par.normal as Vector3).cross(pside)
				var base: Vector3 = (par.anchor as Vector3).lerp(par.tip, 0.55)
				var along: Vector3 = ((par.tip as Vector3) - base)
				var folded_dir: Vector3 = along.normalized() if along.length() > 0.001 						else (par.normal as Vector3)
				var own_dir: Vector3 = (pside * cos(float(p.spread) * PI)
						+ pup * sin(float(p.spread) * PI) + folded_dir * 0.5).normalized()
				p.anchor = base
				p.aim = folded_dir.slerp(own_dir, float(p.unfold))
				# FOLDED MEANS INSIDE. A branch running along its parent at
				# its own full length overshoots the parent's tip whenever the
				# parent is retracted -- and a branch sticking out of the far
				# end of the anatomy it is folded within is not folded within
				# it. While folded it is clamped to what the parent has left;
				# as it unfolds it returns to its own length, and nothing has
				# resized, only where it lies.
				var remaining: float = maxf(0.02, along.length())
				var own_len: float = float(p.morph.length)
				var use_len: float = lerpf(minf(own_len, remaining), own_len,
						float(p.unfold))
				p.tip = base + (p.aim as Vector3) * use_len
				p.extend = use_len / maxf(0.01, own_len)
		var to_tip: Vector3 = (p.tip as Vector3) - (p.anchor as Vector3)
		if to_tip.length() > 0.001:
			p.aim = to_tip.normalized()
			p.extend = clampf(to_tip.length() / maxf(0.01, float(p.morph.length)), 0.05, 1.4)


## Somewhere real to attend to, within this individual's preferred reach.
func _seek_target(p: Dictionary) -> void:
	if _space == null:
		return
	var tr: Dictionary = p.traits
	var anchor: Vector3 = p.anchor
	var nrm: Vector3 = p.normal
	var side: Vector3 = p.side
	var up: Vector3 = nrm.cross(side)
	var reach: float = float(p.morph.length) * (0.6 + 0.7 * float(tr.preferred_reach))
	for attempt in 6:
		var a := _rng.randf_range(0.0, TAU)
		var tilt := _rng.randf_range(0.15, 1.15) * (0.4 + 0.6 * float(tr.boldness))
		var dir := (nrm * cos(tilt) + (side * cos(a) + up * sin(a)) * sin(tilt)).normalized()
		var q := PhysicsRayQueryParameters3D.create(anchor + nrm * 0.01,
				anchor + nrm * 0.01 + dir * reach)
		var hit: Dictionary = _space.intersect_ray(q)
		if hit.is_empty():
			continue
		p.target = hit.position
		return
	# NOTHING IN THE AIR — SO WORK THE SURFACE IT IS STANDING ON.
	#
	# The first version only looked outward into the room, and a palp on a
	# wall has nothing within half a metre of itself, so seeking almost always
	# failed: the census came back 29 probing, 26 hovering, and one each
	# tracing and sampling. All the characterful acts need a target and none
	# of them ever got one.
	#
	# But the wall IS a surface, and §9's "Trace: follow edge, seam, contour or
	# grain" is precisely about working it. A palp that finds nothing to reach
	# for turns its attention to what it is already touching.
	var lateral := _rng.randf_range(0.0, TAU)
	var offset := (side * cos(lateral) + up * sin(lateral)) 			* reach * _rng.randf_range(0.35, 0.9)
	var probe_from: Vector3 = anchor + offset + nrm * 0.12
	var back := PhysicsRayQueryParameters3D.create(probe_from, probe_from - nrm * 0.30)
	var surface: Dictionary = _space.intersect_ray(back)
	if not surface.is_empty():
		p.target = surface.position
		return
	p.target = Vector3.INF


func _age(delta: float) -> void:
	var i := palps.size() - 1
	while i >= 0:
		var p: Dictionary = palps[i]
		p.age += delta
		# Emerge, hold, withdraw. Withdrawal propagates from the tip (§9).
		var emerge := 0.9
		var leave := 1.2
		if p.age < emerge:
			p.grow = smoothstep(0.0, 1.0, p.age / emerge)
		elif p.age > p.life - leave:
			p.grow = 1.0 - smoothstep(0.0, 1.0, (p.age - (p.life - leave)) / leave)
		else:
			p.grow = 1.0
		if p.age >= p.life:
			palp_died.emit(int(p.id))
			palps.remove_at(i)
		i -= 1


## Population accounting EXCLUDES branches. A branch is anatomy that unfolded
## out of an appendage that was already counted -- it is not a new inhabitant,
## and charging it against the spawn budget would make a branching margin
## quietly stop populating itself.
func _count_in_tier(tier: int) -> int:
	var n := 0
	for p in palps:
		if int(p.tier) == tier and int(p.parent) < 0:
			n += 1
	return n


## --- hooks that are declared and NOT yet implemented -------------------
## Named so the architecture is legible and so nobody mistakes their silence
## for completion. §35 phases 5, 6, 8 and 12.

## Phase 5 — DONE. Stable per-individual traits, from the palp's own seed,
## for the whole of its life (§8: they must not be reshuffled continuously).
func personality_of(id: int) -> Dictionary:
	for p in palps:
		if int(p.id) == id:
			return p.traits
	return {}

## SOMETHING FRIGHTENED THE MARGIN.
##
## Raises startle on everything close enough to have felt it, in proportion to
## how close it was and inversely to each individual's own nerve. From there
## §10's warning signals do the rest: the social pass spreads it outward, so a
## bang in one corner runs across the wall as a wave rather than switching the
## whole margin on at once.
func alarm(at: Vector3, amount: float = 1.0, radius: float = 1.6) -> int:
	var hit := 0
	for p in palps:
		var d: float = (p.tip as Vector3).distance_to(at)
		if d > radius:
			continue
		var near: float = 1.0 - d / radius
		# A jumpy individual has a LOW threshold, so it takes more from the
		# same event.
		var nerve: float = 1.4 - float(p.traits.startle_threshold)
		p.startle = clampf(float(p.startle) + amount * near * nerve, 0.0, 1.0)
		hit += 1
	return hit


## Phase 6 — DONE for all nine of §10's broadcasts: tip position, occupancy
## (via tip proximity), target, interest level, contact state, startle state,
## branch state, hero proximity and critter proximity.
func neighbours_of(id: int) -> Array:
	for p in palps:
		if int(p.id) == id:
			return NeighborScript.neighbours(p, _board)
	return []

## PHASE 8 — RECURSIVE UNFOLDING (§12).
##
##     "Never spawn a branch by scaling a cylinder from zero. Make it appear
##      that complicated anatomy was folded inside simple anatomy."
##
## So a branch is never created at zero size. It is created at FULL SIZE,
## lying exactly along its parent's distal spine — inside the parent's own
## volume, where it cannot be seen — and then separates. The geometry was
## always there; what changes is whether it is folded.
##
## §12's sequence in full is twelve steps and this is the middle six: the
## crease, the separation, the independent investigation, and the fold back.
## Vascular congestion and gold repositioning are shader work that does not
## exist yet.
## EVERY FIELD THE REST OF THE SYSTEM EXPECTS, IN ONE PLACE.
##
## Appendages are born in two places -- `_birth` for the ordinary ones and
## `try_branch` for folded anatomy -- and for as long as those were two
## independent dictionary literals they drifted apart. It has now happened
## twice: first a branch reached a global attention event with no
## `attend_override`, and then a branch reached §10's social pass with no
## `contact`.
##
## The second one was much worse than it looks. Reading a missing key raises,
## and the raise aborted the margin's ENTIRE update from that appendage
## onward -- so palps earlier in the array went on moving normally while
## everything after the branch silently stopped, including its own clocks. It
## presented as "one palp is ignoring me" and the margin looked fine.
##
## Merged non-destructively into both, so a field added to the ordinary birth
## reaches branches whether or not anyone remembers they exist.
static func _shared_state() -> Dictionary:
	return {
		"neighbour_count": 0,
		"joined": -1,
		"hero_near": 0.0,
		"contact": 0.0,
		"startle": 0.0,
		"critter_near": 0.0,
		"critter_at": Vector3.INF,
		"contested": false,
		"local_look": false,
		"look_left": 0.0,
		"attend_override": Vector3.INF,
		# §12 steps 2-4: the swelling that precedes a branch, and where along
		# the organ it is happening.
		"swell": 0.0,
		"swell_v": 0.6,
	}


func try_branch(id: int) -> bool:
	var parent: Dictionary = {}
	for p in palps:
		if int(p.id) == id:
			parent = p
			break
	if parent.is_empty():
		return false
	if int(parent.children) > 0 or int(parent.parent) >= 0:
		return false          # no branching from a branch, and not twice
	if parent.target == Vector3.INF:
		return false          # §12 step 1: it branches because it found something
	if palps.size() + 3 > TIER_CAPS[0] + TIER_CAPS[1] + TIER_CAPS[2]:
		return false
	var n := 2 + (_rng.randi() % 2)
	var nrm: Vector3 = parent.normal
	var side: Vector3 = parent.side
	for i in n:
		var indiv_seed := _seed_base + _next_id * 7919
		var morph = MorphologyScript.generate(
				MorphologyScript.Kind.CRYSTAL_FEELER if _rng.randf() < 0.35
				else MorphologyScript.Kind.SOFT_PALP, indiv_seed)
		# A branch is a smaller organ of the same biology, at FULL size for
		# what it is. Nothing about it grows from nothing.
		morph.length *= 0.42
		morph.base_radius *= 0.5
		var spread := (float(i) / float(maxi(1, n - 1)) - 0.5) * 1.1
		palps.append({
			"id": _next_id, "tier": TIER_SECONDARY, "seed": indiv_seed,
			"morph": morph, "anchor": parent.anchor, "normal": nrm,
			"side": side,
			"aim": (parent.aim as Vector3),
			"age": 0.0, "life": _rng.randf_range(4.5, 8.0), "grow": 1.0,
			"traits": BehaviorScript.personality(indiv_seed),
			"act": BehaviorScript.Act.PROBE, "act_clock": 0.0,
			"act_left": BehaviorScript.duration(BehaviorScript.Act.PROBE,
					BehaviorScript.personality(indiv_seed), _rng),
			"target": parent.target, "trace_angle": _rng.randf_range(0.0, TAU),
			"tip": parent.tip, "last_tip": parent.tip,
			"neighbour_count": 0, "joined": -1, "hero_near": 0.0,
			"parent": id, "unfold": 0.0, "children": 0,
			"spread": spread,
		})
		palps[palps.size() - 1].merge(_shared_state(), false)
		_next_id += 1
	parent.children = n
	branched.emit(id, n)
	return true


## Where a branch's own spine ends and its parent's begins, for the renderer.
func parent_of(p: Dictionary) -> Dictionary:
	var pid: int = int(p.parent)
	if pid < 0:
		return {}
	for q in palps:
		if int(q.id) == pid:
			return q
	return {}


## §37's ACCEPTANCE ARRANGEMENT.
##
## "At least six nearby appendages must be clearly different without relying
## purely on colour ... The edge should never look like repeated noodles."
##
## That is a review test, and reviewing it against whatever the simulation
## happens to have produced in one flat is not a review — the best natural
## cluster reached five appendages and four archetypes. This puts one of every
## archetype in a row on a chosen wall, at primary scale, so the question
## §37 actually asks can be answered from one frame.
func arrange_archetype_row(at: Vector3, nrm: Vector3, spacing: float = 0.34) -> int:
	palps.clear()
	var any := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
	var side := any.cross(nrm).normalized()
	var kinds: Array = TIER_ARCHETYPES[TIER_PRIMARY]
	var made := 0
	for i in kinds.size():
		var offset: float = (float(i) - float(kinds.size() - 1) * 0.5) * spacing
		var where: Vector3 = at + side * offset
		_birth_specific(TIER_PRIMARY, where, nrm, int(kinds[i]))
		made += 1
	return made


func _birth_specific(tier: int, at: Vector3, nrm: Vector3, archetype: int) -> void:
	var indiv_seed := _seed_base + _next_id * 7919
	var morph = MorphologyScript.generate(archetype, indiv_seed)
	morph.length *= TIER_SCALE[tier]
	morph.base_radius *= TIER_SCALE[tier]
	var any := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
	var side := any.cross(nrm).normalized()
	palps.append({
		"id": _next_id, "tier": tier, "seed": indiv_seed, "morph": morph,
		"anchor": at, "normal": nrm, "side": side,
		"aim": nrm, "age": 1.2, "life": 9999.0, "grow": 1.0,
		"traits": BehaviorScript.personality(indiv_seed),
		"act": BehaviorScript.Act.HOVER, "act_clock": 0.0, "act_left": 9999.0,
		"target": Vector3.INF, "trace_angle": 0.0,
		"tip": at + nrm * float(morph.length),
		"last_tip": at + nrm * float(morph.length),
		"extend": 1.0,
	})
	_next_id += 1


## Facts for the contract.
## §22's last clause: NEARBY PALPS ORIENT TOWARD THE INTERACTION.
##
## Only the ones close enough to have felt it, and only by turning to look --
## this is not the director's seizure, which takes the whole ecology at once
## and is meant to be rare. A handful of appendages near a thing that just
## happened, turning toward it, is what makes the margin read as aware of its
## own neighbourhood rather than as scenery that occasionally animates.
func orient_nearby(at: Vector3, radius: float = 0.9) -> int:
	var turned := 0
	for p in palps:
		# Never override the director. If the whole ecology is already
		# attending to something, a local event does not get to redirect it.
		if p.get("attend_override", Vector3.INF) != Vector3.INF:
			continue
		if (p.anchor as Vector3).distance_to(at) > radius:
			continue
		p.attend_override = at
		p.local_look = true
		p.look_left = 1.4 + float(p.traits.curiosity) * 1.6
		p.act = BehaviorScript.Act.WATCH
		p.act_clock = 0.0
		p.act_left = float(p.look_left)
		turned += 1
	return turned


func census() -> Dictionary:
	var by_tier := [0, 0, 0]
	var by_kind := {}
	for p in palps:
		if int(p.parent) < 0:
			by_tier[int(p.tier)] += 1
		var k: String = p.morph.name_of_kind()
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	var by_act := {}
	for p in palps:
		var a: String = BehaviorScript.act_name(int(p.act))
		by_act[a] = int(by_act.get(a, 0)) + 1
	var social := 0
	var joined := 0
	var feel_hero := 0
	var joined_hero := 0
	var branches := 0
	var unfolding := 0
	var shared := {}
	for p in palps:
		if int(p.neighbour_count) > 0:
			social += 1
		if int(p.joined) >= 0:
			joined += 1
		if float(p.hero_near) > 0.01:
			feel_hero += 1
		if int(p.joined) == -2:
			joined_hero += 1
		if int(p.parent) >= 0:
			branches += 1
			if float(p.unfold) < 0.98:
				unfolding += 1
		if p.target != Vector3.INF:
			var key := "%.2f_%.2f_%.2f" % [p.target.x, p.target.y, p.target.z]
			shared[key] = int(shared.get(key, 0)) + 1
	var cooperating := 0
	for k in shared:
		if int(shared[k]) >= 2:
			cooperating += int(shared[k])
	return {"live": palps.size(), "tiers": by_tier, "kinds": by_kind,
			"born": _next_id, "acts": by_act,
			"with_neighbours": social, "joined_a_neighbour": joined,
			"cooperating": cooperating,
			"feel_hero": feel_hero, "joined_hero": joined_hero,
			"branches": branches, "unfolding": unfolding}
