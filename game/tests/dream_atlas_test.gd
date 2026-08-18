extends Node
## The fractal Orison, held to the three things it actually claims.
##
##     godot --headless --path game res://tests/DreamAtlasTest.tscn
##
## Exit code is the failure count.
##
## These are not "does it run" checks. Each one is a property the design would
## be a lie without:
##
##   A. THE SAME WALK ARRIVES AT THE SAME ROOM, forever and on any machine.
##      Without this the building is not persistent, it is merely random, and
##      the player can never learn it.
##   B. THE BUILDING DOES NOT CLOSE. Walking a loop must NOT return you to
##      where you started. This is the one property most likely to be
##      "accidentally fixed" by a future refactor that adds global placement,
##      and it would take the whole thesis with it.
##   C. FORGETTING IS A PROGRESSION, NOT NOISE. Faults must arrive in decay
##      order, and the building must be measurably worse after more nights.
##      A generator that sprays faults at random is procedural soup wearing
##      the vocabulary of memory.

const SEED_HEX := "f123456789abcdef"
const OTHER_SEED := "0123456789abcdef"

## Pinned 2026-08-17 from the committed generator. See _block_e_golden.
const GOLDEN_MIX := 5200473954009329611
const GOLDEN_ROOT := 5556579809797176643
const GOLDEN_WALK := 2605370776228155153

var failures := 0
var checks := 0


func _ready() -> void:
	print("[ATLAS] START")
	_block_a_identity()
	_block_b_no_closure()
	_block_c_forgetting()
	_block_d_spawn()
	_block_e_golden()
	print("[ATLAS] CHECKS: %d/%d fails=%d" % [checks - failures, checks, failures])
	print("DREAM ATLAS TEST: %s" % ["PASS" if failures == 0 else "FAIL"])
	get_tree().quit(failures)


# --- A: the same walk arrives at the same room ------------------------

func _block_a_identity() -> void:
	var a := DreamAtlas.new()
	a.setup(SEED_HEX, 3)
	var b := DreamAtlas.new()
	b.setup(SEED_HEX, 3)
	var path := PackedInt32Array([1, 0, 2, 2, 1])
	_check("the same walk names the same room, from a separate atlas",
			a.room_id(path) == b.room_id(path))
	_check("and describes it identically",
			str(a.room(path)) == str(b.room(path)))

	# Different seeds must be different buildings, or every campaign is one
	# campaign.
	var other := DreamAtlas.new()
	other.setup(OTHER_SEED, 3)
	_check("a different campaign seed is a different building",
			a.room_id(path) != other.room_id(path))

	# Order matters: left-then-right is not right-then-left. If it were, the
	# building would be a set of rooms rather than a place with directions.
	_check("the ORDER of the walk matters, not just the doors taken",
			a.room_id(PackedInt32Array([0, 1])) \
					!= a.room_id(PackedInt32Array([1, 0])))

	# A thousand distinct short walks should give a thousand distinct rooms.
	# Collisions here would silently weld unrelated parts of the building
	# together.
	var seen := {}
	var collisions := 0
	for i in 1000:
		var p := PackedInt32Array([i % 4, (i / 4) % 4, (i / 16) % 4,
				(i / 64) % 4, (i / 256) % 4])
		var id := a.room_id(p)
		if seen.has(id):
			collisions += 1
		seen[id] = true
	_check("1000 distinct walks give 1000 distinct rooms (%d collisions)"
			% collisions, collisions == 0)


# --- B: the building does not close -----------------------------------

func _block_b_no_closure() -> void:
	var a := DreamAtlas.new()
	a.setup(SEED_HEX, 3)
	# Out and back by the same door index is NOT a return trip. In a real
	# building it would be; in a remembered one there is no "back", only
	# another door that resembles the one you came through.
	var start := PackedInt32Array([2, 1])
	var out := DreamAtlas.step(start, 0)
	var back := DreamAtlas.step(out, 0)
	_check("leaving and 'returning' does not arrive where you started",
			a.room_id(back) != a.room_id(start))
	# A four-door loop does not close either.
	var loop := PackedInt32Array([])
	for d in [0, 1, 2, 3]:
		loop = DreamAtlas.step(loop, d)
	_check("a four-door loop does not close",
			a.room_id(loop) != a.room_id(PackedInt32Array([])))
	# But the path to a room is still stable -- non-closure must not mean
	# non-determinism, which is the failure mode this design is one bug away
	# from at all times.
	_check("non-closure has not cost determinism",
			a.room_id(back) == a.room_id(back.duplicate()))


# --- C: forgetting is a progression -----------------------------------

