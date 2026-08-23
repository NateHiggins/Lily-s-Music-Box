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
var enabled := true
var critters: Array = []

var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D = null
var _next_id := 0
var _clock := 0.0
var _spawn_clock := 0.0

var _pos := PackedVector4Array()
var _fwd := PackedVector4Array()
var _up := PackedVector4Array()
var _size := PackedVector4Array()
var _matter := PackedVector4Array()
var _counts := PackedVector4Array()
var _law := PackedVector4Array()


func setup(controller: DreamFieldController, seed_v: int) -> void:
	name = "DreamCritterController"
	enabled = OS.get_environment("DREAM_CRITTERS") != "0"
	field = controller
	_rng.seed = seed_v
	for arr in [_pos, _fwd, _up, _size, _matter, _counts, _law]:
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
	if _spawn_clock >= 0.9:
		_spawn_clock = 0.0
		if critters.size() < MAX_LIVE:
			_try_spawn()
	_walk(delta)
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
	for attempt in 8:
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.2),
				_rng.randf_range(-1.0, 1.0)).normalized()
		var q := PhysicsRayQueryParameters3D.create(centre, centre + dir * 3.0)
		var hit: Dictionary = _space.intersect_ray(q)
		if hit.is_empty():
			continue
		var kinds: Array = [SpeciesScript.Kind.SEAM_GRAZER,
				SpeciesScript.Kind.CRYSTAL_LISTENER, SpeciesScript.Kind.FOLD_CRAB]
		var kind: int = kinds[_rng.randi() % kinds.size()]
		var m: Dictionary = GeneratorScript.generate(kind, _next_id * 6151 + 17)
		var nrm: Vector3 = (hit.normal as Vector3).normalized()
		var any := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
		critters.append({
			"id": _next_id, "morph": m,
			"pos": (hit.position as Vector3) + nrm * float(m.tall) * 0.5,
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
			# The crab's law: which leg is currently shorter than the gap it
			# spans, and by how much.
			"fold_leg": -1,
			"fold": 0.0,
			"fold_clock": 0.0,
			# §21 — what the margin is currently doing to it.
			"following": -1,
			"nudged": 0.0,
			"feeding": false,
		})
		critter_born.emit(_next_id, String(m.species))
		_next_id += 1
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
		if c.pause <= 0.0:
			var still: float = 2.4 if int(m.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER else 0.7
			c.pause = _rng.randf_range(0.6, 2.2) + still * float(m.pause_bias)
			c.moving = _rng.randf() > (0.55 if int(m.kind)
					== SpeciesScript.Kind.CRYSTAL_LISTENER else 0.25)
		if bool(c.get("moving", true)):
			var turn: float = float(m.turn_bias) * delta * 0.6
			var up: Vector3 = c.up
			var fwd: Vector3 = (c.fwd as Vector3).rotated(up, turn).normalized()
			var step: Vector3 = fwd * float(m.speed) * delta
			# Stay on the surface: cast down and re-seat, so they follow the
			# architecture rather than sliding off it.
			var probe: Vector3 = (c.pos as Vector3) + step + up * 0.06
			var q := PhysicsRayQueryParameters3D.create(probe, probe - up * 0.25)
			var hit: Dictionary = _space.intersect_ray(q) if _space != null else {}
			if hit.is_empty():
				c.fwd = (fwd as Vector3).rotated(up, PI * 0.55).normalized()
			else:
				c.pos = (hit.position as Vector3) + (hit.normal as Vector3) * float(m.tall) * 0.5
				c.up = (hit.normal as Vector3).normalized()
				c.fwd = (fwd - (c.up as Vector3) * fwd.dot(c.up)).normalized()
		_apply_law(c, delta)
		_use_the_margin(c, delta)
		i -= 1


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
	c.feeding = false
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
					c.pos = pos + away.normalized() * delta * 0.12
					c.nudged = 0.4
					# Being shoved is startling, in proportion to temperament.
					if float(m.startle) > 0.6:
						c.moving = false
			# FOLLOW IT TO WHAT IT FOUND. A curious individual treats a palp's
			# discovery as worth investigating.
			elif closest < 0.55 and closest_p.target != Vector3.INF:
				if float(m.curiosity) > 0.5 and int(c.following) < 0:
					c.following = int(closest_p.id)
				if int(c.following) == int(closest_p.id):
					var to: Vector3 = (closest_p.target as Vector3) - pos
					to = to - (c.up as Vector3) * to.dot(c.up)
					if to.length() > 0.04:
						c.fwd = (c.fwd as Vector3).lerp(to.normalized(),
								delta * 1.5).normalized()
					else:
						c.following = -1
	# FEED ON WHAT THE DREAM LEFT. Residue is transformed matter, and a
	# scavenger stops for it.
	if residue != null and residue.has_method("nearest_patch"):
		var patch: Dictionary = residue.nearest_patch(pos, 0.5)
		if not patch.is_empty():
			c.feeding = true
			c.moving = false





## §24 — THE SPECIES' ONE IMPOSSIBLE RULE, ENACTED.
##
## Declaring a law in a dictionary is not the same as an animal having it, and
## a species whose impossible rule exists only in its data is not yet a Dream
## animal. Each of these is the creature doing the thing.
func _apply_law(c: Dictionary, delta: float) -> void:
	var m: Dictionary = c.morph
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
			c.spin += delta * (0.9 + 1.4 * float(m.crystal))
		SpeciesScript.Kind.FOLD_CRAB:
			# A LEG SHORTENS WITHOUT MOVING EITHER OF ITS ENDS. Its root stays
			# on the body and its foot stays planted, and the limb between
			# them becomes shorter than the gap it spans.
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
	var slot := 0
	for i in critters.size():
		if slot >= MAX_CRITTERS:
			break
		_write_slot(slot, critters[i], false)
		slot += 1
		if bool(critters[i].get("twin", false)) and slot < MAX_CRITTERS:
			_write_slot(slot, critters[i], true)
			slot += 1
	var n := slot
	for i in range(n, MAX_CRITTERS):
		_counts[i] = Vector4.ZERO
	material.set_shader_parameter("critter_pos", _pos)
	material.set_shader_parameter("critter_fwd", _fwd)
	material.set_shader_parameter("critter_up", _up)
	material.set_shader_parameter("critter_size", _size)
	material.set_shader_parameter("critter_matter", _matter)
	material.set_shader_parameter("critter_counts", _counts)
	material.set_shader_parameter("critter_law", _law)
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
		_law[i] = Vector4(float(c.get("spin", 0.0)),
				float(int(c.get("fold_leg", -1))), float(c.get("fold", 0.0)), 0.0)
		_size[i] = Vector4(float(m.length), float(m.wide), float(m.tall),
				float(int(m.seed) % 97) * 0.041)
		_matter[i] = Vector4(float(m.gold), float(m.crystal), float(m.cilia),
				float(c.gait))
		_counts[i] = Vector4(float(m.limbs), float(m.feelers),
				float(m.asymmetry), 1.0)


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
	var nudged := 0
	var following := 0
	var feeding := 0
	for c in critters:
		if float(c.get("nudged", 0.0)) > 0.0:
			nudged += 1
		if int(c.get("following", -1)) >= 0:
			following += 1
		if bool(c.get("feeding", false)):
			feeding += 1
	return {"live": critters.size(), "born": _next_id, "species": by_species,
			"max": MAX_LIVE, "on_both_sides": twinned, "folding_a_leg": folding,
			"nudged_by_a_palp": nudged, "following_a_palp": following,
			"feeding_on_residue": feeding}
