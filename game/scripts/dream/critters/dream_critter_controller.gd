class_name DreamCritterController
extends Node3D
## Level 3 of the ecology, in the world (§14, §19, §20, §21).
##
## Individuals of three species live on the surfaces the Dream has reached,
## walk them at their own pace, and use the margin as habitat. §21 is the
## point of putting them here at all: *"This turns the wall into a functioning
## biome."*
##
## Eight at a time, all in one mesh and one draw, because the frame is
## submission-bound.

const SpeciesScript := preload("res://scripts/dream/critters/dream_critter_species.gd")
const GeneratorScript := preload("res://scripts/dream/critters/dream_critter_generator.gd")
const SHADER := preload("res://shaders/dream_critter.gdshader")
const MicroLightScript := preload("res://scripts/dream/dream_microbiology_light.gd")
const MicroMechanicsScript := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

# Twelve buffer slots for eight animals: a seam grazer that is occupying both
# sides of a wall needs two of them, because it is ONE animal appearing twice.
const MAX_CRITTERS := 12
const MAX_LIVE := 8
const MAX_LIMBS := 8
const MAX_FEELERS := 12
# Photographed at 40 cm the body showed its polygons on the silhouette, which
# is the one place a low-poly count always tells.
const BODY_RINGS := 13
const BODY_SEGS := 18
const LIMB_RINGS := 5
# Five segments is a pentagonal prism and four is a square one, which is why
# the legs and cilia photographed as bars and slabs rather than as limbs.
const LIMB_SEGS := 8
const FEELER_RINGS := 5
const FEELER_SEGS := 6

signal critter_born(id: int, species: String)
signal critter_died(id: int)

var field: DreamFieldController = null
var margin = null
var residue = null
var hero = null
## §32 — the area's weather, read as a scale on how much anything happens.
var director = null
## When installed by ApartmentEncroachment, complex births consult the E1 moss
## authority. Standalone morphology harnesses leave this null and retain their
## local test contract.
var ecology_director = null
var enabled := true
var critters: Array = []

var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D = null
var _next_id := 0
var _clock := 0.0
var _spawn_clock := 0.0
## Reused receptor scratch; the fauna owns what recognition means to it.
var _signal_near: Array = []

var _pos := PackedVector4Array()
var _fwd := PackedVector4Array()
var _up := PackedVector4Array()
var _size := PackedVector4Array()
var _matter := PackedVector4Array()
var _counts := PackedVector4Array()
var _law := PackedVector4Array()
## MBIO-1: the listener's local receptor state in the existing draw.
var _photo := PackedVector4Array()
## MBIO-3: the same local mechanical response in the existing fauna draw.
var _mechanical := PackedVector4Array()
## §26 — per-individual material balance: x hue bias, y perfusion,
## z wetness, w iridescence.
var _look := PackedVector4Array()
var _lamp_pose: Dictionary = {}


func setup(controller: DreamFieldController, seed_v: int) -> void:
	name = "DreamCritterController"
	enabled = OS.get_environment("DREAM_CRITTERS") != "0"
	field = controller
	_rng.seed = seed_v
	for arr in [_pos, _fwd, _up, _size, _matter, _counts, _law, _look, _photo,
			_mechanical]:
		arr.resize(MAX_CRITTERS)
	material = ShaderMaterial.new()
	material.shader = SHADER
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Critters"
	mesh_instance.mesh = _build_mesh()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.extra_cull_margin = 20.0
	add_child(mesh_instance)
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world != null:
		_space = world.direct_space_state


## One buffer holding eight animals: a body, eight limbs and twelve feelers
## each. UV2.y tags the part so one vertex program can build three anatomies.
func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var indices := PackedInt32Array()
	for c in MAX_CRITTERS:
		# Body: a unit sphere the vertex stage reshapes per body plan.
		var base := verts.size()
		for r in BODY_RINGS:
			var v := float(r) / float(BODY_RINGS - 1)
			var polar := v * PI
			for sgm in BODY_SEGS:
				var u := float(sgm) / float(BODY_SEGS - 1)
				var a := u * TAU
				var p := Vector3(sin(polar) * cos(a), cos(polar), sin(polar) * sin(a))
				verts.append(p)
				normals.append(p.normalized())
				uvs.append(Vector2(u, v))
				uv2.append(Vector2(float(c), 0.0))
		for r in BODY_RINGS - 1:
			for sgm in BODY_SEGS - 1:
				var a0 := base + r * BODY_SEGS + sgm
				indices.append(a0); indices.append(a0 + BODY_SEGS); indices.append(a0 + 1)
				indices.append(a0 + 1); indices.append(a0 + BODY_SEGS); indices.append(a0 + BODY_SEGS + 1)
		_append_tubes(verts, normals, uvs, uv2, indices, c, 1.0,
				MAX_LIMBS, LIMB_RINGS, LIMB_SEGS)
		_append_tubes(verts, normals, uvs, uv2, indices, c, 2.0,
				MAX_FEELERS, FEELER_RINGS, FEELER_SEGS)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	return mesh


func _append_tubes(verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, uv2: PackedVector2Array,
		indices: PackedInt32Array, c: int, part: float,
		count: int, rings: int, segs: int) -> void:
	for k in count:
		var base := verts.size()
		for r in rings:
			var along := float(r) / float(rings - 1)
			for sgm in segs:
				var a := float(sgm) / float(segs - 1) * TAU
				verts.append(Vector3.ZERO)
				normals.append(Vector3(cos(a), sin(a), 0.0))
				uvs.append(Vector2(float(k), along))
				uv2.append(Vector2(float(c), part))
		for r in rings - 1:
			for sgm in segs - 1:
				var a0 := base + r * segs + sgm
				indices.append(a0); indices.append(a0 + segs); indices.append(a0 + 1)
				indices.append(a0 + 1); indices.append(a0 + segs); indices.append(a0 + segs + 1)


