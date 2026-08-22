class_name LivingField
extends RefCounted
## THE ENCROACHMENT AS A SLIME MOULD (design/LIVING_FIELD_BRIEF.md).
##
## A coarse 3-D field over one case flat — trail, body, stain — driven by
## Physarum-style agents (Jones 2010): particles sense a diffusing, decaying
## chemoattractant trail ahead of them, turn toward the strongest, step and
## deposit. The BODY is the live plasmodium (recent agent density, fast
## decay, so it recedes where the agents leave); the STAIN is the
## extracellular slime the organism leaves and avoids (Reid et al. 2012), a
## slow integrator of the body; the SOURCE (the case's beachhead) deposits
## food. Shuttle streaming is a global cosine on speed and deposit. Uploaded
## as an ImageTexture3D the layered surface samples in world space.
##
## Presentation only: no collision, no gameplay owner, no save key.

const VOXEL_M := 0.25
const MAX_XZ := 56
const MAX_Y := 18
const STEP_HZ := 8.0
const PULSE_S := 14.0

const TRAIL_DECAY := 0.92
## The body persists for minutes once laid (0.97 per pass at ~18 passes/s):
## a plasmodium keeps the ground it has taken until it withdraws.
const BODY_DECAY := 0.97
const STAIN_GAIN := 0.12
const STAIN_DECAY := 0.996
const SENSOR_VOXELS := 3
const DEPOSIT := 0.55
const FOOD := 0.3
const STARVE_TRAIL := 0.02
const AGENT_MIN := 120
const AGENT_SPAN := 780

var origin := Vector3.ZERO
var size_m := Vector3.ZERO
var nx := 1
var ny := 1
var nz := 1
var intensity := 0.0
var source := Vector3.ZERO
var seed := 1
var clock := 0.0
var steps := 0

var trail := PackedFloat32Array()
var body := PackedFloat32Array()
var stain := PackedFloat32Array()
var _scratch := PackedFloat32Array()
var _agents_pos := PackedVector3Array()
var _agents_dir := PackedVector3Array()
var _agents_starve := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _texture: ImageTexture3D
var _accum := 0.0
## The relaxation (diffuse, decay, encode) is amortised: SLICES_PER_TICK
## y-slices each tick, so a full pass takes ny / SLICES_PER_TICK ticks and
## no tick loops over the whole field. Decay constants are per PASS.
const SLICES_PER_TICK := 5
var _slice_cursor := 0
var _images: Array[Image] = []
var _upload_due := false


## `rect` is the flat in Godot xz (x0, z0, x1, z1), `floor_y` its floor.
func configure(rect: Vector4, floor_y: float, source_world: Vector3, rng_seed: int) -> void:
	origin = Vector3(rect.x, floor_y - 0.1, rect.y)
	size_m = Vector3(rect.z - rect.x, 3.4, rect.w - rect.y)
	nx = clampi(int(ceil(size_m.x / VOXEL_M)), 4, MAX_XZ)
	nz = clampi(int(ceil(size_m.z / VOXEL_M)), 4, MAX_XZ)
	ny = clampi(int(ceil(size_m.y / VOXEL_M)), 4, MAX_Y)
	var n := nx * ny * nz
	trail.resize(n); trail.fill(0.0)
	body.resize(n); body.fill(0.0)
	stain.resize(n); stain.fill(0.0)
	_scratch.resize(n)
	source = source_world
	seed = rng_seed
	_rng.seed = rng_seed
	_agents_pos.clear()
	_agents_dir.clear()
	_agents_starve.clear()


func texture() -> ImageTexture3D:
	if _texture == null:
		_ensure_images()
		_texture = ImageTexture3D.new()
		_texture.create(Image.FORMAT_RGB8, nx, nz, ny, false, _images)
	return _texture


func _ensure_images() -> void:
	if _images.size() == ny:
		return
	_images.clear()
	for y in ny:
		_images.append(Image.create(nx, nz, false, Image.FORMAT_RGB8))


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
	if _upload_due and _texture != null:
		_texture.update(_images)
		_upload_due = false
		return true
	return false


## The shuttle-streaming phase, 0..1 over PULSE_S; the surface breathes with it.
func pulse_phase() -> float:
	return fmod(clock, PULSE_S) / PULSE_S


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


func _spawn(at: Vector3) -> void:
	_agents_pos.append(at)
	_agents_dir.append(_random_dir())
	_agents_starve.append(0)


