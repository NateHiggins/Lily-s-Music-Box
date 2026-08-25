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
const LifecycleScript := preload("res://scripts/dream/dream_organelle_lifecycle.gd")
const MicroLightScript := preload("res://scripts/dream/dream_microbiology_light.gd")
const MicroMechanicsScript := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

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

## §12 STEP 8 — THE FINE CILIA, AND WHY EACH OF THESE IS A DURATION.
##
## The canonical sequence puts the cilia at step 8, one whole step AFTER the
## secondary branches begin investigating independently. That ordering is the
## content: an appendage that arrived already bristling would read as a spawn
## with more polygons on it. What §12 describes is an instrument being brought
## out — the branch separates, it goes and looks at the thing, and only then
## does the fine anatomy come out of it.
##
## So: how long a branch must be investigating something of its own before the
## cilia begin,
const CILIA_AFTER_S := 0.55
## how long they take to come out -- long enough that the ordered wave down
## the band is a thing you watch happen rather than a state change,
const CILIA_DEPLOY_S := 0.85
## how long they work once out, before the job is finished,
const CILIA_WORK_S := 1.30
## and how long step 10 takes to put them back.
const CILIA_RETRACT_S := 0.70
## Deployed cilia take a real interval to sample recognition before returning
## a vascular pulse. This is separate from the branch's ordinary task clock.
const CILIA_SIGNAL_SAMPLE_S := 0.48

## §12 STEP 9 — TASK COMPLETION IS A BEAT, NOT AN EDGE.
##
## Nothing in the sequence is instantaneous and this least of all: it is the
## one moment the branch stops investigating and reports. A boolean flipping
## between two frames is not a step of an anatomical sequence, it is a
## bookkeeping change, so it is given a real duration during which the branch
## holds still on the thing it has finished and the fine anatomy closes on it.
const TASK_S := 0.75

## How far a branch must have separated from its parent before it counts as
## investigating independently (§12 step 7). Below this it is still coming
## out of the parent and is not yet its own organ.
const UNFOLD_INVESTIGATING := 0.75

## Where step 11 begins, measured back from the end of an appendage's life.
## Named because steps 9 and 10 have to fit in FRONT of it: completion, then
## the fine anatomy retracting, and only then the branch folding away.
const LEAVE_S := 1.2

## §3's scale language, as multipliers on an archetype's authored length.
## The primaries run large: they are the ones the player walks up to, they
## carry the whole archetype library between them, and photographed at 1.0
## they were slivers on a wall at gameplay distance. §3 puts primary palps at
## 10-60 cm and this lands them there.
const TIER_SCALE := [1.35, 0.55, 0.24]
## LC-6A. Top-level incursions use the shared small-organelle life band. A
## branch's shorter `life` remains its already-approved work/unfold sequence,
## not a second independently breeding organism.
const TIER_LIFE_MIN_S := [90.0, 60.0, 45.0]
const TIER_LIFE_MAX_S := [150.0, 115.0, 90.0]
## LC-6B. A death is remembered by this visit's existing margin owner. The
## records are anatomical impressions, not save facts or new scene nodes.
const MAX_IMPRESSIONS := 24
const IMPRESSION_CELL_M := 0.18

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
## Flattened memories left after top-level organs withdraw. Branches are
## anatomy of their parent and fold back into it, so they do not manufacture
## independent corpses.
var impressions: Array = []

var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D = null
var _next_id := 0
var _spawn_clock := 0.0
var _clock := 0.0
var _social_clock := 0.0
var _board: Array = []
## Reused receptor scratch. Signal storage belongs to the ecology director;
## interpretation belongs here, at the organ that can actually answer it.
var _signal_near: Array = []
var _last_secretion_born := -INF
var _last_secretion_src := -2147483648
var _seed_base := 0
var _next_impression_id := 0
var _retired_slots := [0, 0, 0]
var _pending_recruits: Array = []
## One production-lamp sample per physics tick, shared by every local
## receptor. `lamp_pose()` raycasts, so asking once per cilium would turn a
## sensory detail into the most expensive thing in the ecology.
var _lamp_pose: Dictionary = {}


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
		# Once a lived organ has vacated a slot, ordinary stocking may not
		# silently replace it. Its local environment must have selected a mode
		# and left a recruitment record first.
		if int(_retired_slots[tier]) > 0:
			var request := _take_recruit(tier)
			if request.is_empty():
				continue
			_birth(tier, request.anchor, request.normal, request)
			_retired_slots[tier] = maxi(0, int(_retired_slots[tier]) - 1)
			break
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


