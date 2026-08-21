extends Node
## THE CONVERSION STAYS. Eight things proved about DreamExposureField:
##
##   A. it only ever goes UP while a room is real -- the governing change of
##      DREAM_SURFACE_REDESIGN_BRIEF.md workstream A, and the one assertion
##      the whole redesign rests on
##   B. what the lamp buys is DWELL, not presence
##   C. decay seeds it, per room, and never finishes the job on its own
##   D. the building forgets a room it has dropped, and only that room
##   E. it tiles, and it says so when the pocket outgrows the tile
##   F. it is deterministic, because a field seeded from the atlas that
##      differed between two runs of one save would be a silent desync
##   G. the upload layout is the layout the sampler will read
##   H. reversible irradiance rises, cools and clears without mutating exposure
##
## Harness integrity follows the N7 idiom: exact check count, a counted
## sentinel, no timing dependence, and a nonzero exit on any failure. This one
## is pure data -- no scene, no renderer, no godot window -- so it runs
## headless in well under a second.

const EXPECTED_CHECKS := 35
## A room four metres square at the origin, in the [x0, z0, x1, z1] form
## DreamRoomBuilder writes into plan.modules.
const ROOM := [0.0, 0.0, 4.0, 4.0]
const REACH := 6.0
## Godot's spot angle is a half-angle; 40 degrees is DREAM_LAMP_ANGLE.
var COS_OUTER := cos(deg_to_rad(40.0))

var failures := 0
var checks := 0


func _ready() -> void:
	print("[EXPOSURE] START")
	_block_a_persistence()
	_block_b_dwell()
	_block_c_decay()
	_block_d_forgetting()
	_block_e_tiling()
	_block_f_determinism()
	_block_g_upload()
	_block_h_irradiance()
	if checks != EXPECTED_CHECKS:
		failures += 1
		printerr("[EXPOSURE] HARNESS FAIL: %d checks ran, %d expected"
				% [checks, EXPECTED_CHECKS])
	print("DREAM EXPOSURE TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[EXPOSURE] FAIL: %s" % what)


## A lamp standing at the west end of ROOM pointing east down it.
func _sweep(field: DreamExposureField, aim: Vector3, seconds: float,
		steps: int = 10) -> void:
	for i in steps:
		field.add_lamp(Vector3(0.5, 1.5, 2.0), aim, REACH, COS_OUTER, 1.0,
				seconds / float(steps))


# --- A: it only ever goes up -----------------------------------------

func _block_a_persistence() -> void:
	var f := DreamExposureField.new()
	# decay 0, so nothing is here but what the lamp puts here. That isolates
	# the accumulation from the baseline.
	f.stamp_room("@", ROOM, 0.0, 0.5)
	var lit := Vector3(3.0, 1.5, 2.0)
	_check(f.sample(lit) == 0.0, "a decay-free room starts unconverted")

	_sweep(f, Vector3(1, 0, 0), 1.0)
	var after_one := f.sample(lit)
	_check(after_one > 0.0, "the lamp writes into the field")

	_sweep(f, Vector3(1, 0, 0), 1.0)
	var after_two := f.sample(lit)
	_check(after_two >= after_one, "holding the beam never lowers exposure")

	# THE ASSERTION THE REDESIGN EXISTS FOR. Point the lamp the other way for
	# a long time and come back: the gold the player already uncovered must
	# still be uncovered. Before this class, `heat` was recomputed from the
	# cone every frame and this value would have returned to zero.
	_sweep(f, Vector3(-1, 0, 0), 4.0, 40)
	_check(f.sample(lit) == after_two,
			"exposure PERSISTS after the beam has moved away")

	# And the field as a whole grew, rather than one voxel being shuffled.
	_check(f.total() > 0.0, "the field accumulates in aggregate")


# --- B: dwell, not presence ------------------------------------------

