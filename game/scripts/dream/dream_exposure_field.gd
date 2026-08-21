class_name DreamExposureField
extends RefCounted
## HOW MUCH OF HER YOU HAVE UNCOVERED, AND IT DOES NOT GO BACK.
##
## Workstream A of design/DREAM_SURFACE_REDESIGN_BRIEF.md, and the foundation
## every other workstream in it depends on. The brief's own diagnosis:
##
##   "Exposure is instantaneous, not accumulated. `heat` is recomputed every
##   frame from the lamp cone, so gold appears while lit and vanishes when the
##   beam moves. Every plate shows the opposite: the conversion STAYS."
##
## So this is the thing that stays. A coarse scalar field over the pocket that
## only ever goes up while a room is real, written by the lamp and seeded by
## how forgotten the room already is, and read by the shader as the answer to
## "has the building turned here yet".
##
## ─────────────────────────────────────────────────────────────────────────
## IT IS A VOLUME, NOT A LIGHTMAP, AND THAT IS THE WHOLE POINT
##
## The obvious build is a per-surface buffer -- unwrap each wall, accumulate
## into its texels. This is a VOLUME instead, sampled by world position, and
## the reasons are in order of how much they matter:
##
## 1. THE FICTION SAYS VOLUME. design/THE_TENANT.md: "the building IS her
##    body", and the gold under the plaster is what that body looks like from
##    inside three dimensions. A thing underneath the whole building is not a
##    property of a wall. When the infection crosses from the wall onto the
##    floor in plate 1 it is not two surfaces agreeing -- it is one mass
##    showing through both, and a volume gets that for free while any
##    per-surface scheme has to fake continuity at every corner.
##
## 2. THE SHADER IS ALREADY WORLD-SPACE. dream_klimt.gdshader is triplanar
##    precisely because "the maze is graybox boxes with no usable UVs", and
##    projecting from world space "runs the ornament CONTINUOUSLY from one
##    module into the next". A world-space field is the same decision made
##    again; a UV-space field would be the first thing in the dream to need
##    per-object unwrapping, on geometry that is generated at runtime.
##
## 3. IT COSTS NOTHING TO SUBMIT. One sampler3D shared by every Klimt
##    material. The frame is submission-bound (TASKS.md P) and this adds no
##    draws, no material instances and no meshes -- it adds one texture and
##    three uniforms to materials that already exist.
##
## ─────────────────────────────────────────────────────────────────────────
## WHY IT WRAPS INSTEAD OF FOLLOWING THE PLAYER
##
## The pocket translates through world space forever -- the building does not
## close, so a passage walks in one direction and never comes back. A field
## anchored to the player has to be re-anchored, and re-anchoring either
## resamples (expensive, and lossy every time) or clears (which would erase
## the accumulation this class exists to keep).
##
## So it does not move. It TILES: world position maps into the grid modulo the
## grid, and the sampler repeats. Nothing is ever re-anchored, nothing is ever
## resampled, and a room 48 m away aliases onto the same voxels as one here --
## which is safe for exactly the reason the pocket is safe, that the far room
## does not exist. Rooms are stamped when built and zeroed when freed, so a
## region wrapping back into use was cleared by whoever left it.
##
## The one thing that would break it is two SIMULTANEOUSLY live rooms landing
## on the same voxels, which needs a pocket wider than EXTENT_M. `overflowed()`
## reports that rather than letting it render as a mystery, and the extent is
## set with a lot of room: the pocket is a trail of three plus one room's
## neighbours, and the catalog's largest module is under 11 m.
##
## ─────────────────────────────────────────────────────────────────────────
## WHAT FEEDS IT
##
## THE LAMP, by dwell. Not "is lit" but "has been lit, for how long" -- the
## beam converts at CONVERT_PER_S at the centre of the cone, so a wall glanced
## across is touched and a wall held on is taken. That is the mechanic the
## plates are drawing: the player's own attention is what spreads it.
##
## DECAY, at stamp time. DreamAtlas.decay(id, depth) is already "how far gone
## this room is" -- nights compounded, plus distance from where you woke -- and
## the brief asks for the texture to evolve "as time in the maze continues AND
## light is cast". A room deep in a sixth-night building starts part-turned
## before the player's beam ever reaches it.
##
## THE ROOM'S OWN SEED, so no two rooms grow alike. DreamAtlas.aspect(id, salt)
## costs nothing and already names every other property of a room this way.
##
## ─────────────────────────────────────────────────────────────────────────
## AND IT IS HER BEHAVIOUR TOO
##
## THE_TENANT.md §3: this field is "how much of her you have uncovered in this
## room -- and she should avoid the rooms where she is most exposed." That is
## why `room_exposure()` exists and why the CPU keeps the authoritative copy
## rather than living only on the GPU. The shader and the pursuer read the
## same number, which is the whole reason the behaviour is free.

