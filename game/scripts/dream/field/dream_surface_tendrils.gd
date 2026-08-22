class_name DreamSurfaceTendrils
extends Node3D
## DF-13 — SURFACE TENDRILS (owner ruling 2026-08-22: the procedural
## tentacle is shelved and *"used as the grist for many small tentacles we
## can spawn across a surface"*).
##
## The hero limb is now the modelled creature. What the procedural one was
## always good at is being CHEAP AND ENTIRELY AUTHORLESS — a limb with no
## asset behind it — which is exactly what a swarm needs. So the same idea
## runs here at a tenth the size and a hundredth the ceremony: where the
## Dream Field's cross-section meets a surface, small tendrils push through,
## look at whatever is nearest, and withdraw.
##
## This is the answer to DF-4's "high intensity → actual new anatomy". A
## stain on a wall says something passed. A hundred small limbs coming out
## of the wall, each on its own errand, says **one body is meeting our space
## in a hundred places at once** — which is the thing the whole Dream Field
## ruling is about.
##
## Everything is in ONE mesh and ONE draw: the tendrils are rings of a
## shared tube, and their spines live in a uniform array. Nothing is
## instanced per tendril, nothing allocates while it runs.

const SHADER := preload("res://shaders/dream_tendrils.gdshader")
const MAX_TENDRILS := 24
const JOINTS := 6
const RINGS := 13
const SEGS := 11

## How long a tendril's whole life lasts, and how much of it is spent out.
const EMERGE_S := 0.9
const HOLD_S := 5.4
const WITHDRAW_S := 1.1

var field: DreamFieldController = null
var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var count := 0
var spawned := 0

## Per tendril: anchor, normal, a target it noses toward, phase, life.
var _anchor := PackedVector3Array()
var _normal := PackedVector3Array()
var _aim := PackedVector3Array()
var _life := PackedFloat32Array()
var _length := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _spine := PackedVector3Array()      # MAX_TENDRILS * JOINTS
var _grow := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D = null
var _clock := 0.0
var _spawn_clock := 0.0
## The last surface a tendril found. Photographed at room distance, tendrils
## scattered one-per-wall read as stray black thorns; the ruling asks for
## "many small tendrils across a surface", and MANY IN ONE PLACE is what
## says one body is meeting our space here. So each new tendril mostly joins
## the last one's patch instead of starting its own.
var _patch_at := Vector3.INF
var _patch_n := Vector3.UP
var _patch_left := 0


func setup(controller: DreamFieldController, seed_v: int) -> void:
	name = "DreamSurfaceTendrils"
	field = controller
	_rng.seed = seed_v
	_anchor.resize(MAX_TENDRILS)
	_normal.resize(MAX_TENDRILS)
	_aim.resize(MAX_TENDRILS)
	_life.resize(MAX_TENDRILS)
	_length.resize(MAX_TENDRILS)
	_seed.resize(MAX_TENDRILS)
	_grow.resize(MAX_TENDRILS)
	_spine.resize(MAX_TENDRILS * JOINTS)
	for i in MAX_TENDRILS:
		_life[i] = -1.0
	material = ShaderMaterial.new()
	material.shader = SHADER
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Tendrils"
	mesh_instance.mesh = _build_mesh()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.extra_cull_margin = 16.0
	add_child(mesh_instance)
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world != null:
		_space = world.direct_space_state