func _birth(tier: int, at: Vector3, nrm: Vector3,
		recruit: Dictionary = {}) -> void:
	var choices: Array = TIER_ARCHETYPES[tier]
	var archetype: int = int(recruit.get("kind",
			choices[_rng.randi() % choices.size()]))
	# §37: at least six nearby appendages must be clearly different. Rolling
	# dice does not deliver that — photographed, the first population came out
	# 29 whiskers of 64, and the closest cluster held two archetypes between
	# six members. The PRIMARY tier is the one the player walks up to, so it
	# takes each archetype in turn and is guaranteed to show the whole
	# library. The lower tiers stay random: distributed sensing genuinely is
	# mostly whiskers.
	if tier == TIER_PRIMARY and recruit.is_empty():
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
	var indiv_seed := int(recruit.get("seed", _seed_base + _next_id * 7919))
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
		"life": _rng.randf_range(TIER_LIFE_MIN_S[tier], TIER_LIFE_MAX_S[tier]),
		# LC-6A: complete anatomy exists on its first frame. Emergence is a
		# folded wall posture in the renderer, never a zero-to-one scale.
		"grow": 1.0,
		"lifecycle_stage": LifecycleScript.Stage.FOLDED,
		"lifecycle_override": -1,
		"reproduction": int(recruit.get("mode",
				LifecycleScript.Reproduction.QUIESCENT)),
		"generation": int(recruit.get("generation", 0)),
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
	_lamp_pose = {}
	if field != null and field.player != null and field.player.has_method("lamp_pose"):
		_lamp_pose = field.player.lamp_pose()
	# §10 — the social pass, at its own cadence. Sixty-five appendages is
	# 2,080 pairs and none of this changes fast enough to need 60 Hz.
	_social_clock += delta
	var socialise: bool = _social_clock >= 0.18
	if socialise:
		_board = NeighborScript.broadcast(palps)
		_receive_signal_packets()
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
		# Unfolding, unless it has started folding back -- otherwise the two
		# fight and the branch shivers in place at the end of its life.
		if int(p.parent) >= 0 and float(p.unfold) < 1.0 				and not bool(p.get("folding", false)):
			p.unfold = minf(1.0, float(p.unfold) + delta * 0.75)
		# §12 STEPS 8, 9 AND 10 — but only on a branch, and only on one that
		# is actually working. See `_fine_anatomy`.
		if int(p.parent) >= 0:
			_fine_anatomy(p, delta)
		_update_photoreception(p, delta)
		_update_mechanoreception(p, delta)
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
		var before_contact: float = float(p.contact)
		var on_it := 0.0
		if p.target != Vector3.INF:
			on_it = 1.0 - smoothstep(0.012, 0.055,
					(p.tip as Vector3).distance_to(p.target))
		p.contact = maxf(on_it, float(p.contact) - delta * 2.2)
		_recognize_signal_target(p, before_contact)
		_propagate_signal_answer(p)
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


## §9's primitives, split by whether they are a relationship to a target.
##
## This is what "an INVESTIGATING branch" means in code. Probing, touching,
## tracing, tasting, bracing and sampling are all ways of working a thing that
## has been found. Hovering is what `next_act` returns when there is nothing
## to work; watching is attention pointed elsewhere; withdrawing and freezing
## are the opposite of investigation. A branch in one of those is IDLE, and an
## idle branch does not bring its instruments out.
static func _is_investigating_act(act: int) -> bool:
	match act:
		BehaviorScript.Act.PROBE, BehaviorScript.Act.TOUCH, 				BehaviorScript.Act.TRACE, BehaviorScript.Act.TASTE, 				BehaviorScript.Act.BRACE, BehaviorScript.Act.SAMPLE:
			return true
	return false


