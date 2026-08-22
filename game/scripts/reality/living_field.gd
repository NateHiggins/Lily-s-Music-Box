class_name LivingField
extends RefCounted
## THE ENCROACHMENT AS A SLIME MOULD (design/LIVING_FIELD_BRIEF.md §2, §5).
##
## One field per STOREY — trail, body, stain, and which source's organism
## it is — driven by Physarum-style agents (Jones 2010) in 3-D: particles
## sense a diffusing, decaying chemoattractant trail ahead of them, turn
## toward the strongest, step and deposit. The BODY is the live plasmodium
## (it persists for minutes, and recedes on starvation); the STAIN is the
## extracellular slime the organism leaves and avoids (Reid et al. 2012), a
## slow integrator of the body; each SOURCE (a case's beachhead) bears agents
## in its own tint. Shuttle streaming is a global cosine on speed and
## deposit. And a GRAVITY that is not the building's — a vector field of its
## own logic (§5d) — pulls every heading, pools the body where it points,
## and sets the organism's appetite. Uploaded as an ImageTexture3D the
## layered surface samples in world space.
##
## Presentation only: no collision, no gameplay owner, no save key.

const VOXEL_M := 0.5
const MAX_XZ := 64
const MAX_Y := 8
const STEP_HZ := 8.0
const PULSE_S := 14.0
## One slice a tick: a full pass every ny ticks (~0.12 s at 60 Hz), which is
## fast beside an organism that crosses a room in a minute, and cheap enough
## to run every frame for the player's storey.
const SLICES_PER_TICK := 1

const TRAIL_DECAY := 0.92
## The body persists for minutes once laid (0.97 per pass): a plasmodium
## keeps the ground it has taken until it withdraws.
const BODY_DECAY := 0.97
const STAIN_GAIN := 0.12
const STAIN_DECAY := 0.996
const SENSOR_VOXELS := 2
const DEPOSIT := 0.55
const FOOD := 0.3
const STARVE_TRAIL := 0.02
const AGENT_MIN := 120
const AGENT_SPAN := 780
const GRAVITY_PULL := 0.42
const POOL_GAIN := 2.0

var origin := Vector3.ZERO
var size_m := Vector3.ZERO
var nx := 1
var ny := 1
var nz := 1
## [{"position": Vector3, "intensity": float, "tint_index": int}] — the
## storey's cases; tint_index is what the surface palette is keyed by.
var sources: Array = []
var seed := 1
var clock := 0.0
var steps := 0

var trail := PackedFloat32Array()
var body := PackedFloat32Array()
var stain := PackedFloat32Array()
var who := PackedByteArray()
var _scratch := PackedFloat32Array()
var _agents_pos := PackedVector3Array()
var _agents_dir := PackedVector3Array()
var _agents_starve := PackedInt32Array()
var _agents_src := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _texture: ImageTexture3D
var _accum := 0.0
var _slice_cursor := 0
var _images: Array[Image] = []
var _upload_due := false
## Up to three nodes where the body is strongest after each pass, for the
## lights the encroachment keeps on the organism.
var nodes: PackedVector3Array = PackedVector3Array()
var node_strength: PackedFloat32Array = PackedFloat32Array()
var node_source: PackedInt32Array = PackedInt32Array()
## The gravity varies over metres, not centimetres: it is sampled on a 2 m
## lattice once per pass and the agents read the nearest cell. Per agent per
## step it cost 18 ms a tick in GDScript; cached it is under a millisecond.
const GRAVITY_CELL_M := 2.0
var _gx := 1
var _gy := 1
var _gz := 1
var _gravity_cache := PackedVector4Array()
var _gravity_cursor := 0
const GRAVITY_CELLS_PER_TICK := 24