## One mesh holding every tendril: UV.x around, UV.y along, and the tendril's
## index baked into a second UV so the vertex stage can find its spine.
func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for t in MAX_TENDRILS:
		var base := verts.size()
		for r in RINGS:
			var v := pow(float(r) / float(RINGS - 1), 1.7)
			for s in SEGS:
				var u := float(s) / float(SEGS - 1)
				var a := u * TAU
				verts.append(Vector3(cos(a), sin(a), v))
				normals.append(Vector3(cos(a), sin(a), 0.0))
				uvs.append(Vector2(u, v))
				uv2.append(Vector2(float(t), 0.0))
		for r in RINGS - 1:
			for s in SEGS - 1:
				var a0 := base + r * SEGS + s
				indices.append(a0); indices.append(a0 + SEGS); indices.append(a0 + 1)
				indices.append(a0 + 1); indices.append(a0 + SEGS); indices.append(a0 + SEGS + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The tendrils are placed in world space by the shader, so the mesh must
	# never be culled by its authored bounds.
	mesh.custom_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	return mesh


func _physics_process(delta: float) -> void:
	if field == null or field.state == null:
		return
	_clock += delta
	_spawn_clock += delta
	# Spawn where the field's cross-section actually meets matter.
	if _spawn_clock > 0.10:
		_spawn_clock = 0.0
		_try_spawn()
	count = 0
	for i in MAX_TENDRILS:
		if _life[i] < 0.0:
			continue
		_life[i] += delta
		var total := EMERGE_S + HOLD_S + WITHDRAW_S
		if _life[i] >= total:
			_life[i] = -1.0
			continue
		# Emergence, hold, withdrawal — the same three beats as the hero,
		# without the ceremony.
		var g := 0.0
		if _life[i] < EMERGE_S:
			g = smoothstep(0.0, 1.0, _life[i] / EMERGE_S)
		elif _life[i] < EMERGE_S + HOLD_S:
			g = 1.0
		else:
			g = 1.0 - smoothstep(0.0, 1.0, (_life[i] - EMERGE_S - HOLD_S) / WITHDRAW_S)
		_grow[i] = g
		_lay_spine(i, g)
		count += 1
	_push()


## A tendril is born where a ray from inside a field lobe hits a surface —
## so it comes out of real matter, not out of the air.
func _try_spawn() -> void:
	if _space == null:
		return
	var slot := -1
	for i in MAX_TENDRILS:
		if _life[i] < 0.0:
			slot = i
			break
	if slot < 0:
		return
	var st := field.state
	var live: Array = []
	for i in st.lobes.size():
		if st.lobe_present(i):
			live.append(i)
	if live.is_empty():
		return
	# Join the open patch: cast back at the same surface from a point beside
	# it, so a dozen tendrils come out of one square metre of wall.
	if _patch_left > 0 and _patch_at != Vector3.INF:
		_patch_left -= 1
		var any_p := Vector3.UP if absf(_patch_n.y) < 0.9 else Vector3.RIGHT
		var sx := any_p.cross(_patch_n).normalized()
		var sy := _patch_n.cross(sx)
		var off := sx * _rng.randf_range(-0.45, 0.45) + sy * _rng.randf_range(-0.40, 0.40)
		var from := _patch_at + off + _patch_n * 0.35
		var q := PhysicsRayQueryParameters3D.create(from, from - _patch_n * 0.75)
		var h: Dictionary = _space.intersect_ray(q)
		if not h.is_empty():
			_seat(slot, h.position, (h.normal as Vector3).normalized())
			return
	var l: Dictionary = st.lobes[live[_rng.randi() % live.size()]]
	var r := st.slice_radius(float(l.radius), float(l.w_offset))
	var centre: Vector3 = l.centre
	# Mostly horizontal: the organism is on WALLS, and a tendril out of a
	# wall reads; one out of the ceiling four metres up does not.
	var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.25, 0.15),
			_rng.randf_range(-1.0, 1.0)).normalized()
	var query := PhysicsRayQueryParameters3D.create(centre, centre + dir * (r + 2.2))
	var hit: Dictionary = _space.intersect_ray(query)
	if hit.is_empty():
		return
	# A fresh patch, and the next several tendrils will join it.
	_patch_at = hit.position
	_patch_n = (hit.normal as Vector3).normalized()
	_patch_left = _rng.randi_range(7, 13)
	_seat(slot, hit.position, _patch_n)


func _seat(slot: int, at: Vector3, n: Vector3) -> void:
	_anchor[slot] = at
	_normal[slot] = n
	# What it noses toward: a little off the normal, so a field of them
	# never points the same way.
	var any := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var side := any.cross(n).normalized()
	_aim[slot] = (n * _rng.randf_range(0.25, 0.9) + side * _rng.randf_range(-1.2, 1.2)
			+ n.cross(side) * _rng.randf_range(-1.2, 1.2)).normalized()
	# Photographed from across the room, 5-16 cm was invisible. A limb has to
	# be a hand's length to read as a limb at all.
	_length[slot] = _rng.randf_range(0.16, 0.40)
	_seed[slot] = _rng.randf_range(0.0, 30.0)
	_life[slot] = 0.0
	spawned += 1
	if OS.get_environment("ENCROACH_DEBUG") == "1" and spawned <= 8:
		print("[TENDRIL] %d at %s n=%s len=%.3f" % [slot, at, n, _length[slot]])


## Six joints on a curve from the anchor along the aim, with a slow drift so
## no two tendrils move alike.
func _lay_spine(i: int, g: float) -> void:
	var a: Vector3 = _anchor[i]
	var n: Vector3 = _normal[i]
	var aim: Vector3 = _aim[i]
	var ln: float = _length[i] * g
	var sd: float = _seed[i]
	var any := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var side := any.cross(n).normalized()
	var up := n.cross(side)
	# A CURL, not a spike. Photographed at room distance the straight version
	# read as brass horns nailed to the wall; what makes a limb read as a limb
	# is that it leaves the surface along the normal, turns over, and reaches
	# back down. So: normal-dominant at the root, aim-dominant (squared) along
	# the shaft, and a steady lateral arc that differs per tendril.
	var curl := (side * cos(sd * 1.9) + up * sin(sd * 1.9)).normalized()
	for j in JOINTS:
		var t := float(j) / float(JOINTS - 1)
		var p := a + n * (ln * (0.75 * t - 0.30 * t * t)) + aim * (ln * t * t * 0.95)
		p += curl * (ln * sin(t * PI * 0.72) * 0.42)
		# The nose: it sways looking for something, faster near the tip.
		var sway := sin(_clock * 1.7 + sd + t * 2.2) * ln * 0.22 * t
		var sway2 := cos(_clock * 1.3 + sd * 1.7 + t * 1.8) * ln * 0.18 * t
		_spine[i * JOINTS + j] = p + side * sway + up * sway2
	_grow[i] = g


func _push() -> void:
	material.set_shader_parameter("tendril_spine", _spine)
	material.set_shader_parameter("tendril_grow", _grow)
	material.set_shader_parameter("tendril_seed", _seed)
	material.set_shader_parameter("tendril_count", MAX_TENDRILS)
	if field != null:
		field.apply_to(material)
		material.set_shader_parameter("df_pulse", field.state.pulse_phase)
		material.set_shader_parameter("attention", field.state.attention)
	mesh_instance.visible = count > 0


func census() -> Dictionary:
	return {"live": count, "spawned": spawned, "max": MAX_TENDRILS}