## §12 STEPS 8, 9 AND 10 ON ONE BRANCH — THE FINE ANATOMY.
##
##   7. secondary branches independently investigate
##   8. fine cilia deploy
##   9. task completes
##  10. fine anatomy retracts
##
## Steps 5-7 and 11-12 were built first, and between the branch arriving and
## the branch leaving there was nothing: it came out, it waved at something,
## it went back in. Four of the twelve steps are about what it does WHILE it
## is out, and three of those four are this.
##
## The shape is deliberately the same as steps 2-4, which is the one part of
## §12 that already reads correctly: a state is entered, a clock runs for a
## named number of seconds, and only when the clock finishes does the next
## thing become possible. Nothing here is allowed to happen on the frame that
## permits it.
##
## AND NOTHING HERE IS A SIZE. `cilia_out` is an angle, not a scale: at 0 the
## cilia are lying curled inside the shaft's own volume and at 1 they stand
## off it, at exactly the same length throughout. "Never spawn a branch by
## scaling a cylinder from zero" is the governing sentence of §12 and it does
## not stop applying because the cylinder got smaller.
func _fine_anatomy(p: Dictionary, delta: float) -> void:
	# STEP 10 IS CHECKED FIRST, so that nothing can deploy after the branch
	# has committed to going back in. Two ways in: the job finished, which is
	# the one §12 describes, or the branch simply ran out of life with the
	# instruments still out -- and even then the fine anatomy comes in before
	# the branch folds, because step 10 precedes step 11 either way.
	var retracting: bool = bool(p.task_done) 			or float(p.age) > float(p.life) - LEAVE_S - CILIA_RETRACT_S
	if retracting:
		p.cilia_out = maxf(0.0, float(p.cilia_out) - delta / CILIA_RETRACT_S)
		p.investigate = 0.0
		return
	_sample_signal_with_cilia(p, delta)
	# STEP 7 IS A PRECONDITION, NOT A LABEL. A branch is investigating on its
	# own account when it has separated far enough to be its own organ AND it
	# is doing one of §9's target-directed things about something real.
	if float(p.unfold) < UNFOLD_INVESTIGATING or p.target == Vector3.INF 			or not _is_investigating_act(int(p.act)):
		# Idle. The instruments stay where they are -- they do not come out,
		# and they do not go back in either, because a branch that pauses
		# mid-job has not finished the job.
		return
	p.investigate = float(p.investigate) + delta
	# STEP 9 — THE COMPLETION BEAT, once it is running. It holds the branch
	# for TASK_S and nothing else about the fine anatomy moves during it.
	if float(p.task_left) > 0.0:
		p.task_left = float(p.task_left) - delta
		if float(p.task_left) <= 0.0:
			p.task_left = 0.0
			p.task_done = true
			# AND THE REST OF THE SEQUENCE FOLLOWS FROM IT, IN ORDER. The
			# branch's remaining life is cut to exactly step 10 plus step 11,
			# so retraction begins now and folding begins when retraction has
			# finished. Before this the branch died on its own timer and the
			# order of 9, 10 and 11 was a coincidence of two clocks.
			p.life = minf(float(p.life),
					float(p.age) + CILIA_RETRACT_S + LEAVE_S)
		return
	# STEP 8 — DEPLOYMENT. Not until the branch has been investigating for
	# CILIA_AFTER_S, and then over CILIA_DEPLOY_S rather than at once. The
	# ORDER along the band is the renderer's: this is the one clock the wave
	# runs against.
	if float(p.investigate) < CILIA_AFTER_S:
		return
	if float(p.cilia_out) < 1.0:
		p.cilia_out = minf(1.0, float(p.cilia_out) + delta / CILIA_DEPLOY_S)
		return
	# Out, and working. When the work is done, step 9 begins: the branch
	# plants on what it has finished and stops, which among a dozen moving
	# things is the most readable thing it can do.
	if float(p.investigate) >= CILIA_AFTER_S + CILIA_DEPLOY_S + CILIA_WORK_S:
		p.task_left = TASK_S
		p.act = BehaviorScript.Act.BRACE
		p.act_clock = 0.0
		# Enough that the general act timer cannot expire underneath the beat
		# and hand it to `next_act` half way through.
		p.act_left = TASK_S + 0.15


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


## LC-6A. The shared words, interpreted by the clock this owner already has.
## Top-level palps use normalized age. Branches are folded anatomy within a
## parent, so their established §12 sequence is the honest clock: unfold,
## investigate, exchange/complete, retract and shed.
static func lifecycle_stage_of(p: Dictionary) -> int:
	var override := int(p.get("lifecycle_override", -1))
	if override >= 0:
		return clampi(override, LifecycleScript.Stage.FOLDED,
				LifecycleScript.Stage.STAIN)
	if int(p.get("parent", -1)) >= 0:
		if bool(p.get("folding", false)):
			return LifecycleScript.Stage.SHED
		if bool(p.get("task_done", false)):
			return LifecycleScript.Stage.SENESCENT
		if float(p.get("task_left", 0.0)) > 0.0:
			return LifecycleScript.Stage.EXCHANGE
		var unfolded := float(p.get("unfold", 0.0))
		if unfolded < 0.08:
			return LifecycleScript.Stage.FOLDED
		if unfolded < 0.42:
			return LifecycleScript.Stage.BUD
		if unfolded < UNFOLD_INVESTIGATING:
			return LifecycleScript.Stage.JUVENILE
		if float(p.get("cilia_out", 0.0)) >= 0.98:
			return LifecycleScript.Stage.EXCHANGE
		return LifecycleScript.Stage.MATURE
	var life := maxf(0.001, float(p.get("life", 1.0)))
	return LifecycleScript.stage_at(float(p.get("age", 0.0)) / life)