## `rect` is the storey in Godot xz (x0, z0, x1, z1), `floor_y` its floor.
func configure(rect: Vector4, floor_y: float, rng_seed: int) -> void:
	origin = Vector3(rect.x, floor_y - 0.1, rect.y)
	size_m = Vector3(rect.z - rect.x, 3.4, rect.w - rect.y)
	nx = clampi(int(ceil(size_m.x / VOXEL_M)), 4, MAX_XZ)
	nz = clampi(int(ceil(size_m.z / VOXEL_M)), 4, MAX_XZ)
	ny = clampi(int(ceil(size_m.y / VOXEL_M)), 4, MAX_Y)
	var n := nx * ny * nz
	trail.resize(n); trail.fill(0.0)
	body.resize(n); body.fill(0.0)
	stain.resize(n); stain.fill(0.0)
	who.resize(n); who.fill(0)
	_scratch.resize(n)
	seed = rng_seed
	_rng.seed = rng_seed
	_agents_pos.clear(); _agents_dir.clear(); _agents_starve.clear(); _agents_src.clear()
	sources.clear()
	_gx = maxi(1, int(ceil(size_m.x / GRAVITY_CELL_M)))
	_gy = maxi(1, int(ceil(size_m.y / GRAVITY_CELL_M)))
	_gz = maxi(1, int(ceil(size_m.z / GRAVITY_CELL_M)))
	_gravity_cache.resize(_gx * _gy * _gz)
	_refresh_gravity()


func add_source(position: Vector3, tint_index: int) -> int:
	sources.append({"position": position, "intensity": 0.0, "tint_index": tint_index})
	return sources.size() - 1


func set_source_intensity(index: int, value: float) -> void:
	if index >= 0 and index < sources.size():
		sources[index].intensity = clampf(value, 0.0, 1.0)


func texture() -> ImageTexture3D:
	if _texture == null:
		_ensure_images()
		_texture = ImageTexture3D.new()
		_texture.create(Image.FORMAT_RGBA8, nx, nz, ny, false, _images)
	return _texture


func _ensure_images() -> void:
	if _images.size() == ny:
		return
	_images.clear()
	for y in ny:
		_images.append(Image.create(nx, nz, false, Image.FORMAT_RGBA8))


## Advance by `delta` seconds: the agents step at STEP_HZ, the relaxation
## runs SLICES_PER_TICK slices every call, and the texture uploads once a
## full pass has completed. Returns true when the texture was uploaded.
func tick(delta: float) -> bool:
	clock += delta
	_accum += delta
	while _accum >= 1.0 / STEP_HZ:
		_accum -= 1.0 / STEP_HZ
		_step()
	_relax_slices()
	_refresh_gravity_some()
	if _upload_due and _texture != null:
		_texture.update(_images)
		_upload_due = false
		return true
	return false


## The shuttle-streaming phase, 0..1 over PULSE_S; the surface breathes with it.
func pulse_phase() -> float:
	return fmod(clock, PULSE_S) / PULSE_S


## The field is alive if any source is, or while agents remain.
func alive() -> bool:
	for s in sources:
		if float(s.intensity) > 0.001:
			return true
	return _agents_pos.size() > 0


# ── THE GRAVITY OF ITS OWN (§5d) ──────────────────────────────────────────
# The same rule the surface uses (os_gravity in orison_surface.gdshaderinc):
# the building's down bent by a drifting fbm of position, with an intensity
# from a slower field. Value noise here, the corruption include's there —
# they agree in character, not bitwise, which is all the organism needs.

static func _hash3(ix: int, iy: int, iz: int, seed_v: float) -> float:
	var h := float(ix * 127 + iy * 311 + iz * 74) + seed_v * 17.3
	return fposmod(sin(h) * 43758.5453, 1.0)


static func _noise3(p: Vector3, seed_v: float) -> float:
	var ix := int(floor(p.x))
	var iy := int(floor(p.y))
	var iz := int(floor(p.z))
	var fx := p.x - float(ix)
	var fy := p.y - float(iy)
	var fz := p.z - float(iz)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var x00 := lerpf(_hash3(ix, iy, iz, seed_v), _hash3(ix + 1, iy, iz, seed_v), fx)
	var x10 := lerpf(_hash3(ix, iy + 1, iz, seed_v), _hash3(ix + 1, iy + 1, iz, seed_v), fx)
	var x01 := lerpf(_hash3(ix, iy, iz + 1, seed_v), _hash3(ix + 1, iy, iz + 1, seed_v), fx)
	var x11 := lerpf(_hash3(ix, iy + 1, iz + 1, seed_v), _hash3(ix + 1, iy + 1, iz + 1, seed_v), fx)
	return lerpf(lerpf(x00, x10, fy), lerpf(x01, x11, fy), fz)


static func _fbm3(p: Vector3, seed_v: float) -> float:
	return _noise3(p, seed_v) * 0.5 + _noise3(p * 2.03, seed_v + 1.0) * 0.3 \
			+ _noise3(p * 4.1, seed_v + 2.0) * 0.2


