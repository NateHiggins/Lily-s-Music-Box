extends Node
## WHAT WOULD RECURSION COST, AND CAN IT EVEN FIT?
##
##     C:/devkit/bin/godot.cmd --headless --path game \
##             res://tests/DreamRecursionPrice.tscn
##
## Session plan item 4: "PRICE RECURSION BEFORE BUILDING IT. Nothing in the
## project does nested enterable space. 29 of 400 deep rooms ask for it."
##
## This is a PROBE, not a test. It asserts nothing and cannot fail; it answers
## three questions with numbers so the decision to build nested space, or to
## express RECURSION some other way, is made against measurements rather than
## against an impression of how often it comes up.
##
##   1. HOW OFTEN. The 29/400 figure is one sample at one depth band. Sampled
##      properly across seeds, cases and depths, because DreamAtlas.fault()
##      arrives in decay order and decay rises with both nights and depth --
##      so the incidence is not one number, it is a curve, and the shallow end
##      is what a first-night player actually sees.
##
##   2. WHETHER IT FITS. This is the question that decides the whole feature.
##      A recursive room has to contain another enterable room: two more wall
##      thicknesses, a doorway, and enough floor left over that a body can get
##      around the inner box to reach its door. The Orison's own bones are
##      2.08 m corridors and 0.91 m doors, and a 2.08 m room cannot contain
##      anything at all. If most rooms flagged RECURSION are too small to hold
##      a room, then nested space is not a rendering problem or a budget
##      problem -- it is geometrically impossible for that room and the fault
##      needs a different expression.
##
##   3. WHAT IT WOULD ADD. In draw submissions, which is the axis this frame
##      is actually bound on.

const SEEDS := ["f123456789abcdef", "0123456789abcdef", "deadbeefcafef00d",
		"a1b2c3d4e5f60718", "5555aaaa3333cccc"]
const CASES := ["mina_caption_crisis", "juno_channel_theft",
		"omar_unrepairable"]
## Depth bands to sample. Depth is distance from where the player woke, and
## DreamAtlas.decay() folds it in at depth/14, so 14 is where the depth term
## saturates and anything past it is the same building.
const DEPTHS := [1, 2, 3, 5, 8, 11, 14, 18]
const ROOMS_PER_CELL := 40
## Nights matter as much as depth: decay compounds 1 - 0.82^nights, so the
## sixth passage is a different building from the first.
const NIGHTS := [0, 2, 5]