func _age(delta: float) -> void:
	var i := palps.size() - 1
	while i >= 0:
		var p: Dictionary = palps[i]
		p.age += delta
		# LC-6A: the owner clock classifies; the renderer poses complete tissue.
		# Branches retain §12's own functional sequence and are classified by it.
		p.lifecycle_stage = lifecycle_stage_of(p)
		# Named, because §12 steps 9 and 10 have to fit in front of it.
		var leave := LEAVE_S
		var going: float = 0.0
		if p.age > p.life - leave:
			going = smoothstep(0.0, 1.0, (p.age - (p.life - leave)) / leave)
		if int(p.parent) >= 0:
			# §12 STEPS 10-12 — IT FOLDS BACK IN. A branch that scales down to
			# nothing is the same error as one that scales up from nothing:
			# "never spawn a branch by scaling a cylinder from zero" is a
			# statement about anatomy, and anatomy does not leave that way
			# either. It lies back down along its parent, which is exactly
			# where it came from, and is gone when it is indistinguishable
			# from it.
			#
			# It was also BORN at full size in `try_branch`. Do not overwrite
			# that fact with the primary appendage's emergence ramp: separation
			# is carried exclusively by `unfold`, while `grow` stays an invariant
			# statement about the branch's already-present anatomy.
			p.grow = 1.0
			p.folding = going > 0.0
			if going > 0.0:
				p.unfold = 1.0 - going
		else:
			# A top-level palp folds back against the architecture when shed. It
			# never becomes a smaller palp on the way in or out.
			p.grow = 1.0
		if p.age >= p.life:
			# §12 STEP 12 — THE PARENT RETURNS TO SIMPLER TOPOLOGY. Its child
			# count was set when it branched and never put back, so an
			# appendage stayed marked as branched for the rest of its life
			# long after the branches had gone -- and since try_branch refuses
			# a parent that already has children, it could never do it twice.
			if int(p.parent) >= 0:
				var par: Dictionary = parent_of(p)
				if not par.is_empty():
					par.children = maxi(0, int(par.children) - 1)
			else:
				_remember_death(p)
				_retired_slots[int(p.tier)] = int(_retired_slots[int(p.tier)]) + 1
				_queue_environmental_recruit(p)
			palp_died.emit(int(p.id))
			palps.remove_at(i)
		i -= 1


## Local facts become the shared lifecycle vocabulary. `food` is the nearest
## live field lobe's intensity at this architectural patch. Ether is not a
## second gas simulation here: it is the local signal/exchange fraction in
## the one body, the same electrochemical work the palps already publish.
func lifecycle_environment(p: Dictionary) -> Dictionary:
	var neighbours: Array = []
	var kinds := {}
	var same := 0
	var cross := 0
	var signalling := 0
	for other in palps:
		if int(other.get("parent", -1)) >= 0 or int(other.id) == int(p.id):
			continue
		if (other.anchor as Vector3).distance_to(p.anchor) > 1.5:
			continue
		neighbours.append(other)
		kinds[int(other.morph.kind)] = true
		var mature := lifecycle_stage_of(other) in [
				LifecycleScript.Stage.MATURE, LifecycleScript.Stage.EXCHANGE]
		if mature and int(other.morph.kind) == int(p.morph.kind):
			same += 1
		elif mature:
			cross += 1
		if lifecycle_stage_of(other) == LifecycleScript.Stage.EXCHANGE \
				or bool(other.get("signal_recognized", false)) \
				or float(other.get("cilia_out", 0.0)) > 0.5:
			signalling += 1
	var local_count := neighbours.size() + 1
	var tier := int(p.tier)
	return {
		"food": _field_food_at(p.anchor),
		"ether": clampf(float(signalling) / float(maxi(1, neighbours.size())),
				0.0, 1.0),
		"density": clampf(float(_count_in_tier(tier))
				/ float(TIER_CAPS[tier]), 0.0, 1.0),
		"diversity": clampf(float(kinds.size() + 1) / float(local_count), 0.0, 1.0),
		"same_compatibility": 0.82 if same > 0 else 0.0,
		"cross_compatibility": 0.78 if cross > 0 else 0.0,
	}


func _field_food_at(at: Vector3) -> float:
	if field == null or field.state == null:
		return 0.0
	var best := 0.0
	for i in field.state.lobes.size():
		if not field.state.lobe_present(i):
			continue
		var l: Dictionary = field.state.lobes[i]
		var radius: float = field.state.slice_radius(float(l.radius),
				float(l.w_offset))
		var nearness := 1.0 - clampf(at.distance_to(l.centre)
				/ maxf(0.001, radius + 1.2), 0.0, 1.0)
		best = maxf(best, float(l.intensity) * nearness)
	return clampf(best, 0.0, 1.0)