func _block_b_dwell() -> void:
	var brief := DreamExposureField.new()
	brief.stamp_room("@", ROOM, 0.0, 0.5)
	_sweep(brief, Vector3(1, 0, 0), 1.0)

	var held := DreamExposureField.new()
	held.stamp_room("@", ROOM, 0.0, 0.5)
	_sweep(held, Vector3(1, 0, 0), 2.0, 20)

	var at := Vector3(3.0, 1.5, 2.0)
	_check(held.sample(at) > brief.sample(at),
			"two seconds of beam converts more than one")

	# The rim creeps and the centre takes: a point off the axis of the same
	# cone must be less converted than one on it. This is what stops the
	# field growing a hard-edged ellipse for the shader's warp to fail to
	# hide -- the brief's complaint that the frontier is "a cone falloff".
	var axis := held.sample(Vector3(3.0, 1.5, 2.0))
	var rim := held.sample(Vector3(3.0, 1.5, 3.6))
	_check(rim < axis, "the cone rim converts more slowly than its axis")

	# Nothing outside the beam's reach is touched at all.
	_check(held.sample(Vector3(0.5, 1.5, 22.0)) == 0.0,
			"beyond reach is untouched")


# --- C: decay seeds it -----------------------------------------------

func _block_c_decay() -> void:
	var none := DreamExposureField.new()
	none.stamp_room("@", ROOM, 0.0, 0.5)
	_check(none.total() == 0.0, "decay 0 stamps nothing")

	var gone := DreamExposureField.new()
	gone.stamp_room("@", ROOM, 1.0, 0.5)
	_check(gone.total() > 0.0, "a forgotten room starts part-turned")

	var half := DreamExposureField.new()
	half.stamp_room("@", ROOM, 0.4, 0.5)
	_check(gone.total() > half.total(),
			"more decay stamps more conversion")

	# Per room, so no two rooms grow alike. Same decay, different aspect().
	var other := DreamExposureField.new()
	other.stamp_room("@", ROOM, 1.0, 0.9)
	var differs := false
	for x in range(0, 8):
		for z in range(0, 8):
			var at := Vector3(float(x) * 0.5, 1.5, float(z) * 0.5)
			if gone.sample(at) != other.sample(at):
				differs = true
	_check(differs, "two rooms with one decay grow different patterns")

	# THE CONTROL SHOT. "The same corridor, unlit, must be photographable as
	# an ordinary derelict apartment hallway with nothing wrong with it."
	# Decay may make a room look further gone; it must never finish it.
	_check(gone.peak() <= DreamExposureField.DECAY_CEILING + 0.001,
			"decay alone never converts a surface outright")


# --- D: the building forgets -----------------------------------------

func _block_d_forgetting() -> void:
	var f := DreamExposureField.new()
	f.stamp_room("@a", ROOM, 1.0, 0.5)
	f.stamp_room("@b", [6.0, 0.0, 10.0, 4.0], 1.0, 0.7)
	_check(f.stamped_rooms() == 2, "two rooms stamped")
	var kept := f.room_exposure("@b")

	f.clear_room("@a")
	_check(f.room_exposure("@a") == 0.0, "a forgotten room is zeroed")
	_check(f.room_exposure("@b") == kept,
			"forgetting one room leaves its neighbour alone")

	# And the space is handed back clean, which is what makes the tiling safe.
	f.stamp_room("@a", ROOM, 1.0, 0.5)
	_check(f.stamped_rooms() == 2, "the space can be re-stamped after")


# --- E: it tiles, and says when the tile is too small -----------------

func _block_e_tiling() -> void:
	var f := DreamExposureField.new()
	f.stamp_room("@", ROOM, 1.0, 0.5)
	var here := Vector3(2.0, 1.5, 2.0)
	var away := here + Vector3(DreamExposureField.EXTENT_M, 0.0, 0.0)
	_check(f.sample(here) == f.sample(away),
			"a point and the point one tile away address one voxel")

	# Negative coordinates are half of every passage, and GDScript's % keeps
	# the sign -- which would mirror the field across the origin. posmod does
	# not, and this is the assertion that says so.
	var mirrored := here - Vector3(DreamExposureField.EXTENT_M, 0.0, 0.0)
	_check(f.sample(mirrored) == f.sample(here),
			"the tile wraps into negative world space correctly")

	_check(not f.overflowed(), "an ordinary pocket does not alias")

	# AND NEITHER DO NEIGHBOURS. Two rooms joined at a door are separated by
	# one 0.20 m wall, so the far face of one and the near face of the next
	# fall inside the same half-metre column. An inclusive footprint made
	# every adjacent pair in the pocket report as an overflow, and the first
	# real fractal run after this class was wired in said exactly that about a
	# room and its own child.
	var joined := DreamExposureField.new()
	joined.stamp_room("@a", [0.0, 0.0, 4.0, 4.0], 1.0, 0.5)
	joined.stamp_room("@b", [4.2, 0.0, 8.2, 4.0], 1.0, 0.6)
	_check(not joined.overflowed(),
			"rooms joined at a door do not read as aliasing")

	# Two SIMULTANEOUSLY live rooms one tile apart is the one thing tiling
	# cannot survive, and it must be reported rather than rendered as a
	# mystery.
	var over := DreamExposureField.new()
	over.stamp_room("@a", ROOM, 1.0, 0.5)
	over.stamp_room("@b", [DreamExposureField.EXTENT_M,
			0.0, DreamExposureField.EXTENT_M + 4.0, 4.0], 1.0, 0.5)
	_check(over.overflowed(), "a pocket wider than the tile is reported")


