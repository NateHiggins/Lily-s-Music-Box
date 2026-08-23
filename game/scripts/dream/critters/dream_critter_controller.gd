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

const MAX_CRITTERS := 8
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


func setup(controller: DreamFieldController, seed_v: int) -> void:
	name = "DreamCritterController"
	enabled = OS.get_environment("DREAM_CRITTERS") != "0"
	field = controller
	_rng.seed = seed_v
	for arr in [_pos, _fwd, _up, _size, _matter, _counts]:
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
		if critters.size() < MAX_CRITTERS:
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
		i -= 1


func _push() -> void:
	var n := mini(critters.size(), MAX_CRITTERS)
	for i in MAX_CRITTERS:
		if i >= n:
			_counts[i] = Vector4.ZERO
			continue
		var c: Dictionary = critters[i]
		var m: Dictionary = c.morph
		var plan := 0.0
		if int(m.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER:
			plan = 1.0
		elif int(m.kind) == SpeciesScript.Kind.FOLD_CRAB:
			plan = 2.0
		var p: Vector3 = c.pos
		_pos[i] = Vector4(p.x, p.y, p.z, plan)
		var f: Vector3 = c.fwd
		_fwd[i] = Vector4(f.x, f.y, f.z, 0.0)
		var u: Vector3 = c.up
		_up[i] = Vector4(u.x, u.y, u.z, 0.0)
		_size[i] = Vector4(float(m.length), float(m.wide), float(m.tall),
				float(int(m.seed) % 97) * 0.041)
		_matter[i] = Vector4(float(m.gold), float(m.crystal), float(m.cilia),
				float(c.gait))
		_counts[i] = Vector4(float(m.limbs), float(m.feelers),
				float(m.asymmetry), 1.0)
	material.set_shader_parameter("critter_pos", _pos)
	material.set_shader_parameter("critter_fwd", _fwd)
	material.set_shader_parameter("critter_up", _up)
	material.set_shader_parameter("critter_size", _size)
	material.set_shader_parameter("critter_matter", _matter)
	material.set_shader_parameter("critter_counts", _counts)
	material.set_shader_parameter("critter_count", n)
	if field != null:
		field.apply_to(material)
	mesh_instance.visible = n > 0


func census() -> Dictionary:
	var by_species := {}
	for c in critters:
		var s: String = String(c.morph.species)
		by_species[s] = int(by_species.get(s, 0)) + 1
	return {"live": critters.size(), "born": _next_id, "species": by_species,
			"max": MAX_CRITTERS}