func _queue_environmental_recruit(dead: Dictionary) -> void:
	var environment := lifecycle_environment(dead)
	var mode := LifecycleScript.reproduction_for(environment)
	if mode == LifecycleScript.Reproduction.QUIESCENT:
		return
	var partner := _compatible_partner(dead, mode)
	var seed_v := int(dead.seed) + 104729
	if not partner.is_empty():
		# A deterministic fold of two lived patterns. The receiving organ's kind
		# remains fixed below; the mixed seed only varies its bounded anatomy,
		# surface affinity and personality inside that archetype.
		seed_v = int(dead.seed) ^ (int(partner.seed) * 31 + 104729)
	_pending_recruits.append({
		"tier": int(dead.tier), "kind": int(dead.morph.kind), "seed": seed_v,
		"anchor": dead.anchor, "normal": dead.normal, "mode": mode,
		"generation": int(dead.get("generation", 0)) + 1,
	})


func _compatible_partner(subject: Dictionary, mode: int) -> Dictionary:
	if mode == LifecycleScript.Reproduction.ASEXUAL:
		return {}
	var want_same := mode == LifecycleScript.Reproduction.SEXUAL
	var candidates: Array = []
	for other in palps:
		if int(other.get("parent", -1)) >= 0 or int(other.id) == int(subject.id):
			continue
		if (other.anchor as Vector3).distance_to(subject.anchor) > 1.5:
			continue
		if lifecycle_stage_of(other) not in [LifecycleScript.Stage.MATURE,
				LifecycleScript.Stage.EXCHANGE]:
			continue
		if (int(other.morph.kind) == int(subject.morph.kind)) != want_same:
			continue
		candidates.append(other)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b): return int(a.id) < int(b.id))
	return candidates[0]


func _take_recruit(tier: int) -> Dictionary:
	for i in _pending_recruits.size():
		if int(_pending_recruits[i].tier) == tier:
			var request: Dictionary = _pending_recruits[i]
			_pending_recruits.remove_at(i)
			return request
	return {}


func _remember_death(p: Dictionary) -> void:
	var cell := Vector3i(roundi(float(p.anchor.x) / IMPRESSION_CELL_M),
			roundi(float(p.anchor.y) / IMPRESSION_CELL_M),
			roundi(float(p.anchor.z) / IMPRESSION_CELL_M))
	var key := "%d:%d:%d:%d" % [cell.x, cell.y, cell.z, int(p.morph.kind)]
	for stain in impressions:
		if String(stain.key) == key:
			stain.deaths = int(stain.deaths) + 1
			stain.last_death_id = int(p.id)
			return
	var memory := p.duplicate(true)
	memory.id = _next_impression_id
	memory.key = key
	memory.deaths = 1
	memory.last_death_id = int(p.id)
	memory.lifecycle_override = LifecycleScript.Stage.STAIN
	memory.lifecycle_stage = LifecycleScript.Stage.STAIN
	memory.age = memory.life
	memory.grow = 1.0
	memory.extend = 1.0
	memory.cilia_out = 0.0
	impressions.append(memory)
	_next_impression_id += 1
	if impressions.size() > MAX_IMPRESSIONS:
		impressions.remove_at(0)


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
## §12's sequence in full is twelve steps. Steps 2-4 are the tell, driven by
## `swell` and drawn by the shader; 5 to 7 are this function and the unfolding
## in `_think`; 8 to 10 are `_fine_anatomy`; 11 and 12 are `_age` putting a
## branch back down along its parent and handing the topology back.
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
		# Local organelle communication. These clocks and flags last only for
		# this appendage's life and never enter RealityState.
		"signal_target": Vector3.INF,
		"signal_adopted_at": -1.0,
		"signal_recognized": false,
		"signal_recognized_at": -1.0,
		"signal_orient_due": -1.0,
		"signal_oriented_at": -1.0,
		"signal_neighbours": 0,
		"cilia_signal_src": -2147483648,
		"cilia_signal_born": -1.0,
		"cilia_signal_clock": -1.0,
		"cilia_signal_sampled_at": -1.0,
		"cilia_signal_pulsed_at": -1.0,
		# MBIO-1. Transient receptor memory belongs to the organ carrying it;
		# it is neither a field channel nor a save fact.
		"photo": MicroLightScript.state(),
		"photo_side": 0.0,
		"mechanical": MicroMechanicsScript.state(),
		# §12 steps 2-4: the swelling that precedes a branch, and where along
		# the organ it is happening.
		"swell": 0.0,
		"swell_v": 0.6,
		# §12 step 11: whether it is on its way back into its parent.
		"folding": false,
		# §12 step 7: how long this appendage has been investigating something
		# of its OWN. Cilia are gated on this and not on the clock, because
		# "after the branch appears" and "after it starts investigating" are
		# different moments and §12 asks for the second one.
		"investigate": 0.0,
		# §12 step 8: how far the fine anatomy is out. 0 is not "absent" -- it
		# is lying curled inside the shaft's own volume, which is the same
		# claim §12 makes about a folded branch one level up. 1 is fully
		# erect. Nothing between those is a size.
		"cilia_out": 0.0,
		# Where along the organ the ciliated band sits.
		"cilia_band": 0.62,
		# §12 step 9: seconds left of the completion beat, and whether it has
		# already happened. `task_done` is what lets step 10 begin, so the two
		# cannot get out of order.
		"task_left": 0.0,
		"task_done": false,
		# LC-6A: presentation classification owned by this appendage's existing
		# clock. Review arrangements may override it without changing their age.
		"lifecycle_stage": LifecycleScript.Stage.MATURE,
		"lifecycle_override": -1,
		# THE TOPOLOGY, FOR THE APPENDAGES BORN THROUGH `_birth_specific`.
		#
		# The other two births set all three of these in their own literals,
		# and merging non-destructively cannot disturb that. §37's arrangement
		# row sets none of them, so an arrangement palp reaching `_think`
		# raises on `p.parent` -- the exact failure this dictionary exists to
		# prevent, one row further down the same list.
		"parent": -1,
		"unfold": 1.0,
		"children": 0,
		# Secondary births supply their own fan angle. Primary acceptance-row
		# palps have no parent to fan away from, but the live topology update
		# still reads the field while attention is released.
		"spread": 0.0,
	}