## Half a metre. The growth front is domain-warped noise in the shader, so the
## field only has to say WHERE the mass roughly is -- the ragged edge is drawn
## at pixel resolution from a value interpolated out of this. Finer would cost
## linearly for detail that is thrown away and then re-invented.
const VOXEL_M := 0.5
## 96 x 96 voxels of 0.5 m is 48 m square. See the wrapping note above: this
## has to comfortably exceed the widest the live pocket can ever be.
const GRID_XZ := 96
## Eight layers of 0.5 m covers 0..4 m, which holds the 3.015 m clear ceiling
## and its slab. Y does NOT wrap -- the fractal is single-storey, every room
## is placed in a plane, and a ceiling bleeding onto a floor would be a
## coordinate bug rather than a feature.
const GRID_Y := 8
const EXTENT_M := float(GRID_XZ) * VOXEL_M
const HEIGHT_M := float(GRID_Y) * VOXEL_M

## Seconds of beam held dead-centre to convert a surface outright. Six is slow
## enough that sweeping a corridor leaves a trail rather than a wash, and fast
## enough that deliberately holding on one wall visibly does something inside
## a 28 s passage.
const CONVERT_PER_S := 1.0 / 6.0
## IR-V1's reversible presentation channel. These are absolute response units
## per second, not lerp factors, so the photosensitivity ceiling is invariant
## under frame rate and EXPOSURE_HZ changes.
const IRRADIANCE_RISE_PER_S := 0.42
const IRRADIANCE_FALL_PER_S := 0.28
## How much of a room decay alone can turn before the lamp arrives. Capped
## well below 1 because of the brief's control shot: "the same corridor,
## unlit, must be photographable as an ordinary derelict apartment hallway
## with nothing wrong with it." Decay makes a room look further gone; it must
## never make it look finished.
const DECAY_CEILING := 0.34

## Salt for the per-room blotching. A golden vector the moment it ships, same
## as every salt in dream_atlas.gd and dream_room_builder.gd: it names a fact
## about every room in every campaign and changing it re-grows the whole
## building for every existing save, silently.
const SALT_EXPOSURE := 0xE7B05E

## voxel index -> 0..255. One durable byte per voxel; the shader samples RG8 R.
var _cells := PackedByteArray()
## Reversible direct irradiance, 0..1. This shares the existing volume and GPU
## sampler with durable exposure but is never read by gameplay.
var _irradiance := PackedFloat32Array()
## Set once if a stamp ever wrapped onto a live room. Diagnostic, never
## gameplay -- see overflowed().
var _overflow := false
## Rooms currently stamped, key -> the span of grid columns they cover. The
## span rather than the rect because every reader wants the columns, and
## recomputing them per call was showing up in the stamp path.
var _stamped: Dictionary = {}
## grid column -> the room key that stamped it. Not a correctness check any
## more (see _note_extent) -- it exists so a departing room only zeroes the
## columns it still owns, and a column shared with a live neighbour across a
## doorway keeps its gold.
var _owner: Dictionary = {}
## key -> the world rect, kept alongside the span because the overflow test is
## a question about world metres and the span has already lost them.
var _rects: Dictionary = {}
## Has anything changed since the last upload? The field moves on two very
## different clocks -- the lamp writes continuously, but stamping and clearing
## only happen when the player crosses a threshold -- so "upload when the lamp
## ran" would miss a whole room appearing, and "upload every tick" rebuilds
## eight Images a tick to re-send bytes that did not move.
var _dirty := true