func _block_c_forgetting() -> void:
	var early := DreamAtlas.new()
	early.setup(SEED_HEX, 0)
	var late := DreamAtlas.new()
	late.setup(SEED_HEX, 20)

	# The same room, more nights in: worse. Averaged over many rooms because
	# any single room is allowed its own character.
	var early_sum := 0.0
	var late_sum := 0.0
	for i in 400:
		var p := PackedInt32Array([i % 4, (i / 4) % 4, (i / 16) % 4])
		var id := early.room_id(p)
		early_sum += early.decay(id, p.size())
		late_sum += late.decay(id, p.size())
	_check("the building is measurably more forgotten after 20 nights "
			+ "(%.3f -> %.3f)" % [early_sum / 400.0, late_sum / 400.0],
			late_sum > early_sum * 1.15)

	# Depth degrades too: the far reaches are less rehearsed.
	var near_sum := 0.0
	var far_sum := 0.0
	for i in 300:
		var id := late.room_id(PackedInt32Array([i % 4, (i / 4) % 4]))
		near_sum += late.decay(id, 1)
		far_sum += late.decay(id, 13)
	_check("rooms far from where you woke are worse remembered",
			far_sum > near_sum)

	# FAULTS MUST BE ORDERED. A room with low decay may not be BLANKING, and a
	# thoroughly forgotten one may not be pristine. This is what separates a
	# memory model from a noise field.
	var out_of_order := 0
	var histogram := {}
	for i in 2000:
		var p := PackedInt32Array([i % 4, (i / 4) % 4, (i / 16) % 4,
				(i / 64) % 4])
		var id := late.room_id(p)
		var d := late.decay(id, p.size())
		var f := late.fault(id, p.size())
		histogram[f] = int(histogram.get(f, 0)) + 1
		if d < 0.18 and f != DreamAtlas.Fault.NONE:
			out_of_order += 1
		if d >= 0.90 and f != DreamAtlas.Fault.BLANKING:
			out_of_order += 1
	_check("faults arrive in decay order, never out of it (%d violations)"
			% out_of_order, out_of_order == 0)

	# And the vocabulary must actually be USED. A model that only ever emits
	# two of its six faults is two faults wearing six names.
	var kinds := 0
	for f in histogram:
		if int(histogram[f]) > 0:
			kinds += 1
	var rows: Array = []
	for f in histogram:
		rows.append("%s=%d" % [DreamAtlas.fault_name(f), int(histogram[f])])
	rows.sort()
	print("   fault census over 2000 rooms: %s" % ", ".join(rows))
	_check("at least four distinct fault kinds actually occur (%d)" % kinds,
			kinds >= 4)


# --- D: you wake somewhere else every night ---------------------------

func _block_d_spawn() -> void:
	var a := DreamAtlas.new()
	a.setup(SEED_HEX, 5)
	var first := a.spawn_path(1)
	_check("a reload puts you back where you woke",
			a.room_id(first) == a.room_id(a.spawn_path(1)))
	var distinct := {}
	for night in range(1, 41):
		distinct[a.room_id(a.spawn_path(night))] = true
	_check("forty nights wake you in forty different places (%d)"
			% distinct.size(), distinct.size() >= 38)
	_check("and never at the same root, because there is no entrance",
			a.spawn_path(1).size() >= 3)


# --- E: the golden vectors --------------------------------------------
#
# THE ROOM NAMES ARE A PUBLIC FACT AND MUST NEVER MOVE.
#
# Every room in every campaign is named by `mix64` and a handful of salts.
# Changing any of them -- even "tidying" a constant -- silently renames the
# entire building for every existing save: the player's learned geography
# becomes someone else's. There is no error and no crash; the world is just
# quietly replaced.
#
# So the exact values are pinned here. If this block fails, the question is
# never "what should the new number be" -- it is "what did I change, and put
# it back".
func _block_e_golden() -> void:
	var a := DreamAtlas.new()
	a.setup(SEED_HEX, 0)
	_check("mix64 is exactly what it was (%d)" % DreamAtlas.mix64(1, 2),
			DreamAtlas.mix64(1, 2) == GOLDEN_MIX)
	var root := a.room_id(PackedInt32Array([]))
	_check("the root room of the canonical seed is unchanged (%d)" % root,
			root == GOLDEN_ROOT)
	var walk := a.room_id(PackedInt32Array([1, 0, 2]))
	_check("and the room three doors in is unchanged (%d)" % walk,
			walk == GOLDEN_WALK)
	# Door indices must be reachable: a spawn path that names a door the room
	# does not have is a room the walk cannot reproduce.
	var bad := 0
	for night in range(1, 60):
		var p := a.spawn_path(night)
		var partial := PackedInt32Array()
		for step in p:
			var here := a.room(partial)
			if step >= int(here.doors):
				bad += 1
			partial.append(step)
	_check("every spawn path uses doors that exist (%d violations)" % bad,
			bad == 0)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