## A cilium carpet answers light by changing its beat, not by glowing. Only
## already-deployed, strongly ciliated anatomy is a receptor; the lamp cannot
## skip the established unfold/investigate/deploy sequence.
func _update_photoreception(p: Dictionary, delta: float) -> void:
	var receptor: Dictionary = p.photo
	var receptive := float(p.morph.cilia) >= 0.52 \
			and float(p.get("cilia_out", 0.0)) >= 0.08
	var sample := MicroLightScript.sample(_lamp_pose, p.tip) if receptive \
			else {"level": 0.0, "toward": Vector3.ZERO}
	MicroLightScript.advance(receptor, float(sample.level), delta)
	var toward: Vector3 = sample.get("toward", Vector3.ZERO)
	p.photo_side = clampf(toward.dot(p.side as Vector3), -1.0, 1.0) \
			if toward.length_squared() > 0.0 else 0.0


## Fine cilia are broad-band surface receptors. Their own substrate decides
## which travelling packet is meaningful; the signal bed does not command it.
func _update_mechanoreception(p: Dictionary, delta: float) -> void:
	var receptor: Dictionary = p.mechanical
	MicroMechanicsScript.advance(receptor, delta)
	if director == null or float(p.morph.cilia) < 0.52 \
			or float(p.get("cilia_out", 0.0)) < 0.08:
		return
	if director.signals_near(p.tip, 0.0, _signal_near) <= 0:
		return
	var normal: Vector3 = p.get("normal", Vector3.UP)
	var substrate := DreamEcologyDirector.Substrate.FLOOR \
			if absf(normal.dot(Vector3.UP)) >= 0.65 \
			else DreamEcologyDirector.Substrate.WALL
	var mask := MicroMechanicsScript.IMPULSE | MicroMechanicsScript.SCRAPE \
			| MicroMechanicsScript.HUM
	for packet in _signal_near:
		if MicroMechanicsScript.accept(receptor, packet, mask, substrate):
			break


## A secretion is an invitation, not a command. At the social cadence, the
## nearest unoccupied palp whose body is inside it adopts the point as an
## object of inquiry. One packet recruits one palp; the answer may recruit
## others later, after actual contact establishes recognition.
func _receive_signal_packets() -> void:
	if director == null or palps.is_empty():
		return
	var chosen = null
	var chosen_packet = null
	var nearest := INF
	for p in palps:
		if p.target != Vector3.INF or p.get("attend_override", Vector3.INF) != Vector3.INF:
			continue
		if director.signals_near(p.tip, 0.0, _signal_near) <= 0:
			continue
		for packet in _signal_near:
			if int(packet.function) != DreamEcologyDirector.Fn.SECRETE \
					or int(packet.family) != DreamEcologyDirector.Chem.SECRETION \
					or float(packet.sign) <= 0.0:
				continue
			var affinity: int = int(packet.affinity)
			if affinity >= 0 and affinity != DreamEcologyDirector.SrcClass.PALP:
				continue
			if int(packet.src_id) == _last_secretion_src \
					and float(packet.born) <= _last_secretion_born:
				continue
			var d: float = (p.tip as Vector3).distance_to(packet.at)
			if d < nearest:
				nearest = d
				chosen = p
				chosen_packet = packet
	if chosen == null:
		return
	chosen.target = chosen_packet.at
	chosen.signal_target = chosen_packet.at
	chosen.signal_adopted_at = director.signal_time()
	chosen.signal_recognized = false
	chosen.signal_recognized_at = -1.0
	chosen.signal_orient_due = -1.0
	chosen.signal_oriented_at = -1.0
	chosen.signal_neighbours = 0
	_last_secretion_born = float(chosen_packet.born)
	_last_secretion_src = int(chosen_packet.src_id)
	chosen.act = BehaviorScript.Act.PROBE
	chosen.act_clock = 0.0
	chosen.act_left = BehaviorScript.duration(BehaviorScript.Act.PROBE,
			chosen.traits, _rng)