func _init() -> void:
	_cells.resize(GRID_XZ * GRID_XZ * GRID_Y)
	_cells.fill(0)
	_irradiance.resize(_cells.size())
	_irradiance.fill(0.0)


# ── ADDRESSING ────────────────────────────────────────────────────────────
#
# World metres to grid. X and Z wrap; Y clamps. posmod rather than % because
# a passage walks into negative world coordinates about half the time and
# GDScript's % keeps the sign, which would fold two different places onto one
# index and mirror the field across the origin.

static func _wrap(v: float) -> int:
	return posmod(int(floor(v / VOXEL_M)), GRID_XZ)


static func _layer(y: float) -> int:
	return clampi(int(floor(y / VOXEL_M)), 0, GRID_Y - 1)


static func _index(ix: int, iy: int, iz: int) -> int:
	return iy * GRID_XZ * GRID_XZ + iz * GRID_XZ + ix


## Deterministic 0..1 per voxel per room.
##
## DreamAtlas.mix64 rather than a hash written here, and that file's own
## header says why: "String.hash() was re-implemented from memory once in this
## project and produced confident wrong numbers for a day; anything this file
## depends on for determinism is defined here, in one place, where it can be
## tested." A second private hash in the same subsystem would be the same
## mistake with the same failure mode -- and the first draft of this one
## multiplied its way past 2^63 on ordinary grid coordinates, which wraps
## silently and is exactly the class of bug the kickoff log warns about twice.
##
## The final step is aspect()'s, verbatim, so a voxel and a room property are
## drawn from one distribution.
static func _hash01(a: int, b: int, c: int, salt: int) -> float:
	var h := DreamAtlas.mix64(DreamAtlas.mix64(a, b),
			DreamAtlas.mix64(c, salt))
	return float(absi(h) % 1000003) / 1000003.0


# ── WRITING ───────────────────────────────────────────────────────────────

## A room became real. Lay down its baseline.
##
## `rect` is [x0, z0, x1, z1] in world metres, exactly as DreamRoomBuilder
## writes it into plan.modules. `decay` and `seed01` come from the atlas --
## decay(id, depth) and aspect(id, salt) -- so this class never needs to know
## what an atlas is and stays testable without one.
##
## The baseline is BLOTCHY, not flat. A uniform fill would put a visible
## rectangle of slightly-gold at every room boundary, which is the one thing
## the whole triplanar design exists to avoid; a hash per voxel makes decay
## read as patches the building has lost rather than as a per-room constant.
func stamp_room(key: String, rect: Array, decay: float,
		seed01: float) -> void:
	if rect.size() < 4 or _stamped.has(key):
		# Already real. Re-stamping would push the baseline back over
		# accumulation the player has paid for, which is precisely the
		# regression this class exists to prevent.
		return
	var span := _span(rect)
	_claim(key, span)
	_stamped[key] = span
	_rects[key] = rect.duplicate()
	_note_extent()
	_dirty = true
	var salt := SALT_EXPOSURE ^ int(clampf(seed01, 0.0, 1.0) * 1048576.0)
	var ceiling := clampf(decay, 0.0, 1.0) * DECAY_CEILING
	if ceiling <= 0.0:
		return
	for entry in span:
		var ix: int = entry[0]
		var iz: int = entry[1]
		for iy in GRID_Y:
			var n := _hash01(entry[2], entry[3], iy, salt)
			# Squared, so most of a lightly-decayed room stays bare and the
			# turned patches are few and definite. A linear ramp gave every
			# voxel a little gold, which reads as a dirty wall rather than as
			# something growing.
			var v := int(clampf(ceiling * n * n, 0.0, 1.0) * 255.0)
			var i := _index(ix, iy, iz)
			# max, not assign: a wrapped-in region may still hold something,
			# and the field's contract is that it never goes down.
			if v > int(_cells[i]):
				_cells[i] = v