func _physics_process(delta: float) -> void:
	if not enabled or field == null or field.state == null:
		return
	_clock += delta
	_spawn_clock += delta
	_lamp_pose = {}
	if field.player != null and field.player.has_method("lamp_pose"):
		_lamp_pose = field.player.lamp_pose()
	if _spawn_clock >= 0.9:
		_spawn_clock = 0.0
		if critters.size() < MAX_LIVE:
			_try_spawn()
	_walk(delta)
	_apply_ecology_support(delta)
	_push()


## They live where the Dream has reached, so they are born on a surface a live
## lobe can see — the same rule the margin uses.
func _try_spawn() -> void:
	if _space == null:
		return
	var st := field.state
	var live: Array = []
	for i in st.lobes.size():
		if st.lobe_present(i):
			live.append(i)
	if live.is_empty():
		return
	var l: Dictionary = st.lobes[live[_rng.randi() % live.size()]]
	var centre: Vector3 = l.centre
	var birth_colony = null
	if ecology_director != null:
		var eligible: Array = []
		var colony_ids: Array = ecology_director.moss_colonies.keys()
		colony_ids.sort()
		for colony_id in colony_ids:
			var candidate_colony = ecology_director.moss_colonies[colony_id]
			if candidate_colony.complex_unlocked() and candidate_colony.ether_at(candidate_colony.origin) >= 0.12:
				eligible.append(candidate_colony)
		if eligible.is_empty():
			return
		birth_colony = eligible[_rng.randi() % eligible.size()]
		# Complex organisms hatch from the dense atmosphere that authorized
		# them, rather than hoping a random field lobe happens to overlap it.
		centre = birth_colony.origin + birth_colony.origin.direction_to(l.centre) * 0.08
	# THE HERO IS WHERE THE DREAM IS STRONGEST HERE, so some of them are born
	# around it rather than anywhere the field happens to reach. Left purely to
	# chance, critters and the hero met only occasionally -- the §22 beat where
	# several flee and one remains cannot happen to animals that are never in
	# the same room. Half, so the rest of the flat is still inhabited.
	if hero != null and is_instance_valid(hero) and _rng.randf() < 0.5:
		centre = hero.global_position + Vector3(
				_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.2, 0.5),
				_rng.randf_range(-0.7, 0.7))
	for attempt in 8:
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.2),
				_rng.randf_range(-1.0, 1.0)).normalized()
		var ray_length := 1.6 if birth_colony != null else 3.0
		var q := PhysicsRayQueryParameters3D.create(centre, centre + dir * ray_length)
		var hit: Dictionary = _space.intersect_ray(q)
		if hit.is_empty():
			continue
		var kinds: Array = [SpeciesScript.Kind.SEAM_GRAZER,
				SpeciesScript.Kind.CRYSTAL_LISTENER, SpeciesScript.Kind.FOLD_CRAB]
		var kind: int = kinds[_rng.randi() % kinds.size()]
		var m: Dictionary = GeneratorScript.generate(kind, _next_id * 6151 + 17)
		var nrm: Vector3 = (hit.normal as Vector3).normalized()
		var birth_at: Vector3 = (hit.position as Vector3) + nrm * float(m.tall) * 0.5
		var colony = birth_colony if birth_colony != null and birth_colony.ether_at(birth_at) >= 0.12 \
				else _supporting_colony(birth_at)
		var ecology_record: Dictionary = {}
		if ecology_director != null:
			if colony == null:
				continue
			ecology_record = colony.spawn(colony.OrganismClass.COMPLEX_ORGANELLE,
					birth_at)
			if ecology_record.is_empty():
				continue
		var any := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
		critters.append({
			"id": _next_id, "morph": m,
			"pos": birth_at,
			"up": nrm,
			"fwd": any.cross(nrm).normalized(),
			"age": 0.0, "life": _rng.randf_range(18.0, 40.0),
			"gait": float(m.gait_phase),
			"pause": 0.0,
			"alive": 1.0,
			# §24 — the seam grazer's law. Set when it is actually on
			# something thin enough to be on both sides of.
			"twin": false,
			"twin_pos": Vector3.ZERO,
			"twin_up": Vector3.UP,
			"twin_fwd": Vector3.FORWARD,
			# The listener's law: its resonator's own angle, which advances
			# while the shell holding it does not turn at all.
			"spin": 0.0,
			"photo": MicroLightScript.state(),
			"photo_side": 0.0,
			"mechanical": MicroMechanicsScript.state(),
			# The crab's law: which leg is currently shorter than the gap it
			# spans, and by how much.
			"fold_leg": -1,
			"fold": 0.0,
			"fold_clock": 0.0,
			# §21 — what the margin is currently doing to it.
			"following": -1,
			"nudged": 0.0,
			"feeding": false,
			# §21 — the rest of what the margin is to an animal that lives in
			# it: something to work over, something to get under, and something
			# whose attention it can attract.
			"grooming": false,
			"hiding": false,
			"announced": 0.0,
			# §21's last three, which all need an animal to be able to stand
			# on an APPENDAGE rather than on architecture.
			"riding": -1,
			"ride_t": 0.0,
			"ride_cool": 0.0,
			"bridged": false,
			"rode_growing": false,
			# §22 — what it is doing about the hero, if anything.
			"hero_near": 0.0,
			"toward_hero": false,
			# §22 — sensory structures put out toward the hero. This is the
			# critter's HALF OF A CONVERSATION: the hero's club touches it and
			# it answers by unfolding, which is the whole of the beat.
			"unfold": 0.0,
			"attend_override": Vector3.INF,
			"ecology_colony": colony,
			"ecology_record": ecology_record,
			"ecology_returning": false,
			"ecology_ether_min": 1.0,
			"signal_seen_born": -1.0,
			"signal_seen_src": -2147483648,
			"signal_presented_at": -1.0,
			# Distance covered by its OWN locomotion, excluding being shoved
			# or fleeing. §32's bias governs walking, so that is what has to
			# be measured against it.
			"walked": 0.0,
		})
		critter_born.emit(_next_id, String(m.species))
		_next_id += 1
		return