## Recognition is emitted once, on the contact threshold's rising edge. A
## palp hovering near a secretion has not yet understood anything.
func _recognize_signal_target(p: Dictionary, before_contact: float) -> void:
	if director == null or bool(p.get("signal_recognized", false)):
		return
	if p.get("signal_target", Vector3.INF) == Vector3.INF:
		return
	if before_contact >= 0.5 or float(p.contact) < 0.5:
		return
	var source_class := DreamEcologyDirector.SrcClass.BRANCH \
			if int(p.parent) >= 0 else DreamEcologyDirector.SrcClass.PALP
	director.emit_signal_packet(int(p.id), source_class,
			DreamEcologyDirector.Fn.RECOGNIZE, p.tip, 0.85, 1.0,
			DreamEcologyDirector.Chem.ELECTRIC, 1.0, 1.2)
	p.signal_recognized = true
	p.signal_recognized_at = director.signal_time()
	p.signal_orient_due = director.signal_time() + 0.45


## The margin carries the answer outward on its own delay. This is local
## tissue conduction, not the rare whole-body attention event.
func _propagate_signal_answer(p: Dictionary) -> void:
	if director == null or float(p.get("signal_orient_due", -1.0)) < 0.0:
		return
	if director.signal_time() < float(p.signal_orient_due):
		return
	p.signal_orient_due = -1.0
	p.signal_oriented_at = director.signal_time()
	p.signal_neighbours = orient_nearby(p.tip, 0.9, int(p.id))


## Fine cilia interpret recognition differently from fauna. They close across
## the sampled site for a duration, then return a vascular pulse intended for
## living architecture. The next recipient lane will decide what architecture
## does with it; this owner does not route that answer on its behalf.
func _sample_signal_with_cilia(p: Dictionary, delta: float) -> void:
	if director == null or float(p.get("cilia_out", 0.0)) < 0.95 \
			or bool(p.get("task_done", false)):
		return
	var clock: float = float(p.get("cilia_signal_clock", -1.0))
	if clock >= 0.0:
		clock += delta
		p.cilia_signal_clock = clock
		if clock < CILIA_SIGNAL_SAMPLE_S:
			return
		p.cilia_signal_clock = -1.0
		p.cilia_signal_pulsed_at = director.signal_time()
		director.emit_signal_packet(int(p.id), DreamEcologyDirector.SrcClass.CILIA,
				DreamEcologyDirector.Fn.PULSE, p.tip, 1.1, 0.65,
				DreamEcologyDirector.Chem.VASCULAR, 1.0, 1.0,
				DreamEcologyDirector.SrcClass.ARCHITECTURE)
		return
	if director.signals_near(p.tip, 0.0, _signal_near) <= 0:
		return
	for packet in _signal_near:
		if int(packet.function) != DreamEcologyDirector.Fn.RECOGNIZE \
				or int(packet.family) != DreamEcologyDirector.Chem.ELECTRIC:
			continue
		if int(packet.src_id) == int(p.id):
			continue
		if int(packet.src_id) == int(p.get("cilia_signal_src", -2147483648)) \
				and float(packet.born) <= float(p.get("cilia_signal_born", -1.0)):
			continue
		var affinity: int = int(packet.affinity)
		if affinity >= 0 and affinity != DreamEcologyDirector.SrcClass.CILIA:
			continue
		p.cilia_signal_src = int(packet.src_id)
		p.cilia_signal_born = float(packet.born)
		p.cilia_signal_clock = 0.0
		p.cilia_signal_sampled_at = director.signal_time()
		break


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
			"lifecycle_stage": LifecycleScript.Stage.FOLDED,
			"lifecycle_override": -1,
			"traits": BehaviorScript.personality(indiv_seed),
			"act": BehaviorScript.Act.PROBE, "act_clock": 0.0,
			"act_left": BehaviorScript.duration(BehaviorScript.Act.PROBE,
					BehaviorScript.personality(indiv_seed), _rng),
			"target": parent.target, "trace_angle": _rng.randf_range(0.0, TAU),
			"tip": parent.tip, "last_tip": parent.tip,
			"neighbour_count": 0, "joined": -1, "hero_near": 0.0,
			"parent": id, "unfold": 0.0, "children": 0,
			"spread": spread,
			# §12 step 8: where this individual's ciliated band sits. Toward
			# the working end, because that is the end that is doing the work,
			# but never ON the tip -- the tip is the thing they surround.
			"cilia_band": _rng.randf_range(0.52, 0.76),
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
		"lifecycle_stage": LifecycleScript.Stage.MATURE,
		"lifecycle_override": LifecycleScript.Stage.MATURE,
		"traits": BehaviorScript.personality(indiv_seed),
		"act": BehaviorScript.Act.HOVER, "act_clock": 0.0, "act_left": 9999.0,
		"target": Vector3.INF, "trace_angle": 0.0,
		"tip": at + nrm * float(morph.length),
		"last_tip": at + nrm * float(morph.length),
		"extend": 1.0,
	})
	# THE SAME MERGE AS THE OTHER TWO BIRTHS. This one was written for a
	# review arrangement that is never stepped, so it got away with carrying
	# none of the shared state -- but "never stepped" is a property of the one
	# caller, not of the function, and the failure it invites is the silent
	# one documented on `_shared_state`.
	palps[palps.size() - 1].merge(_shared_state(), false)
	_next_id += 1