## A room left the pocket. The building forgets what you did to it.
##
## Brief: "Rooms leaving the pocket may lose it. That is correct and
## thematically right." It is also what makes the wrapping safe -- the voxels
## are handed back clean for whoever wraps onto them next.
func clear_room(key: String) -> void:
	var span: Array = _stamped.get(key, [])
	_stamped.erase(key)
	_rects.erase(key)
	if not span.is_empty():
		_dirty = true
	for entry in span:
		var ix: int = entry[0]
		var iz: int = entry[1]
		var cell: int = ix * GRID_XZ + iz
		# Only if this room still owns the column. Under an overflow two rooms
		# share it and the survivor must keep its baseline.
		if str(_owner.get(cell, "")) != key:
			continue
		_owner.erase(cell)
		for iy in GRID_Y:
			var i := _index(ix, iy, iz)
			_cells[i] = 0
			_irradiance[i] = 0.0


## THE LAMP, ACCUMULATING. Called at a fixed low rate rather than per frame --
## see DreamMazeRoot; `dt` is the interval actually elapsed, so the conversion
## rate is in seconds of dwell and does not change with the update frequency.
##
## Everything here rejects on squared quantities before touching a sqrt. The
## cone is a small fraction of its own bounding box and almost every voxel
## visited is thrown away, so what this loop costs is dominated by how cheaply
## it can say no.
func add_lamp(origin: Vector3, dir: Vector3, reach: float, cos_outer: float,
		energy: float, dt: float) -> void:
	if dt <= 0.0:
		return
	var d := dir.normalized()
	var reach2 := reach * reach
	var gain := CONVERT_PER_S * dt * clampf(energy, 0.0, 4.0)
	var cos2 := cos_outer * cos_outer
	# Walk only live columns, but walk every voxel in them. A cone-only loop
	# cannot cool the part of the field the beam just left, which would turn the
	# reversible G channel into a second durable exposure record.
	for entry in _owner:
		var ix := int(int(entry) / GRID_XZ)
		var iz := int(entry) % GRID_XZ
		# Recover the closest world-space copy of this wrapped column to the lamp.
		var wx := (float(ix) + 0.5) * VOXEL_M
		var wz := (float(iz) + 0.5) * VOXEL_M
		wx += round((origin.x - wx) / EXTENT_M) * EXTENT_M
		wz += round((origin.z - wz) / EXTENT_M) * EXTENT_M
		for iy in GRID_Y:
			var wy := (float(iy) + 0.5) * VOXEL_M
			var to_v := Vector3(wx, wy, wz) - origin
			var dist2 := to_v.length_squared()
			var direct := 0.0
			if reach > 0.0 and energy > 0.0 and dist2 <= reach2 \
					and dist2 > 0.0001:
				var axial := to_v.dot(d)
				if axial > 0.0 and axial * axial >= cos2 * dist2:
					var dist := sqrt(dist2)
					var ang := clampf((axial / dist - cos_outer)
							/ maxf(0.0001, 1.0 - cos_outer), 0.0, 1.0)
					direct = clampf(ang * ang * (1.0 - dist / reach)
							* energy, 0.0, 1.0)
			var i := _index(ix, iy, iz)
			var previous := float(_irradiance[i])
			var rate := IRRADIANCE_RISE_PER_S if direct > previous \
					else IRRADIANCE_FALL_PER_S
			var response := move_toward(previous, direct, rate * dt)
			if absf(response - previous) > 0.00001:
				_irradiance[i] = response
				_dirty = true
			if direct <= 0.0 or gain <= 0.0:
				continue
			var next := int(_cells[i]) + int(ceil(gain * direct
					/ maxf(0.0001, energy) * 255.0))
			if next != int(_cells[i]):
				_dirty = true
			_cells[i] = 255 if next > 255 else next


# ── READING ───────────────────────────────────────────────────────────────