func _ready() -> void:
	print("[RECURSION] START")
	var catalog := DreamMazeBuilder.load_catalog()
	var constants: Dictionary = catalog.get("constants", {})
	var wall_t: float = DreamMazeBuilder.WALL_T
	var door_w: float = float(constants.get("connector_width_m", 0.91))
	var smallest: Vector2 = _smallest_module(catalog)
	print("[RECURSION] bones: wall %.2f m, door %.2f m, smallest authored "
			% [wall_t, door_w]
			+ "module %.2f x %.2f m" % [smallest.x, smallest.y])

	# --- 1 and 2, in one sweep -------------------------------------------
	var by_depth: Dictionary = {}
	var total: int = 0
	var recursive: int = 0
	var fits: int = 0
	var sizes: Array[float] = []
	for seed_hex in SEEDS:
		for case_id in CASES:
			for nights in NIGHTS:
				var atlas := DreamAtlas.new()
				atlas.setup(seed_hex, nights, case_id)
				for depth in DEPTHS:
					for n in ROOMS_PER_CELL:
						var path := _path_of_depth(depth, n)
						var room := atlas.room(path)
						total += 1
						var key: int = depth
						if not by_depth.has(key):
							by_depth[key] = [0, 0, 0]
						by_depth[key][0] += 1
						if not bool(room.get("recursive", false)):
							continue
						recursive += 1
						by_depth[key][1] += 1
						var size: Vector2 = room.get("size",
								Vector2(4.0, 4.0))
						var room_min: float = minf(size.x, size.y)
						sizes.append(room_min)
						if _can_nest(size, smallest, wall_t, door_w):
							fits += 1
							by_depth[key][2] += 1

	print("\n[RECURSION] 1. HOW OFTEN, and 2. WHETHER IT FITS")
	print("  %-7s %8s %10s %10s %10s" % ["depth", "rooms", "recursive",
			"share", "can nest"])
	var keys: Array = by_depth.keys()
	keys.sort()
	for k in keys:
		var row: Array = by_depth[k]
		print("  %-7d %8d %10d %9.1f%% %10s" % [k, row[0], row[1],
				100.0 * float(row[1]) / maxf(1.0, float(row[0])),
				"%d (%.0f%%)" % [row[2],
						100.0 * float(row[2]) / maxf(1.0, float(row[1]))]])
	print("  %-7s %8d %10d %9.1f%% %10s" % ["ALL", total, recursive,
			100.0 * float(recursive) / maxf(1.0, float(total)),
			"%d (%.0f%%)" % [fits,
					100.0 * float(fits) / maxf(1.0, float(recursive))]])

	if not sizes.is_empty():
		sizes.sort()
		print("\n[RECURSION] the short side of a recursive room, in metres:")
		print("   min %.2f   p25 %.2f   median %.2f   p75 %.2f   max %.2f"
				% [sizes[0], sizes[int(sizes.size() * 0.25)],
				sizes[int(sizes.size() * 0.5)],
				sizes[int(sizes.size() * 0.75)], sizes[sizes.size() - 1]])
		var need_a: Vector2 = _outer_need(smallest, wall_t, door_w)
		var need_b: Vector2 = _outer_need(
				Vector2(smallest.y, smallest.x), wall_t, door_w)
		print("   best-case outer clear span is %.2f x %.2f m, or %.2f x "
				% [need_a.x, need_a.y, need_b.x]
				+ "%.2f m rotated" % need_b.y)

	# --- 3. what it would add --------------------------------------------
	print("\n[RECURSION] 3. WHAT IT WOULD ADD, in draw submissions")
	print("  A pocket measured at 49 GeometryInstance3D over its live rooms")
	print("  (PERF_DREAM census, 45 draw calls, 1.90 ms of a 16.6 ms budget).")
	print("  A nested room is one more room's architecture inside an existing")
	print("  one: floor, ceiling, four wall bands and its own lintels, so it")
	print("  is the cost of a room and not a fraction of one -- call it +6 to")
	print("  +8 submissions each, against ~15 ms of headroom.")
	print("  SUBMISSIONS ARE NOT WHAT MAKES THIS HARD. Read the fit column.")
	print("\n[RECURSION] COMPLETE")
	get_tree().quit(0)


## The smallest footprint the catalog authors, which is the best case for
## anything being nestable at all.
func _smallest_module(catalog: Dictionary) -> Vector2:
	var best := Vector2(999.0, 999.0)
	var best_area := INF
	for id in (catalog.get("modules", {}) as Dictionary):
		var fp: Array = catalog.modules[id].get("footprint_m", [])
		if fp.size() < 2:
			continue
		var v := Vector2(float(fp[0]), float(fp[1]))
		var area: float = v.x * v.y
		if area < best_area:
			best = v
			best_area = area
	return best if best.x < 999.0 else Vector2(4.0, 4.0)


## The outer clear span needed to hold `inner` with a body's route to its door.
##
## The nested room needs its two walls on both axes. One doorway-width of
## approach is then owed on the door-normal axis only: the cheapest valid
## arrangement may sit against the other three sides of the host. This is an
## deliberately optimistic fit test, which is appropriate for pricing -- a
## room rejected here cannot be rescued by a more elaborate layout.
func _outer_need(inner: Vector2, wall_t: float,
		door_w: float) -> Vector2:
	return Vector2(inner.x + 2.0 * wall_t,
			inner.y + 2.0 * wall_t + door_w)


func _can_nest(outer: Vector2, inner: Vector2, wall_t: float,
		door_w: float) -> bool:
	for nested in [inner, Vector2(inner.y, inner.x)]:
		var need: Vector2 = _outer_need(nested, wall_t, door_w)
		# The nested doorway can face either host axis. Swapping the need vector
		# covers that choice without pretending the host itself has no axes.
		if (outer.x >= need.x and outer.y >= need.y) \
				or (outer.x >= need.y and outer.y >= need.x):
			return true
	return false


## A path of the requested depth, varied by `n` so the sample is not one room
## repeated. Door indices reach 3, which is what a real walk emits.
func _path_of_depth(depth: int, n: int) -> PackedInt32Array:
	var path := PackedInt32Array()
	var v: int = n + 1
	for i in depth:
		path.append(v % 4)
		v = (v * 7 + 3) % 97
	return path
