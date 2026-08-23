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

## §29's population tiers. Counts are ceilings, not targets: the margin only
## carries what the field's cross-section actually reaches.
const TIER_PRIMARY := 0
const TIER_SECONDARY := 1
const TIER_TERTIARY := 2
const TIER_CAPS := [6, 20, 60]

## §3's scale language, as multipliers on an archetype's authored length.
const TIER_SCALE := [1.0, 0.55, 0.24]

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

var field: DreamFieldController = null
var enabled := true
## Every live appendage. Index is stable for its lifetime, and the seed is
## preserved across LOD promotion (§30) because identity must survive it.
var palps: Array = []

var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D = null
var _next_id := 0
var _spawn_clock := 0.0
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


func _physics_process(delta: float) -> void:
	if not enabled or field == null or field.state == null:
		return
	_spawn_clock += delta
	if _spawn_clock >= 0.12:
		_spawn_clock = 0.0
		_populate()
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
		var anchor := _find_surface()
		if anchor.is_empty():
			return
		_birth(tier, anchor["position"], anchor["normal"])
		break


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
	})
	palp_born.emit(_next_id, tier, archetype)
	_next_id += 1


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


func _count_in_tier(tier: int) -> int:
	var n := 0
	for p in palps:
		if int(p.tier) == tier:
			n += 1
	return n


## --- hooks that are declared and NOT yet implemented -------------------
## Named so the architecture is legible and so nobody mistakes their silence
## for completion. §35 phases 5, 6, 8 and 12.

## Phase 5. Stable per-individual traits: curiosity, boldness, startle
## threshold, contact persistence, social affinity, hero affinity...
func personality_of(_id: int) -> Dictionary:
	return {}

## Phase 6. Neighbour broadcast: tip position, occupancy, target, interest,
## contact and startle state. Avoidance, grooming, bracing, mimicry.
func neighbours_of(_id: int) -> Array:
	return []

## Phase 8. Recursive unfolding — never by scaling a cylinder from zero.
func try_branch(_id: int) -> bool:
	return false


## Facts for the contract.
func census() -> Dictionary:
	var by_tier := [0, 0, 0]
	var by_kind := {}
	for p in palps:
		by_tier[int(p.tier)] += 1
		var k: String = p.morph.name_of_kind()
		by_kind[k] = int(by_kind.get(k, 0)) + 1
	return {"live": palps.size(), "tiers": by_tier, "kinds": by_kind,
			"born": _next_id}