# --- F: deterministic ------------------------------------------------

func _block_f_determinism() -> void:
	var a := DreamExposureField.new()
	var b := DreamExposureField.new()
	for f in [a, b]:
		f.stamp_room("@", ROOM, 0.62, 0.31)
		_sweep(f, Vector3(1, 0, 0), 1.5, 15)
	_check(a.total() == b.total(),
			"the same seed and the same beam give the same field")
	var same := true
	for x in range(0, 8):
		for z in range(0, 8):
			var at := Vector3(float(x) * 0.5, 1.5, float(z) * 0.5)
			if a.sample(at) != b.sample(at):
				same = false
	_check(same, "and the same field voxel for voxel")


# --- G: the upload layout --------------------------------------------

func _block_g_upload() -> void:
	var f := DreamExposureField.new()
	f.stamp_room("@", ROOM, 1.0, 0.5)
	_sweep(f, Vector3(1, 0, 0), 1.0)
	var images := f.to_images()
	_check(images.size() == DreamExposureField.GRID_Y,
			"one image per Y layer")
	_check(images[0].get_width() == DreamExposureField.GRID_XZ
			and images[0].get_height() == DreamExposureField.GRID_XZ,
			"each layer is the full XZ grid")
	_check(images[0].get_format() == Image.FORMAT_RG8,
			"the existing texture carries durable R plus reversible G")

	# The layer a world height falls into must hold the value sample() reads
	# there, or the sampler will read a different building than the pursuer.
	var at := Vector3(3.0, 1.5, 2.0)
	var iy := int(floor(1.5 / DreamExposureField.VOXEL_M))
	var ix := int(floor(3.0 / DreamExposureField.VOXEL_M))
	var iz := int(floor(2.0 / DreamExposureField.VOXEL_M))
	var texel := images[iy].get_pixel(ix, iz).r
	_check(absf(texel - f.sample(at)) < 0.005,
			"the image layer agrees with sample() at the same point")
	var irradiance_texel := images[iy].get_pixel(ix, iz).g
	_check(absf(irradiance_texel - f.sample_irradiance(at)) < 0.005,
			"the image G channel agrees with reversible irradiance")


# --- H: reversible, bounded irradiance --------------------------------

func _block_h_irradiance() -> void:
	var f := DreamExposureField.new()
	f.stamp_room("@", ROOM, 0.0, 0.5)
	var lit := Vector3(3.0, 1.5, 2.0)
	_check(f.sample_irradiance(lit) == 0.0,
			"irradiance starts dark without changing durable exposure")
	_sweep(f, Vector3(1, 0, 0), 1.0, 15)
	var warm := f.sample_irradiance(lit)
	var durable := f.sample(lit)
	_check(warm > 0.0 and warm <= DreamExposureField.IRRADIANCE_RISE_PER_S + 0.001,
			"direct response rises but cannot exceed its per-second ceiling")
	_sweep(f, Vector3(-1, 0, 0), 0.5, 8)
	var cooled := f.sample_irradiance(lit)
	_check(cooled < warm and cooled >= warm
			- DreamExposureField.IRRADIANCE_FALL_PER_S * 0.5 - 0.001,
			"leaving the cone cools no faster than the ruled fall rate")
	_check(f.sample(lit) == durable,
			"cooling reversible G never lowers durable R")
	f.clear_room("@")
	_check(f.sample_irradiance(lit) == 0.0,
			"forgetting a room clears its reversible presentation channel")
	var a := DreamExposureField.new()
	var b := DreamExposureField.new()
	for field in [a, b]:
		field.stamp_room("@", ROOM, 0.0, 0.5)
		_sweep(field, Vector3(1, 0, 0), 1.2, 18)
	_check(a.sample_irradiance(lit) == b.sample_irradiance(lit),
			"the same beam trace gives the same reversible response")