func _step() -> void:
	steps += 1
	var n := nx * ny * nz
	# Shuttle streaming: the organism pushes on one half of the cycle.
	var pulse := 0.5 + 0.5 * cos(pulse_phase() * TAU)
	var step_m := VOXEL_M * (0.35 + 0.6 * pulse)
	var deposit := DEPOSIT * (0.6 + 0.8 * pulse)

	# Food at the source; the agent budget is the case's intensity.
	var sc := _cell_of(source)
	trail[_index(sc.x, sc.y, sc.z)] += FOOD * intensity
	var budget := int(AGENT_MIN + AGENT_SPAN * intensity) if intensity > 0.001 else 0
	while _agents_pos.size() < budget:
		var at := source
		if _agents_pos.size() > 8 and _rng.randf() < 0.7:
			# Born on the body — the veins — not only at the source.
			at = _agents_pos[_rng.randi_range(0, _agents_pos.size() - 1)]
		_spawn(at + _random_dir() * VOXEL_M * 0.5)
	while _agents_pos.size() > budget:
		_agents_pos.remove_at(_agents_pos.size() - 1)
		_agents_dir.remove_at(_agents_dir.size() - 1)
		_agents_starve.remove_at(_agents_starve.size() - 1)

	# Agents: sense ahead (and four tilted), turn, step, deposit.
	var lo := origin + Vector3(VOXEL_M, VOXEL_M, VOXEL_M) * 0.5
	var hi := origin + size_m - Vector3(VOXEL_M, VOXEL_M, VOXEL_M) * 0.5
	var so := VOXEL_M * float(SENSOR_VOXELS)
	var i := 0
	while i < _agents_pos.size():
		var p := _agents_pos[i]
		var d := _agents_dir[i]
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
		# A little wander so the front fingers rather than files.
		d = (best + _random_dir() * 0.18).normalized()
		var np := p + d * step_m
		# Stay in the flat's volume: bounce off its faces.
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
		body[ci] = minf(1.0, body[ci] + 0.35)
		# Starvation: nothing to follow here for a while -> die; a new agent
		# is born at the source or on the body next step.
		if trail[ci] < STARVE_TRAIL:
			_agents_starve[i] += 1
		else:
			_agents_starve[i] = 0
		if _agents_starve[i] > 12:
			_agents_pos.remove_at(i)
			_agents_dir.remove_at(i)
			_agents_starve.remove_at(i)
			continue
		_agents_pos[i] = np
		_agents_dir[i] = d
		i += 1



## One y-slice of the relaxation: 6-neighbour mean of the trail (the
## diffusion) then decay; body decays fast; stain integrates the body and
## decays over minutes. The slice is encoded into its image as it goes. Hot
## loop: inlined indices, no calls.
func _relax_slice(y: int) -> void:
	var plane := nx * nz
	var base := y * plane
	var bytes := PackedByteArray()
	bytes.resize(plane * 3)
	var o := 0
	for z in nz:
		var row := base + z * nx
		for x in nx:
			var k := row + x
			var sum := trail[k] * 2.0
			var cnt := 2.0
			if x > 0:
				sum += trail[k - 1]; cnt += 1.0
			if x < nx - 1:
				sum += trail[k + 1]; cnt += 1.0
			if z > 0:
				sum += trail[k - nx]; cnt += 1.0
			if z < nz - 1:
				sum += trail[k + nx]; cnt += 1.0
			if y > 0:
				sum += trail[k - plane]; cnt += 1.0
			if y < ny - 1:
				sum += trail[k + plane]; cnt += 1.0
			var t := minf((sum / cnt) * TRAIL_DECAY, 4.0)
			var b := body[k]
			var st := minf(1.0, stain[k] * STAIN_DECAY + b * STAIN_GAIN)
			_scratch[k] = t
			stain[k] = st
			body[k] = b * BODY_DECAY
			bytes[o] = int(minf(t * 0.25, 1.0) * 255.0)
			bytes[o + 1] = int(minf(b, 1.0) * 255.0)
			bytes[o + 2] = int(st * 255.0)
			o += 3
	_images[y].set_data(nx, nz, false, Image.FORMAT_RGB8, bytes)


func _relax_slices() -> void:
	_ensure_images()
	for _i in SLICES_PER_TICK:
		_relax_slice(_slice_cursor)
		_slice_cursor += 1
		if _slice_cursor >= ny:
			_slice_cursor = 0
			# The diffused trail replaces the old one only after a full
			# pass, so every slice reads the same generation.
			var plane := nx * nz
			for k in nx * ny * nz:
				trail[k] = _scratch[k]
			_upload_due = true


## Facts for tests and the inspection HUD.
func census() -> Dictionary:
	var n := nx * ny * nz
	var live := 0
	var stained := 0
	var body_max := 0.0
	var lo := Vector3i(nx, ny, nz)
	var hi := Vector3i(-1, -1, -1)
	var plane := nx * nz
	for k in n:
		if body[k] > 0.2:
			live += 1
		if stain[k] > 0.1:
			stained += 1
		body_max = maxf(body_max, body[k])
		if body[k] > 0.1 or trail[k] > 0.3:
			var y := k / plane
			var z := (k - y * plane) / nx
			var x := k - y * plane - z * nx
			lo = Vector3i(mini(lo.x, x), mini(lo.y, y), mini(lo.z, z))
			hi = Vector3i(maxi(hi.x, x), maxi(hi.y, y), maxi(hi.z, z))
	var extent := 0
	if hi.x >= lo.x:
		extent = (hi.x - lo.x + 1) * (hi.z - lo.z + 1)
	return {"agents": _agents_pos.size(), "live_voxels": live, "stained_voxels": stained,
			"body_max": body_max, "voxels": n, "steps": steps, "extent_cells": extent}