## Facts for the contract.
## §22's last clause: NEARBY PALPS ORIENT TOWARD THE INTERACTION.
##
## Only the ones close enough to have felt it, and only by turning to look --
## this is not the director's seizure, which takes the whole ecology at once
## and is meant to be rare. A handful of appendages near a thing that just
## happened, turning toward it, is what makes the margin read as aware of its
## own neighbourhood rather than as scenery that occasionally animates.
func orient_nearby(at: Vector3, radius: float = 0.9, exclude_id: int = -1) -> int:
	var turned := 0
	for p in palps:
		if int(p.id) == exclude_id:
			continue
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
	# §12 steps 8-10, as four separate readings, because "some cilia exist"
	# says nothing about whether the sequence is running in order.
	var deploying := 0
	var ciliated := 0
	var completing := 0
	var completed := 0
	var photo_receptors := 0
	var photo_responding := 0
	var photoshocks := 0
	var mechanical_receptors := 0
	var mechanical_responding := 0
	var mechanical_received := 0
	var shared := {}
	var stages := {}
	for p in palps:
		var stage_name := LifecycleScript.stage_name(lifecycle_stage_of(p))
		stages[stage_name] = int(stages.get(stage_name, 0)) + 1
		var out_at: float = float(p.get("cilia_out", 0.0))
		if out_at > 0.02 and out_at < 0.98:
			deploying += 1
		if out_at >= 0.98:
			ciliated += 1
		if float(p.get("task_left", 0.0)) > 0.0:
			completing += 1
		if bool(p.get("task_done", false)):
			completed += 1
		if float(p.morph.cilia) >= 0.52 and out_at >= 0.08:
			photo_receptors += 1
		var photo: Dictionary = p.get("photo", {})
		if float(photo.get("response", 0.0)) > 0.02:
			photo_responding += 1
		photoshocks += int(photo.get("shocks", 0))
		if float(p.morph.cilia) >= 0.52 and out_at >= 0.08:
			mechanical_receptors += 1
		var mechanical: Dictionary = p.get("mechanical", {})
		if float(mechanical.get("response", 0.0)) > 0.02:
			mechanical_responding += 1
		mechanical_received += int(mechanical.get("received", 0))
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
			"impressions": impressions.size(),
			"remembered_deaths": impressions.reduce(
					func(total, stain): return total + int(stain.deaths), 0),
			"pending_recruits": _pending_recruits.size(),
			"retired_slots": _retired_slots.duplicate(),
			"with_neighbours": social, "joined_a_neighbour": joined,
			"cooperating": cooperating,
			"feel_hero": feel_hero, "joined_hero": joined_hero,
			"branches": branches, "unfolding": unfolding,
			"cilia_deploying": deploying, "ciliated": ciliated,
			"completing": completing, "completed": completed,
			"photo_receptors": photo_receptors,
			"photo_responding": photo_responding,
			"photoshocks": photoshocks,
			"mechanical_receptors": mechanical_receptors,
			"mechanical_responding": mechanical_responding,
			"mechanical_received": mechanical_received,
			"lifecycle_stages": stages}