## The gravity at a world position and time: a unit vector and an intensity.
## Returns Vector4(gx, gy, gz, intensity).
static func gravity_at(p: Vector3, t: float, phase: float) -> Vector4:
	var q := p * 0.35 + Vector3(t * 0.05, phase * 0.7, -t * 0.03)
	var bend := Vector3(_fbm3(q, 3.0) - 0.5, _fbm3(q + Vector3(11.0, 0.0, 0.0), 5.0) - 0.5,
			_fbm3(q + Vector3(0.0, 0.0, 23.0), 7.0) - 0.5) * 2.2
	var g := (Vector3(0.0, -1.0, 0.0) + bend).normalized()
	var intensity := 0.4 + 1.3 * _fbm3(p * 0.2 + Vector3(0.0, t * 0.03, 0.0), 9.0)
	return Vector4(g.x, g.y, g.z, intensity)


func _refresh_gravity() -> void:
	var phase := pulse_phase()
	for y in _gy:
		for z in _gz:
			for x in _gx:
				var p := origin + Vector3((float(x) + 0.5) * GRAVITY_CELL_M,
						(float(y) + 0.5) * GRAVITY_CELL_M, (float(z) + 0.5) * GRAVITY_CELL_M)
				_gravity_cache[(y * _gz + z) * _gx + x] = gravity_at(p, clock, phase)


## A few cells per tick: the whole lattice about once a second, which a
## field drifting at 0.05 per second cannot tell from all at once.
func _refresh_gravity_some() -> void:
	var phase := pulse_phase()
	var n := _gravity_cache.size()
	var plane := _gx * _gz
	for _i in GRAVITY_CELLS_PER_TICK:
		var k := _gravity_cursor
		var y := k / plane
		var z := (k - y * plane) / _gx
		var x := k - y * plane - z * _gx
		var p := origin + Vector3((float(x) + 0.5) * GRAVITY_CELL_M,
				(float(y) + 0.5) * GRAVITY_CELL_M, (float(z) + 0.5) * GRAVITY_CELL_M)
		_gravity_cache[k] = gravity_at(p, clock, phase)
		_gravity_cursor = (_gravity_cursor + 1) % n


func _gravity_cached(p: Vector3) -> Vector4:
	var x := clampi(int((p.x - origin.x) / GRAVITY_CELL_M), 0, _gx - 1)
	var y := clampi(int((p.y - origin.y) / GRAVITY_CELL_M), 0, _gy - 1)
	var z := clampi(int((p.z - origin.z) / GRAVITY_CELL_M), 0, _gz - 1)
	return _gravity_cache[(y * _gz + z) * _gx + x]


# ── THE FIELD ────────────────────────────────────────────────────────────

func _index(x: int, y: int, z: int) -> int:
	return (y * nz + z) * nx + x


func _cell_of(p: Vector3) -> Vector3i:
	return Vector3i(clampi(int((p.x - origin.x) / VOXEL_M), 0, nx - 1),
			clampi(int((p.y - origin.y) / VOXEL_M), 0, ny - 1),
			clampi(int((p.z - origin.z) / VOXEL_M), 0, nz - 1))


func _sense(p: Vector3) -> float:
	var c := _cell_of(p)
	var i := _index(c.x, c.y, c.z)
	return trail[i] - 0.6 * stain[i]


func _random_dir() -> Vector3:
	return Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.35, 0.35),
			_rng.randf_range(-1.0, 1.0)).normalized()


func _spawn(at: Vector3, src: int) -> void:
	_agents_pos.append(at)
	_agents_dir.append(_random_dir())
	_agents_starve.append(0)
	_agents_src.append(src)


func _remove_agent(i: int) -> void:
	_agents_pos.remove_at(i)
	_agents_dir.remove_at(i)
	_agents_starve.remove_at(i)
	_agents_src.remove_at(i)