func _supporting_colony(at: Vector3):
	if ecology_director == null:
		return null
	var ids: Array = ecology_director.moss_colonies.keys()
	ids.sort()
	for colony_id in ids:
		var colony = ecology_director.moss_colonies[colony_id]
		if colony.complex_unlocked() and colony.ether_at(at) >= 0.12:
			return colony
	return null


func _apply_ecology_support(delta: float) -> void:
	if ecology_director == null:
		return
	for critter in critters:
		var colony = critter.get("ecology_colony")
		var record: Dictionary = critter.get("ecology_record", {})
		if colony == null or record.is_empty():
			continue
		var status: String = colony.update_excursion(record, critter.pos, delta)
		critter.ecology_ether_min = minf(float(critter.ecology_ether_min),
				float(record.ether))
		critter.ecology_returning = status == "returning"
		if status == "returning":
			critter.pause = maxf(float(critter.pause), 0.25)
		elif status == "senescent":
			critter.alive = maxf(0.0, float(critter.alive) - delta * 0.35)


## Move a critter and keep it on the architecture. Every displacement goes
## through here -- walking, being shoved, fleeing -- so none of them can leave
## an animal in mid-air.
func _step_along_surface(c: Dictionary, step: Vector3) -> void:
	if _space == null:
		return
	var up: Vector3 = c.up
	var probe: Vector3 = (c.pos as Vector3) + step + up * 0.06
	var q := PhysicsRayQueryParameters3D.create(probe, probe - up * 0.25)
	var hit: Dictionary = _space.intersect_ray(q)
	if hit.is_empty():
		return                      # nothing under the new spot: do not go
	var m: Dictionary = c.morph
	c.pos = (hit.position as Vector3) + (hit.normal as Vector3) * float(m.tall) * 0.5
	c.up = (hit.normal as Vector3).normalized()
	var f: Vector3 = c.fwd
	c.fwd = (f - (c.up as Vector3) * f.dot(c.up)).normalized()


## §21 — CRAWL ACROSS THEM, BRIDGE ON THEM, RIDE THEM AS THEY COME OUT.
##
## The last three of §21's list all need the same thing and none of them works
## without it: an animal must be able to stand on an APPENDAGE rather than on
## architecture. The surface-walk re-seats by casting a ray at whatever is
## under its destination, and appendages have no presence in physics --
## eighty colliders for organs that exist to be looked at is not a trade worth
## making on a frame that is already submission-bound.
##
## So a rider is carried ANALYTICALLY: it holds an appendage's id and how far
## along it it has got, and its position is read off that organ own line every
## frame. Which makes the other two nearly free -- a rider whose organ is
## still unfolding is riding an emerging one, and a rider that reaches the far
## end while that end is resting on something has crossed a bridge.
##
## Returns whether the animal is being carried, because if it is, nothing else
## may move it.
func _ride(c: Dictionary, delta: float) -> bool:
	c.ride_cool = maxf(0.0, float(c.get("ride_cool", 0.0)) - delta)
	if margin == null or not is_instance_valid(margin):
		c.riding = -1
		return false
	var m: Dictionary = c.morph
	if int(c.riding) < 0:
		# MOUNTING, at the base where the organ meets the wall -- the only
		# part of it an animal standing on that wall can reach. Bold and
		# curious individuals only: climbing onto something much larger and
		# alive is not a thing every animal does.
		if float(c.ride_cool) > 0.0:
			return false
		if float(m.confidence) < 0.5 or float(m.curiosity) < 0.45:
			return false
		for p in margin.palps:
			if (c.pos as Vector3).distance_to(p.anchor) > 0.11:
				continue
			if float(p.grow) < 0.2:
				continue
			c.riding = int(p.id)
			c.ride_t = 0.0
			c.rode_growing = false
			c.bridged = false
			break
		if int(c.riding) < 0:
			return false
	var host: Dictionary = {}
	for p in margin.palps:
		if int(p.id) == int(c.riding):
			host = p
			break
	if host.is_empty():
		# The organ went away from under the animal. It does not fall.
		c.riding = -1
		c.ride_cool = 3.0
		_reseat_any(c, [c.up, Vector3.UP])
		return false
	var base: Vector3 = host.anchor
	var tip: Vector3 = host.tip
	var span: Vector3 = tip - base
	var length: float = span.length()
	if length < 0.03:
		c.riding = -1
		c.ride_cool = 3.0
		return false
	var along: Vector3 = span / length
	# It walks the organ at its own pace, in organ-lengths per second.
	c.ride_t = float(c.ride_t) + delta * float(m.speed) / maxf(0.05, length)
	# Anatomy that has not finished coming out is anatomy being ridden out.
	if float(host.get("unfold", 1.0)) < 0.999 or float(host.get("grow", 1.0)) < 0.999:
		c.rode_growing = true
	if float(c.ride_t) >= 1.0:
		# THE FAR END. If the organ is resting on something the animal steps
		# off onto it, which is the whole of what §21 means by a bridge. If it
		# is waving in the air there is nowhere to go, so it gets off the way
		# it came.
		if float(host.get("contact", 0.0)) > 0.6:
			c.bridged = true
			c.pos = tip
		c.riding = -1
		c.ride_cool = 4.0 if bool(c.bridged) else 2.0
		_reseat_any(c, [host.normal, c.up, Vector3.UP])
		return false
	# ON TOP OF THE ORGAN, not inside it. "Up" for a rider is the direction
	# out of the organ own axis, which is what standing on a limb means.
	var radial: Vector3 = (host.normal as Vector3) - along * (host.normal as Vector3).dot(along)
	if radial.length() < 0.01:
		var sd: Vector3 = host.side
		radial = sd - along * sd.dot(along)
	radial = radial.normalized() if radial.length() > 0.01 else Vector3.UP
	c.pos = base + span * float(c.ride_t) + radial * float(m.tall) * 0.5
	c.up = radial
	c.fwd = along
	c.moving = true
	return true