## 0..1 at a world point, nearest voxel. The shader interpolates; this is for
## gameplay, where "which room is she least willing to enter" does not need
## sub-voxel accuracy.
func sample(at: Vector3) -> float:
	return float(_cells[_index(_wrap(at.x), _layer(at.y), _wrap(at.z))]) / 255.0


## Presentation-only reversible irradiance at a world point.
func sample_irradiance(at: Vector3) -> float:
	return float(_irradiance[_index(_wrap(at.x), _layer(at.y), _wrap(at.z))])


## Diagnostic-only exact band staging for the production proof harness. It
## cannot alter durable R or gameplay and has no environment/configuration seam.
func pin_irradiance_for_proof(value: float) -> void:
	var pinned := clampf(value, 0.0, 1.0)
	for entry in _owner:
		var ix := int(int(entry) / GRID_XZ)
		var iz := int(entry) % GRID_XZ
		for iy in GRID_Y:
			_irradiance[_index(ix, iy, iz)] = pinned
	_dirty = true


## HOW EXPOSED SHE IS IN THIS ROOM. Mean over the room's footprint at standing
## height, which is the band the player's beam actually converts.
##
## THE_TENANT.md §3 wants her to avoid the rooms where she is most uncovered.
## This is that number, and it is a mean rather than a max deliberately: one
## wall the player happened to hold the lamp on should not make a whole room
## unbearable, but a room they have swept end to end should.
func room_exposure(key: String) -> float:
	var span: Array = _stamped.get(key, [])
	if span.is_empty():
		return 0.0
	var total_v := 0
	var iy := _layer(1.5)
	for entry in span:
		total_v += int(_cells[_index(int(entry[0]), iy, int(entry[1]))])
	return float(total_v) / float(span.size()) / 255.0


## Did two live rooms ever land on the same voxels? Diagnostic only. If this
## is ever true the extent is too small for the pocket the builder is holding
## and the answer is GRID_XZ, not a workaround.
func overflowed() -> bool:
	return _overflow


func stamped_rooms() -> int:
	return _stamped.size()


## Total conversion in the field, 0..1 of its capacity. The tests measure
## monotonicity against this, and it is the cheapest possible assertion that
## the lamp is reaching the field at all.
func total() -> float:
	var sum := 0
	for b in _cells:
		sum += b
	return float(sum) / float(_cells.size() * 255)


## The most-converted voxel anywhere, 0..1. This is what the brief's control
## shot is actually a claim about: with no lamp ever cast, decay alone must
## leave the corridor photographable as an ordinary derelict hallway, so the
## peak of a freshly stamped building has to stay under DECAY_CEILING.
func peak() -> float:
	var top := 0
	for b in _cells:
		if b > top:
			top = b
	return float(top) / 255.0


# ── UPLOAD ────────────────────────────────────────────────────────────────

## One RG8 Image per Y layer. R is the original durable byte; G is the
## reversible irradiance response. The texture object and sampler are unchanged.
func to_images() -> Array[Image]:
	var out: Array[Image] = []
	var plane := GRID_XZ * GRID_XZ
	for iy in GRID_Y:
		var bytes := PackedByteArray()
		bytes.resize(plane * 2)
		var start := iy * plane
		for offset in plane:
			var i := start + offset
			bytes[offset * 2] = _cells[i]
			bytes[offset * 2 + 1] = clampi(int(round(
					_irradiance[i] * 255.0)), 0, 255)
		out.append(Image.create_from_data(GRID_XZ, GRID_XZ, false,
				Image.FORMAT_RG8, bytes))
	return out


func make_texture() -> ImageTexture3D:
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RG8, GRID_XZ, GRID_XZ, GRID_Y, false, to_images())
	return tex


## Push to the GPU, but only when the CPU copy actually moved. Returns
## whether it sent anything, so a caller can report how often it is paying.
func upload(tex: ImageTexture3D) -> bool:
	if tex == null or not _dirty:
		return false
	tex.update(to_images())
	_dirty = false
	return true


func is_dirty() -> bool:
	return _dirty


# ── INTERNAL ──────────────────────────────────────────────────────────────