func _step() -> void:
	steps += 1
	var pulse := 0.5 + 0.5 * cos(pulse_phase() * TAU)
	var phase := pulse_phase()

	# Food at each source; the agent budget per source is its case's intensity
	# scaled by the gravity's appetite there.
	var budgets: Array[int] = []
	var total_budget := 0
	for si in sources.size():
		var src: Dictionary = sources[si]
		var it := float(src.intensity)
		var want := 0
		if it > 0.001:
			var g := _gravity_cached(src.position)
			var appetite := clampf(g.w, 0.4, 1.7)
			want = int((AGENT_MIN + AGENT_SPAN * it) * (0.6 + 0.4 * appetite))
			var sc := _cell_of(src.position)
			trail[_index(sc.x, sc.y, sc.z)] += FOOD * it
		budgets.append(want)
		total_budget += want
	var counts: Array[int] = []
	counts.resize(sources.size())
	counts.fill(0)
	for i in _agents_src.size():
		var s := _agents_src[i]
		if s >= 0 and s < counts.size():
			counts[s] += 1
	for si in sources.size():
		var guard := 0
		while counts[si] < budgets[si] and guard < 64:
			guard += 1
			var at: Vector3 = sources[si].position
			if counts[si] > 8 and _rng.randf() < 0.7:
				# Born on the body — the veins — of this source's organism.
				var j := _rng.randi_range(0, _agents_pos.size() - 1)
				if _agents_src[j] == si:
					at = _agents_pos[j]
			_spawn(at + _random_dir() * VOXEL_M * 0.5, si)
			counts[si] += 1
	var i := _agents_pos.size() - 1
	while i >= 0 and _agents_pos.size() > total_budget:
		var s := _agents_src[i]
		if s < 0 or s >= counts.size() or counts[s] > budgets[s]:
			_remove_agent(i)
			if s >= 0 and s < counts.size():
				counts[s] -= 1
		i -= 1

	# Agents: sense ahead (and four tilted), turn, take the gravity, step, deposit.
	var lo := origin + Vector3(VOXEL_M, VOXEL_M, VOXEL_M) * 0.5
	var hi := origin + size_m - Vector3(VOXEL_M, VOXEL_M, VOXEL_M) * 0.5
	var so := VOXEL_M * float(SENSOR_VOXELS)
	i = 0
	while i < _agents_pos.size():
		var p := _agents_pos[i]
		var d := _agents_dir[i]
		var g := _gravity_cached(p)
		var appetite := clampf(g.w, 0.4, 1.7)
		var step_m := VOXEL_M * (0.35 + 0.6 * pulse) * (0.7 + 0.3 * appetite)
		var deposit := DEPOSIT * (0.6 + 0.8 * pulse) * (0.7 + 0.3 * appetite)
		var side := d.cross(Vector3.UP)
		if side.length_squared() < 0.01:
			side = d.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(d).normalized()
		var best := d
		var best_v := _sense(p + d * so)
		for cand in [
				(d * 0.7071 + side * 0.7071).normalized(),
				(d * 0.7071 - side * 0.7071).normalized(),
				(d * 0.7071 + up * 0.7071).normalized(),
				(d * 0.7071 - up * 0.7071).normalized()]:
			var v := _sense(p + cand * so)
			if v > best_v:
				best_v = v
				best = cand
		# The gravity pulls every heading; a little wander so the front fingers.
		d = (best + Vector3(g.x, g.y, g.z) * GRAVITY_PULL * appetite
				+ _random_dir() * 0.18).normalized()
		var np := p + d * step_m
		if np.x < lo.x or np.x > hi.x:
			d.x = -d.x
		if np.y < lo.y or np.y > hi.y:
			d.y = -d.y
		if np.z < lo.z or np.z > hi.z:
			d.z = -d.z
		np = Vector3(clampf(np.x, lo.x, hi.x), clampf(np.y, lo.y, hi.y), clampf(np.z, lo.z, hi.z))
		var c := _cell_of(np)
		var ci := _index(c.x, c.y, c.z)
		trail[ci] += deposit
		# Pooling: the bottom (and, when the gravity points up, the top) slice
		# holds body more readily — the organism spills and pools.
		var pool := 1.0
		if (c.y == 0 and g.y < -0.3) or (c.y == ny - 1 and g.y > 0.3):
			pool = POOL_GAIN
		body[ci] = minf(1.0, body[ci] + 0.25 * pool)
		who[ci] = _agents_src[i]
		if trail[ci] < STARVE_TRAIL:
			_agents_starve[i] += 1
		else:
			_agents_starve[i] = 0
		if _agents_starve[i] > 12:
			_remove_agent(i)
			continue
		_agents_pos[i] = np
		_agents_dir[i] = d
		i += 1