## Put an animal back on a real surface, trying several ideas of which way is
## down. A rider stepping off an organ has no reason to believe the floor is
## where it was when it climbed on.
func _reseat_any(c: Dictionary, ups: Array) -> void:
	if _space == null:
		return
	for u in ups:
		var up: Vector3 = (u as Vector3)
		if up.length() < 0.01:
			continue
		up = up.normalized()
		var from: Vector3 = (c.pos as Vector3) + up * 0.10
		var q := PhysicsRayQueryParameters3D.create(from, from - up * 0.45)
		var hit: Dictionary = _space.intersect_ray(q)
		if hit.is_empty():
			continue
		c.up = (hit.normal as Vector3).normalized()
		c.pos = (hit.position as Vector3) + (c.up as Vector3) * float(c.morph.tall) * 0.5
		var f: Vector3 = c.fwd
		f = f - (c.up as Vector3) * f.dot(c.up)
		c.fwd = f.normalized() if f.length() > 0.01 else (c.up as Vector3).cross(Vector3.RIGHT).normalized()
		return


## §19 and §20 — species decides the style, the individual decides the detail.
## A listener barely moves and freezes often; a crab walks steadily; a grazer
## follows the surface. Two of the same species differ in pause length, which
## way they prefer to turn, and where their gait starts.
func _walk(delta: float) -> void:
	var i := critters.size() - 1
	while i >= 0:
		var c: Dictionary = critters[i]
		c.age += delta
		if c.age >= c.life:
			critter_died.emit(int(c.id))
			critters.remove_at(i)
			i -= 1
			continue
		var m: Dictionary = c.morph
		c.gait += delta * float(m.speed) * 26.0
		# Pausing is a species trait and an individual one: the listener holds
		# still to use its resonators, and a timid crab stops more often.
		c.pause -= delta
		# A fold holds the animal still for its whole duration, so the pause
		# timer must not re-roll `moving` underneath it. It did, and a fold
		# that happened to span a re-roll moved the crab 73 mm.
		if float(c.get("fold", 0.0)) > 0.05:
			c.moving = false
			c.pause = maxf(float(c.pause), 0.35)
		elif c.pause <= 0.0:
			var still: float = 2.4 if int(m.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER else 0.7
			c.pause = _rng.randf_range(0.6, 2.2) + still * float(m.pause_bias)
			c.moving = _rng.randf() > (0.55 if int(m.kind)
					== SpeciesScript.Kind.CRYSTAL_LISTENER else 0.25)
		# §21 — is it being carried? If so its position comes from the organ
		# it is standing on and not from the floor.
		var riding: bool = _ride(c, delta)
		# §13 — everything turns toward one thing and stops.
		if not riding and c.get("attend_override", Vector3.INF) != Vector3.INF:
			var up0: Vector3 = c.up
			var to_it: Vector3 = (c.attend_override as Vector3) - (c.pos as Vector3)
			to_it = to_it - up0 * to_it.dot(up0)
			if to_it.length() > 0.01:
				c.fwd = (c.fwd as Vector3).lerp(to_it.normalized(),
						delta * 8.0).normalized()
			c.moving = false
		if not riding and bool(c.get("moving", true)):
			var turn: float = float(m.turn_bias) * delta * 0.6
			var up: Vector3 = c.up
			var fwd: Vector3 = (c.fwd as Vector3).rotated(up, turn).normalized()
			# §32 — a dormant area moves less; a foraging one moves more. The
			# individual's own speed is still what decides its pace.
			var move_bias: float = 1.0
			if director != null:
				move_bias = float(director.bias().get("move", 1.0))
			var step: Vector3 = fwd * float(m.speed) * move_bias * delta
			# Stay on the surface: cast down and re-seat, so they follow the
			# architecture rather than sliding off it.
			var probe: Vector3 = (c.pos as Vector3) + step + up * 0.06
			var q := PhysicsRayQueryParameters3D.create(probe, probe - up * 0.25)
			var hit: Dictionary = _space.intersect_ray(q) if _space != null else {}
			if hit.is_empty():
				c.fwd = (fwd as Vector3).rotated(up, PI * 0.55).normalized()
			else:
				# How far the ANIMAL moved, not how far its feet are from the
				# surface. Measuring pos-to-hit included the standing offset
				# on every single frame and accumulated 87 m in six seconds.
				var was: Vector3 = c.pos
				c.pos = (hit.position as Vector3) + (hit.normal as Vector3) * float(m.tall) * 0.5
				c.walked = float(c.get("walked", 0.0)) 						+ was.distance_to(c.pos)
				c.up = (hit.normal as Vector3).normalized()
				c.fwd = (fwd - (c.up as Vector3) * fwd.dot(c.up)).normalized()
		_apply_law(c, delta)
		if not riding:
			# An animal being carried along an organ is not using the margin
			# as terrain: it IS on the margin. Letting the habitat pass run as
			# well had appendages shoving a rider off the appendage it was
			# standing on.
			_use_the_margin(c, delta)
		_consider_the_hero(c, delta)
		i -= 1


## §22 — THE HERO, RARELY AND MEANINGFULLY.
##
##     "hero emerges, several critters flee into Dream margin, one remains,
##      hero examines the brave individual ... These interactions can create
##      character without dialogue."
##
## The whole beat depends on the individuals NOT all doing the same thing, so
## this is decided by temperament: a timid critter runs and a confident one
## holds its ground or comes closer. One brave animal among four that fled is
## a character, and it costs nothing to author because §19 already gave every
## individual a confidence.
func _consider_the_hero(c: Dictionary, delta: float) -> void:
	c.toward_hero = false
	if hero == null or not is_instance_valid(hero):
		c.hero_near = 0.0
		return
	var m: Dictionary = c.morph
	var pos: Vector3 = c.pos
	var hero_tip: Vector3 = hero.tip_world()
	var d: float = minf(pos.distance_to(hero_tip),
			pos.distance_to(hero.global_position))
	c.hero_near = clampf(1.0 - d / 2.0, 0.0, 1.0)
	if float(c.hero_near) <= 0.0:
		return
	var up: Vector3 = c.up
	# The hero withdrawing through its own cross-section is the single most
	# alarming thing in this ecology, and even a bold animal reacts to it.
	var alarming: float = 0.55
	if "slice_close" in hero and float(hero.slice_close) > 0.02:
		alarming = 0.9
	if float(m.confidence) < alarming:
		# Flee, along the surface, away from it.
		var away: Vector3 = pos - hero_tip
		away = away - up * away.dot(up)
		if away.length() > 0.001:
			c.fwd = (c.fwd as Vector3).lerp(away.normalized(),
					delta * 3.0 * float(c.hero_near)).normalized()
			c.moving = true
	elif float(m.curiosity) > 0.5:
		# Hold, and approach. This is the brave individual.
		var toward: Vector3 = hero_tip - pos
		toward = toward - up * toward.dot(up)
		if toward.length() > 0.08:
			c.fwd = (c.fwd as Vector3).lerp(toward.normalized(),
					delta * 1.2 * float(c.hero_near)).normalized()
			c.toward_hero = true


## TURNING, INCLUDING THE EXACTLY-BACKWARDS CASE.
##
## Lerping a heading toward its own negation is a FIXED POINT. At any blend
## below a half the result still points the original way once it is
## normalised -- `lerp(f, -f, 0.2)` is `f * 0.6` -- so an animal asked to turn
## right round never turns at all, and one asked to turn nearly right round
## takes an age about it. Found by a hiding critter that reported itself
## hiding for eight steps while facing exactly the wrong way.
##
## Rotating about the animal's own up has no such hole. Where the turn is
## exactly 180 degrees there is no unique axis, so it picks a side and
## commits, which is what an animal does too.
func _turn_toward(c: Dictionary, want: Vector3, amount: float) -> void:
	var fwd: Vector3 = c.fwd
	var up: Vector3 = c.up
	var w: Vector3 = want - up * want.dot(up)
	if w.length() < 0.0001:
		return
	w = w.normalized()
	var ang: float = acos(clampf(fwd.dot(w), -1.0, 1.0))
	if ang < 0.0001:
		return
	var axis: Vector3 = fwd.cross(w)
	axis = axis.normalized() if axis.length() > 0.0001 else up
	c.fwd = fwd.rotated(axis, minf(ang, amount)).normalized()


## §22 — THE HERO'S CLUB TOUCHES AN ANIMAL, AND THE ANIMAL ANSWERS.
##
##     "A tiny critter clings to a hero gold plate; the hero eye notices it;
##      the distal club nudges it; the critter unfolds sensory structures."
##
## THIS IS NOT THE PALP SHOVE WEARING A DIFFERENT NAME, and the difference is
## the entire point of the beat. A primary palp is several times a critter's
## size and does not notice it is there: that push is oblivious, and a jumpy
## individual freezes at it. This one is deliberate. The creature looked at
## this animal first and then reached for it, so what comes back is not alarm
## but attention -- the critter puts its sensory structures OUT, toward the
## thing that touched it. §22 asks for interactions that create character
## without dialogue, and a startle and a greeting are the same displacement
## with two different answers.
##
## Returns the critter it found, so the caller knows whether the beat happened.
func nudged_by_hero(at: Vector3, from: Vector3, delta: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 0.30
	for c in critters:
		var d: float = at.distance_to(c.pos)
		if d < best_d:
			best_d = d
			best = c
	if best.is_empty():
		return {}
	var away: Vector3 = (best.pos as Vector3) - from
	away = away - (best.up as Vector3) * away.dot(best.up)
	if away.length() > 0.001:
		# Gentler than the palp's shove, and re-seated the same way -- an
		# animal the hero can knock off the wall is not being minded.
		_step_along_surface(best, away.normalized() * delta * 0.07)
	best.unfold = 1.0
	best.nudged = 0.5
	# It stops to attend. A brave one holds its ground, which is §22's other
	# example: the hero examines the individual that did not flee.
	if float(best.morph.confidence) < 0.45:
		best.moving = false
	return best


## §21 — THE MARGIN IS HABITAT.
##
##     "Critters should use the Dream margin as habitat ... This turns the
##      wall into a functioning biome."
##
## Three things, chosen because each is legible from across a room: a critter
## gets shoved aside by an appendage far bigger than it is; a curious one
## follows a palp to whatever the palp has found; and one that meets fresh
## residue stops to feed on it. The rest of §21's list needs systems that do
## not exist.
func _use_the_margin(c: Dictionary, delta: float) -> void:
	c.nudged = maxf(0.0, float(c.nudged) - delta)
	# Sensory structures fold back slowly. Faster than they came out would
	# read as a flinch, and a flinch is what this deliberately is not.
	c.unfold = maxf(0.0, float(c.unfold) - delta * 0.28)
	c.feeding = false
	c.grooming = false
	c.hiding = false
	c.announced = maxf(0.0, float(c.announced) - delta)
	var m: Dictionary = c.morph
	var pos: Vector3 = c.pos
	if margin != null:
		var closest := 9.0
		var closest_p: Dictionary = {}
		for p in margin.palps:
			var d: float = pos.distance_to(p.tip)
			if d < closest:
				closest = d
				closest_p = p
		if not closest_p.is_empty():
			# PUSHED ASIDE. A primary palp is several times a critter's size,
			# and it does not notice.
			var personal: float = 0.09 + 0.05 * float(closest_p.morph.length)
			if closest < personal:
				var away: Vector3 = pos - (closest_p.tip as Vector3)
				away = away - (c.up as Vector3) * away.dot(c.up)
				if away.length() > 0.001:
					# Being shoved must keep it ON something. Moving it
					# without re-seating pushed critters off edges into the
					# air -- the contract caught one airborne about one run in
					# three, and an animal that a palp can knock into space is
					# not living on the wall.
					_step_along_surface(c, away.normalized() * delta * 0.12)
					c.nudged = 0.4
					# Being shoved is startling, in proportion to temperament.
					if float(m.startle) > 0.6:
						c.moving = false
			# §21 — HIDE BENEATH THEM. When the margin takes fright the alarm
			# runs through it as a wave, and the smallest animals on the wall
			# do what small animals do: get under the nearest big thing and
			# stop moving. Under is the ANCHOR, where the appendage is thickest
			# and rooted, not the tip that is waving about.
			#
			# Only the nervous ones. A bold individual carrying on as normal
			# while its neighbours bolt is what makes them read as individuals
			# rather than as a shoal.
			elif float(closest_p.get("startle", 0.0)) > 0.45 					and float(m.startle) > 0.45 and closest < 0.7:
				var to_under: Vector3 = (closest_p.anchor as Vector3) - pos
				to_under = to_under - (c.up as Vector3) * to_under.dot(c.up)
				if to_under.length() > 0.05:
					_step_along_surface(c, to_under.normalized() * delta
							* float(m.speed) * 1.6)
					_turn_toward(c, to_under.normalized(), delta * 4.0)
				else:
					c.moving = false
				c.hiding = true
			# §21 — GROOM THEM. An appendage that is ON something is holding
			# still, and a sociable animal that finds one holding still works
			# over it: parked against it, sensory structures out and busy.
			# This is the behaviour that makes the margin read as a body other
			# things live on rather than as scenery.
			elif closest < 0.22 and float(closest_p.get("contact", 0.0)) > 0.6 					and float(m.sociability) > 0.45:
				c.moving = false
				c.grooming = true
				c.unfold = maxf(float(c.unfold), 0.75)
			# FOLLOW IT TO WHAT IT FOUND. A curious individual treats a palp's
			# discovery as worth investigating.
			elif closest < 0.55 and closest_p.target != Vector3.INF:
				if float(m.curiosity) > 0.5 and int(c.following) < 0:
					c.following = int(closest_p.id)
				if int(c.following) == int(closest_p.id):
					var to: Vector3 = (closest_p.target as Vector3) - pos
					to = to - (c.up as Vector3) * to.dot(c.up)
					if to.length() > 0.04:
						_turn_toward(c, to.normalized(), delta * 1.5)
					else:
						c.following = -1
	# FEED ON WHAT THE DREAM LEFT. Residue is transformed matter, and a
	# scavenger stops for it.
	if residue != null and residue.has_method("nearest_patch"):
		var patch: Dictionary = residue.nearest_patch(pos, 0.5)
		if not patch.is_empty():
			c.feeding = true
			c.moving = false
			# §21 — TRIGGER COORDINATED LOCAL ATTENTION. An animal settling to
			# feed on transformed matter is the most interesting thing to
			# happen on that stretch of wall, and the appendages around it turn
			# to watch. Announced ONCE and then not again for a while: a
			# critter that spends six seconds eating must not hold the whole
			# neighbourhood's attention for all six.
			if float(c.announced) <= 0.0 and margin != null 					and margin.has_method("orient_nearby"):
				c.announced = 9.0
				margin.orient_nearby(pos, 0.7)
	_answer_recognition_signal(c, delta)


## Sociable fauna present their receptors to a local recognition pulse. The
## pulse carries no behavioural command: this class chooses to turn and
## unfold, while less-social individuals genuinely do nothing.
func _answer_recognition_signal(c: Dictionary, delta: float) -> void:
	if director == null or float(c.morph.sociability) <= 0.45:
		return
	if director.signals_near(c.pos, 0.0, _signal_near) <= 0:
		return
	for packet in _signal_near:
		if int(packet.function) != DreamEcologyDirector.Fn.RECOGNIZE \
				or int(packet.family) != DreamEcologyDirector.Chem.ELECTRIC \
				or float(packet.sign) <= 0.0:
			continue
		var affinity: int = int(packet.affinity)
		if affinity >= 0 and affinity != DreamEcologyDirector.SrcClass.FAUNA:
			continue
		if int(packet.src_id) == int(c.signal_seen_src) \
				and float(packet.born) <= float(c.signal_seen_born):
			continue
		var toward: Vector3 = (packet.at as Vector3) - (c.pos as Vector3)
		toward -= (c.up as Vector3) * toward.dot(c.up)
		if toward.length() > 0.001:
			_turn_toward(c, toward.normalized(), delta * 5.0)
		c.unfold = maxf(float(c.unfold), 0.9)
		c.signal_seen_born = float(packet.born)
		c.signal_seen_src = int(packet.src_id)
		c.signal_presented_at = director.signal_time()
		break





## §24 — THE SPECIES' ONE IMPOSSIBLE RULE, ENACTED.
##
## Declaring a law in a dictionary is not the same as an animal having it, and
## a species whose impossible rule exists only in its data is not yet a Dream
## animal. Each of these is the creature doing the thing.
func _apply_law(c: Dictionary, delta: float) -> void:
	var m: Dictionary = c.morph
	_update_photoreception(c, delta)
	_update_mechanoreception(c, delta)
	match int(m.kind):
		SpeciesScript.Kind.SEAM_GRAZER:
			# BOTH SIDES OF A THIN WALL AT ONCE. Not a copy: the same animal,
			# met twice, because a body with more extent than our space has
			# can intersect one slice in two places.
			c.twin = false
			if _space == null:
				return
			var up: Vector3 = c.up
			var behind: Vector3 = (c.pos as Vector3) - up * 0.32
			var q := PhysicsRayQueryParameters3D.create(behind, c.pos)
			var hit: Dictionary = _space.intersect_ray(q)
			if hit.is_empty():
				return
			var far: Vector3 = hit.position
			var thickness: float = (c.pos as Vector3).distance_to(far)
			if thickness > 0.30 or thickness < 0.005:
				return
			var far_n: Vector3 = (hit.normal as Vector3).normalized()
			c.twin = true
			c.twin_pos = far + far_n * float(m.tall) * 0.5
			c.twin_up = far_n
			# It faces the same way on both sides, because it is facing one
			# way: the two appearances are not two animals with two opinions.
			var f: Vector3 = c.fwd
			c.twin_fwd = (f - far_n * f.dot(far_n)).normalized()
		SpeciesScript.Kind.CRYSTAL_LISTENER:
			# ITS CRYSTAL TURNS INSIDE A SHELL THAT DOES NOT. The body's
			# orientation is untouched; only the resonator's own angle moves.
			# Light makes that resonator scan, then an abrupt positive step
			# reverses it for one photoshock while the shell arrests.
			var receptor: Dictionary = c.photo
			var base_rate := 0.9 + 1.4 * float(m.crystal)
			var shock := float(receptor.shock)
			var response := float(receptor.response)
			var direction := -1.0 if shock > 0.02 else 1.0
			var mechanical: Dictionary = c.mechanical
			var mech := float(mechanical.response)
			var mech_carrier := int(mechanical.carrier)
			if mech_carrier == DreamEcologyDirector.Carrier.IMPULSE and mech > 0.02:
				direction = -1.0
			elif mech_carrier == DreamEcologyDirector.Carrier.HUM and mech > 0.02:
				base_rate *= 0.22
			c.spin += delta * base_rate * direction \
					* (1.0 + response * 1.35 + mech * 0.45)
			if shock > 0.02:
				c.moving = false
				c.pause = maxf(float(c.pause), 0.28)
				c.unfold = maxf(float(c.unfold), shock * 0.72)
		SpeciesScript.Kind.FOLD_CRAB:
			# A LEG SHORTENS WITHOUT MOVING EITHER OF ITS ENDS. Its root stays
			# on the body and its foot stays planted, and the limb between
			# them becomes shorter than the gap it spans.
			# NOT WHILE IT IS RUNNING. An animal does not perform its one
			# strange trick mid-flight, and letting it try produced a crab
			# that folded a leg while fleeing the hero -- which moved it 75 mm
			# during the event and made the law illegible.
			if float(c.get("hero_near", 0.0)) > 0.25 and float(m.confidence) < 0.55:
				c.fold = 0.0
				c.fold_clock = maxf(float(c.fold_clock), 1.5)
				return
			c.fold_clock -= delta
			if c.fold_clock <= 0.0:
				c.fold_clock = _rng.randf_range(2.2, 5.5)
				c.fold_leg = _rng.randi_range(0, maxi(1, int(m.limbs)) - 1)
			var t: float = c.fold_clock
			# A short event, not a permanent state: §15 asks for restraint.
			c.fold = clampf(sin(maxf(0.0, 1.1 - t) * PI * 0.9), 0.0, 1.0) 					if t < 1.1 else 0.0
			# It stands still while it does this. A leg that is shorter than
			# the gap it spans is only legible if nothing else is moving --
			# and a walking animal's feet move anyway, which would hide the
			# whole point.
			if float(c.fold) > 0.05:
				c.moving = false


func _push() -> void:
	# Slots, not animals. A grazer on both sides of a wall takes two, and both
	# carry the same identity, gait and morphology -- they are one creature.
	# §29/§30 — nearest first, same as the margin. A twin costs a second slot,
	# so a distant animal on both sides of a wall can lose its geometry to a
	# closer one -- which is correct: the player cannot see it anyway.
	var eye := _eye_position()
	var order: Array = []
	for i in critters.size():
		order.append({"i": i, "d": eye.distance_squared_to(critters[i].pos)})
	order.sort_custom(func(a, b): return float(a.d) < float(b.d))
	var slot := 0
	for entry in order:
		if slot >= MAX_CRITTERS:
			break
		var c: Dictionary = critters[int(entry.i)]
		_write_slot(slot, c, false)
		slot += 1
		if bool(c.get("twin", false)) and slot < MAX_CRITTERS:
			_write_slot(slot, c, true)
			slot += 1
	var n := slot
	for i in range(n, MAX_CRITTERS):
		_counts[i] = Vector4.ZERO
		_photo[i] = Vector4.ZERO
		_mechanical[i] = Vector4.ZERO
	material.set_shader_parameter("critter_pos", _pos)
	material.set_shader_parameter("critter_fwd", _fwd)
	material.set_shader_parameter("critter_up", _up)
	material.set_shader_parameter("critter_size", _size)
	material.set_shader_parameter("critter_matter", _matter)
	material.set_shader_parameter("critter_counts", _counts)
	material.set_shader_parameter("critter_law", _law)
	material.set_shader_parameter("critter_look", _look)
	material.set_shader_parameter("critter_photo", _photo)
	material.set_shader_parameter("critter_mechanical", _mechanical)
	material.set_shader_parameter("critter_count", n)
	if field != null:
		field.apply_to(material)
	mesh_instance.visible = n > 0


func _write_slot(i: int, c: Dictionary, as_twin: bool) -> void:
	if true:
		var m: Dictionary = c.morph
		var plan := 0.0
		if int(m.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER:
			plan = 1.0
		elif int(m.kind) == SpeciesScript.Kind.FOLD_CRAB:
			plan = 2.0
		var p: Vector3 = c.twin_pos if as_twin else c.pos
		_pos[i] = Vector4(p.x, p.y, p.z, plan)
		var f: Vector3 = c.twin_fwd if as_twin else c.fwd
		_fwd[i] = Vector4(f.x, f.y, f.z, 0.0)
		var u: Vector3 = c.twin_up if as_twin else c.up
		_up[i] = Vector4(u.x, u.y, u.z, 0.0)
		# x resonator angle, y which leg is folded, z how far, w unused
		_look[i] = Vector4(float(m.get("hue_bias", 0.5)),
				float(m.get("perfusion", 0.6)), float(m.get("wetness", 0.6)),
				float(m.get("iridescence", 0.3)))
		_law[i] = Vector4(float(c.get("spin", 0.0)),
				float(int(c.get("fold_leg", -1))), float(c.get("fold", 0.0)),
				float(c.get("unfold", 0.0)))
		var photo: Dictionary = c.get("photo", {})
		_photo[i] = Vector4(float(photo.get("response", 0.0)),
				float(photo.get("shock", 0.0)),
				float(photo.get("scan", 0.0)) / TAU,
				float(c.get("photo_side", 0.0)))
		var mechanical: Dictionary = c.get("mechanical", {})
		var mech_dir: Vector3 = mechanical.get("direction", Vector3.ZERO)
		_mechanical[i] = Vector4(float(mechanical.get("response", 0.0)),
				float(mechanical.get("carrier", 0)) / 3.0,
				float(mechanical.get("age", 99.0)),
				clampf(mech_dir.dot(f), -1.0, 1.0))
		_size[i] = Vector4(float(m.length), float(m.wide), float(m.tall),
				float(int(m.seed) % 97) * 0.041)
		_matter[i] = Vector4(float(m.gold), float(m.crystal), float(m.cilia),
				float(c.gait) + float(m.get("stride_phase", 0.0)))
		# w carries the walking bob so a moving animal rises and falls on its
		# legs; z is the anatomical asymmetry §17 asks for.
		var bobbing: float = float(m.get("body_bob", 0.0)) 				* (1.0 if bool(c.get("moving", false)) else 0.0)
		_counts[i] = Vector4(float(m.limbs), float(m.feelers),
				float(m.asymmetry), 1.0 + bobbing * sin(float(c.gait) * 2.0) * 0.06)


## Only the crystal listener is the MBIO-1 fauna receptor. Other families
## still carry a zeroed transient state so adding one later cannot inherit a
## stale buffer slot.
func _update_photoreception(c: Dictionary, delta: float) -> void:
	var receptor: Dictionary = c.photo
	var listener := int(c.morph.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER
	var sample := MicroLightScript.sample(_lamp_pose, c.pos) if listener \
			else {"level": 0.0, "toward": Vector3.ZERO}
	MicroLightScript.advance(receptor, float(sample.level), delta)
	var toward: Vector3 = sample.get("toward", Vector3.ZERO)
	var side := (c.up as Vector3).cross(c.fwd as Vector3).normalized()
	c.photo_side = clampf(toward.dot(side), -1.0, 1.0) \
			if toward.length_squared() > 0.0 else 0.0


## A crystal listener accepts floor impulse and sustained hum. Seam grazers
## and fold crabs carry dormant receptor state but ignore the same packet.
func _update_mechanoreception(c: Dictionary, delta: float) -> void:
	var receptor: Dictionary = c.mechanical
	MicroMechanicsScript.advance(receptor, delta)
	if director == null or int(c.morph.kind) != SpeciesScript.Kind.CRYSTAL_LISTENER:
		return
	if director.signals_near(c.pos, 0.0, _signal_near) <= 0:
		return
	var up: Vector3 = c.up
	var substrate := DreamEcologyDirector.Substrate.FLOOR \
			if absf(up.dot(Vector3.UP)) >= 0.65 \
			else DreamEcologyDirector.Substrate.WALL
	var mask := MicroMechanicsScript.IMPULSE | MicroMechanicsScript.HUM
	for packet in _signal_near:
		if MicroMechanicsScript.accept(receptor, packet, mask, substrate):
			c.moving = false
			break


func census() -> Dictionary:
	var by_species := {}
	for c in critters:
		var s: String = String(c.morph.species)
		by_species[s] = int(by_species.get(s, 0)) + 1
	var twinned := 0
	var folding := 0
	for c in critters:
		if bool(c.get("twin", false)):
			twinned += 1
		if float(c.get("fold", 0.0)) > 0.05:
			folding += 1
	var grooming := 0
	var hiding := 0
	var riding := 0
	var bridged := 0
	var rode_growing := 0
	for c in critters:
		if bool(c.get("grooming", false)):
			grooming += 1
		if bool(c.get("hiding", false)):
			hiding += 1
		if int(c.get("riding", -1)) >= 0:
			riding += 1
		if bool(c.get("bridged", false)):
			bridged += 1
		if bool(c.get("rode_growing", false)):
			rode_growing += 1
	var unfolded := 0
	for c in critters:
		if float(c.get("unfold", 0.0)) > 0.05:
			unfolded += 1
	var nudged := 0
	var following := 0
	var feeding := 0
	var feel_hero := 0
	var brave := 0
	var photo_receptors := 0
	var photo_responding := 0
	var photoshocks := 0
	var mechanical_receptors := 0
	var mechanical_responding := 0
	var mechanical_received := 0
	for c in critters:
		if float(c.get("nudged", 0.0)) > 0.0:
			nudged += 1
		if int(c.get("following", -1)) >= 0:
			following += 1
		if bool(c.get("feeding", false)):
			feeding += 1
		if float(c.get("hero_near", 0.0)) > 0.01:
			feel_hero += 1
		if bool(c.get("toward_hero", false)):
			brave += 1
		if int(c.morph.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER:
			photo_receptors += 1
		var photo: Dictionary = c.get("photo", {})
		if float(photo.get("response", 0.0)) > 0.02:
			photo_responding += 1
		photoshocks += int(photo.get("shocks", 0))
		if int(c.morph.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER:
			mechanical_receptors += 1
		var mechanical: Dictionary = c.get("mechanical", {})
		if float(mechanical.get("response", 0.0)) > 0.02:
			mechanical_responding += 1
		mechanical_received += int(mechanical.get("received", 0))
	return {"live": critters.size(), "born": _next_id, "species": by_species,
			"max": MAX_LIVE, "on_both_sides": twinned, "folding_a_leg": folding,
			"nudged_by_a_palp": nudged, "unfolding_at_the_hero": unfolded,
			"grooming_a_palp": grooming, "hiding_under_a_palp": hiding,
			"riding_a_palp": riding, "used_one_as_a_bridge": bridged,
			"rode_one_out": rode_growing,
			"following_a_palp": following,
			"feeding_on_residue": feeding,
			"feel_hero": feel_hero, "approaching_hero": brave,
			"photo_receptors": photo_receptors,
			"photo_responding": photo_responding,
			"photoshocks": photoshocks,
			"mechanical_receptors": mechanical_receptors,
			"mechanical_responding": mechanical_responding,
			"mechanical_received": mechanical_received}


func _eye_position() -> Vector3:
	var vp := get_viewport()
	if vp != null:
		var camera := vp.get_camera_3d()
		if camera != null:
			return camera.global_position
	return global_position