## Every (wrapped x, wrapped z, unwrapped x, unwrapped z) the rect covers.
## The unwrapped pair is carried because the per-room blotch hash must be a
## function of the room's real position -- hashing the wrapped index would
## give two rooms 48 m apart the identical pattern, which is exactly the
## repetition the wrapping is otherwise invisible against.
##
## THE FOOTPRINT IS HALF-OPEN, and that is a correctness requirement rather
## than a rounding preference. Two rooms joined at a door are separated by one
## 0.20 m wall, so the far face of one and the near face of the next fall
## inside the same 0.5 m column. With an inclusive far edge every adjacent
## pair in the pocket claimed a shared column, and `_claim` -- correctly, by
## its own rule -- reported each one as an aliasing overflow. The first
## fractal run after wiring this up printed that warning for a parent and its
## own child, which are 0.2 m apart and not 48 m.
##
## Rounding the far edge UP and stepping back one keeps a room's columns
## strictly inside its own footprint: [0, 4] takes columns 0..7, the room
## starting at 4.2 takes 8 upward, and nothing is shared.
func _span(rect: Array) -> Array:
	var out: Array = []
	var x0 := int(floor(minf(float(rect[0]), float(rect[2])) / VOXEL_M))
	var x1 := maxi(x0,
			int(ceil(maxf(float(rect[0]), float(rect[2])) / VOXEL_M)) - 1)
	var z0 := int(floor(minf(float(rect[1]), float(rect[3])) / VOXEL_M))
	var z1 := maxi(z0,
			int(ceil(maxf(float(rect[1]), float(rect[3])) / VOXEL_M)) - 1)
	for gx in range(x0, x1 + 1):
		for gz in range(z0, z1 + 1):
			out.append([posmod(gx, GRID_XZ), posmod(gz, GRID_XZ), gx, gz])
	return out


## Record which room owns each column.
##
## THIS IS NOT THE OVERFLOW CHECK, and an earlier version's mistake in
## thinking it was is worth keeping written down. It flagged any column two
## rooms both touched, which sounds like the aliasing test and is not one: the
## wall between two joined rooms is 0.20 m and a column is 0.50 m, so a
## doorway joint that does not happen to land on the grid puts both rooms in
## the same column legitimately. The first fractal run reported a room
## aliasing its own child, 0.2 m away, and the warning said they were 48 m
## apart. Rounding the footprint half-open fixed only the case where the joint
## lands exactly on a voxel boundary, which is most of them and not all.
##
## What ownership is actually for is clearing: a room that leaves must not
## zero a column its live neighbour is still standing in.
func _claim(key: String, span: Array) -> void:
	for entry in span:
		_owner[int(entry[0]) * GRID_XZ + int(entry[1])] = key


## THE OVERFLOW CHECK, asking the question the warning actually claims.
##
## The field tiles every EXTENT_M, so the one thing that breaks it is a live
## pocket wider than a tile -- at which point two rooms genuinely occupy the
## same voxels and one is drawing the other's gold. That is a fact about the
## pocket's world-space bounding box, measured in metres, and nothing to do
## with which columns two rooms share at a doorway.
##
## Cheap enough to do on every stamp: the pocket is a trail of three plus one
## room's neighbours, so this loop is under a dozen rects.
func _note_extent() -> void:
	if _overflow or _rects.is_empty():
		return
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for k in _rects:
		var r: Array = _rects[k]
		min_x = minf(min_x, minf(float(r[0]), float(r[2])))
		max_x = maxf(max_x, maxf(float(r[0]), float(r[2])))
		min_z = minf(min_z, minf(float(r[1]), float(r[3])))
		max_z = maxf(max_z, maxf(float(r[1]), float(r[3])))
	var w := max_x - min_x
	var d := max_z - min_z
	if w < EXTENT_M and d < EXTENT_M:
		return
	_overflow = true
	push_warning(("dream exposure field: the live pocket is %.1f x %.1f m "
			+ "and the field tiles every %.0f m -- two live rooms are now "
			+ "sharing voxels and GRID_XZ must grow") % [w, d, EXTENT_M])