## One y-slice of the relaxation: 6-neighbour mean of the trail (the
## diffusion) then decay; body decays, and on the pooling slices it also
## spreads sideways; stain integrates the body and decays over minutes. The
## slice is encoded into its image as it goes. Hot loop: inlined, no calls.
func _relax_slice(y: int) -> void:
	var plane := nx * nz
	var base := y * plane
	var bytes := PackedByteArray()
	bytes.resize(plane * 4)
	var o := 0
	var pool_slice := (y == 0 or y == ny - 1)
	for z in nz:
		var row := base + z * nx
		for x in nx:
			var k := row + x
			var sum := trail[k] * 2.0
			var cnt := 2.0
			var bsum := body[k] * 2.0
			var bcnt := 2.0
			if x > 0:
				sum += trail[k - 1]; cnt += 1.0; bsum += body[k - 1]; bcnt += 1.0
			if x < nx - 1:
				sum += trail[k + 1]; cnt += 1.0; bsum += body[k + 1]; bcnt += 1.0
			if z > 0:
				sum += trail[k - nx]; cnt += 1.0; bsum += body[k - nx]; bcnt += 1.0
			if z < nz - 1:
				sum += trail[k + nx]; cnt += 1.0; bsum += body[k + nx]; bcnt += 1.0
			if y > 0:
				sum += trail[k - plane]; cnt += 1.0
			if y < ny - 1:
				sum += trail[k + plane]; cnt += 1.0
			var t := minf((sum / cnt) * TRAIL_DECAY, 4.0)
			var b := body[k]
			if pool_slice:
				b = maxf(b, (bsum / bcnt) * 0.92)
			var st := minf(1.0, stain[k] * STAIN_DECAY + b * STAIN_GAIN)
			_scratch[k] = t
			stain[k] = st
			body[k] = b * BODY_DECAY
			bytes[o] = int(minf(t * 0.25, 1.0) * 255.0)
			bytes[o + 1] = int(minf(b, 1.0) * 255.0)
			bytes[o + 2] = int(st * 255.0)
			bytes[o + 3] = int(who[k]) * 36 + 18
			o += 4
	_images[y].set_data(nx, nz, false, Image.FORMAT_RGBA8, bytes)


func _relax_slices() -> void:
	_ensure_images()
	for _i in SLICES_PER_TICK:
		_relax_slice(_slice_cursor)
		_slice_cursor += 1
		if _slice_cursor >= ny:
			_slice_cursor = 0
			for k in nx * ny * nz:
				trail[k] = _scratch[k]
			_find_nodes()
			_upload_due = true


## The organism's strongest nodes after a pass: up to three, at least 2 m
## apart, for the lights. Coarse scan over every 2nd voxel in x and z.
func _find_nodes() -> void:
	nodes.clear()
	node_strength.clear()
	node_source.clear()
	var plane := nx * nz
	for _n in 3:
		var best := -1
		var best_v := 0.35
		for y in range(0, ny, 2):
			for z in range(0, nz, 2):
				for x in range(0, nx, 2):
					var k := (y * nz + z) * nx + x
					var v := body[k]
					if v <= best_v:
						continue
					var p := origin + Vector3((float(x) + 0.5) * VOXEL_M,
							(float(y) + 0.5) * VOXEL_M, (float(z) + 0.5) * VOXEL_M)
					var far := true
					for q in nodes:
						if q.distance_to(p) < 2.0:
							far = false
							break
					if far:
						best = k
						best_v = v
		if best < 0:
			break
		var yy := best / plane
		var zz := (best - yy * plane) / nx
		var xx := best - yy * plane - zz * nx
		nodes.append(origin + Vector3((float(xx) + 0.5) * VOXEL_M,
				(float(yy) + 0.5) * VOXEL_M, (float(zz) + 0.5) * VOXEL_M))
		node_strength.append(best_v)
		node_source.append(int(who[best]))


## Facts for tests and the inspection HUD.
func census() -> Dictionary:
	var n := nx * ny * nz
	var live := 0
	var stained := 0
	var body_max := 0.0
	var floor_live := 0
	var plane := nx * nz
	for k in n:
		if body[k] > 0.2:
			live += 1
			if k < plane:
				floor_live += 1
		if stain[k] > 0.1:
			stained += 1
		body_max = maxf(body_max, body[k])
	return {"agents": _agents_pos.size(), "live_voxels": live, "stained_voxels": stained,
			"body_max": body_max, "voxels": n, "steps": steps, "floor_live": floor_live,
			"nodes": nodes.size(), "sources": sources.size()}


## --- LF-3: the organism in someone else's flat ------------------------------
## (owner ruling 2026-08-22: "Juno will report it and it has the chance of
## making a fixable condition happen in the area.")


## Whose body is inside a world rect (x0, z0, x1, z1) on this storey: one
## entry per source — live voxel count (body > 0.3), the strongest value and
## where it is. Cheap: only the rect's cells are visited.
func survey(rect: Vector4) -> Array:
	var out: Array = []
	for _s in sources.size():
		out.append({"count": 0, "best": 0.0, "at": Vector3.ZERO})
	if out.is_empty():
		return out
	var x0 := clampi(int(floor((rect.x - origin.x) / VOXEL_M)), 0, nx - 1)
	var x1 := clampi(int(ceil((rect.z - origin.x) / VOXEL_M)), 0, nx - 1)
	var z0 := clampi(int(floor((rect.y - origin.z) / VOXEL_M)), 0, nz - 1)
	var z1 := clampi(int(ceil((rect.w - origin.z) / VOXEL_M)), 0, nz - 1)
	var plane := nx * nz
	for y in ny:
		for z in range(z0, z1 + 1):
			var row := y * plane + z * nx
			for x in range(x0, x1 + 1):
				var k := row + x
				var b := body[k]
				if b <= 0.3:
					continue
				var s := int(who[k])
				if s >= out.size():
					continue
				var entry: Dictionary = out[s]
				entry.count = int(entry.count) + 1
				if b > float(entry.best):
					entry.best = b
					entry.at = origin + Vector3((float(x) + 0.5) * VOXEL_M,
							(float(y) + 0.5) * VOXEL_M, (float(z) + 0.5) * VOXEL_M)
	return out


## The organism withdraws from a rect: the body is scrubbed, the trail the
## agents steer by goes, the agents inside starve, and the stain — the slime
## the organism avoids (Reid 2012) — is raised, so the flat stays repellent
## until the stain has faded. What a fix does to the area.
func repel(rect: Vector4, stain_level := 0.9) -> int:
	var x0 := clampi(int(floor((rect.x - origin.x) / VOXEL_M)), 0, nx - 1)
	var x1 := clampi(int(ceil((rect.z - origin.x) / VOXEL_M)), 0, nx - 1)
	var z0 := clampi(int(floor((rect.y - origin.z) / VOXEL_M)), 0, nz - 1)
	var z1 := clampi(int(ceil((rect.w - origin.z) / VOXEL_M)), 0, nz - 1)
	var plane := nx * nz
	var touched := 0
	for y in ny:
		for z in range(z0, z1 + 1):
			var row := y * plane + z * nx
			for x in range(x0, x1 + 1):
				var k := row + x
				if body[k] > 0.05 or trail[k] > 0.05:
					touched += 1
				body[k] *= 0.08
				trail[k] = 0.0
				stain[k] = maxf(stain[k], stain_level)
	var i := _agents_pos.size() - 1
	while i >= 0:
		var p := _agents_pos[i]
		if p.x >= rect.x and p.x <= rect.z and p.z >= rect.y and p.z <= rect.w:
			_remove_agent(i)
		i -= 1
	_upload_due = true
	return touched


## Plant a body in a rect for a source (tests and authored beginnings): the
## organism is already there, with agents to keep it alive.
func plant(rect: Vector4, src: int, value := 0.8, agents := 60) -> void:
	if src < 0 or src >= sources.size():
		return
	var x0 := clampi(int(floor((rect.x - origin.x) / VOXEL_M)), 0, nx - 1)
	var x1 := clampi(int(ceil((rect.z - origin.x) / VOXEL_M)), 0, nx - 1)
	var z0 := clampi(int(floor((rect.y - origin.z) / VOXEL_M)), 0, nz - 1)
	var z1 := clampi(int(ceil((rect.w - origin.z) / VOXEL_M)), 0, nz - 1)
	var plane := nx * nz
	for y in range(0, mini(ny, 4)):
		for z in range(z0, z1 + 1):
			var row := y * plane + z * nx
			for x in range(x0, x1 + 1):
				var k := row + x
				body[k] = maxf(body[k], value)
				trail[k] = maxf(trail[k], 1.5)
				who[k] = src
	for _a in agents:
		_spawn(Vector3(_rng.randf_range(rect.x, rect.z), origin.y + _rng.randf_range(0.3, 1.8),
				_rng.randf_range(rect.y, rect.w)), src)
	_upload_due = true
