class_name WallArtLaw
extends RefCounted
## One law for every picture hook in the building. Art hangs on a REAL
## wall (nested room rects have ghost edges where a bathroom was carved
## out — nothing hangs on those), never across a doorway or window, and
## never through the wainscot rail on walls that carry one. Every placer
## — hallway art, character art, found art, story decals — asks here, so
## a piece with nowhere legal is not hung instead of hung wrong.
##
## History note: the original in-building_root legality pass read wall
## cuts from a key named "cuts"; the generator writes "openings". The
## opening check therefore never fired, which is how frames ended up
## bridging doorways. This version reads the key that exists.

# The rail cap, read off the thing that builds it rather than guessed.
# build_orison.py tops the dado at 1.32 (:2902), caps it to 1.36 (:2946) and
# rides a bullnose bead at dado_top + 0.035 (:2958), so 1.355 is the highest
# millwork a piece has to clear. The old 1.56 was 0.20 m of invented height,
# and it is why hall pieces ended up flush against ceiling trim and clipped
# into the elevator door surround -- the law was pushing them there.
const RAIL_TOP := 1.355
## The character-art quad is 0.72 m square, so its half-height is 0.36. The
## old 0.34 was described as "conservative" but is the opposite: understating
## the piece makes every clearance test pass more easily.
const ART_HALF_H := 0.36
const ART_HALF_W := 0.38
const VISUAL_GAP := 0.18
## How far a hook stands off the plaster. It has to exceed the trim: window
## and door casings stand 0.020 proud of the face (build_orison :3049) and the
## dado cap and its bead stand further still.
const STANDOFF := 0.055

# A hook is not legal merely because the wall exists. The whole building is
# assembled in one pass, so remember occupied wall bands as each character
# hangs their work. This also keeps the later found-art pass from silently
# laying a second frame over a resident's chosen piece.
static var _reserved: Dictionary = {}
static var _surface_reserved: Dictionary = {}


static func clear_reservations() -> void:
	_reserved.clear()
	_surface_reserved.clear()


static func legal_spot(floor_data: Dictionary, room: Dictionary,
		want_wall: String, want_along: float, height: float,
		visual_blocker := Callable(), half_width := ART_HALF_W,
		half_height := ART_HALF_H) -> Dictionary:
	var rect: Array = room.rect
	var walls_order: Array = [want_wall]
	for w in ["north", "south", "east", "west"]:
		if w != want_wall:
			walls_order.append(w)
	var alongs: Array = [want_along, 0.3, 0.5, 0.7, 0.25, 0.75, 0.4,
			0.6, 0.2, 0.8]
	# Walls with a rail push low pieces up above the cap, once, before
	# the search — a piece authored at rail height is a request, not a fact.
	var hang_height := maxf(height, RAIL_TOP + half_height + 0.06) \
			if _room_has_rail(room) else height
	for wall in walls_order:
		var want_horizontal: bool = wall in ["north", "south"]
		for along in alongs:
			var x := lerpf(float(rect[0]), float(rect[2]), float(along))
			var y := lerpf(float(rect[1]), float(rect[3]), float(along))
			var yaw := 0.0
			var bx := x     # probe just beyond the rect edge: the wall
			var by := y
			match wall:
				"north":
					y = float(rect[3]) - 0.105
					by = float(rect[3]) + 0.08
				"south":
					y = float(rect[1]) + 0.105
					by = float(rect[1]) - 0.08
					yaw = PI
				"east":
					x = float(rect[2]) - 0.105
					bx = float(rect[2]) + 0.08
					yaw = -PI * 0.5
				"west":
					x = float(rect[0]) + 0.105
					bx = float(rect[0]) - 0.08
					yaw = PI * 0.5
			# WHICH wall, not merely whether one exists. The 0.105 above is a
			# guess measured from a room rect, and a room rect edge is not one
			# thing: STACK_RECTS are interior faces while partition rects sit
			# on centrelines, so a single inset lands proud on one wall and
			# inside the brick on the next. Once the backing wall is known,
			# its own thickness gives the face and the guess is discarded.
			var backing := backing_wall(floor_data, bx, by, hang_height,
					half_height, half_width, want_horizontal)
			if backing.is_empty():
				continue
			var seated := _seat(backing, rect, x, y, want_horizontal)
			x = seated.x
			y = seated.y
			if nested_room_blocks(floor_data, room, x, y):
				continue
			if furniture_blocks(floor_data, x, y, hang_height,
					half_width, half_height):
				continue
			if visual_blocker.is_valid() and bool(visual_blocker.call(
					x, y, yaw, hang_height)):
				continue
			if _reserved_blocks(room, wall, x, y, hang_height,
					half_width, half_height):
				continue
			_reserve(room, wall, x, y, hang_height,
					half_width, half_height)
			return {"ok": true, "x": x, "y": y, "yaw": yaw, "wall": wall,
					"height": hang_height}
	return {"ok": false}


## Move a hook from its guessed position onto the real plaster face of the
## wall that backs it, standing STANDOFF clear on the room's side.
static func _seat(wall: Dictionary, rect: Array, x: float, y: float,
		horizontal: bool) -> Vector2:
	var t := float(wall.get("t", 0.12))
	var cl := float(wall["a"][1]) if horizontal else float(wall["a"][0])
	var room_c := (float(rect[1]) + float(rect[3])) * 0.5 if horizontal \
			else (float(rect[0]) + float(rect[2])) * 0.5
	var inward := 1.0 if room_c > cl else -1.0
	var seat := cl + inward * (t * 0.5 + STANDOFF)
	return Vector2(x, seat) if horizontal else Vector2(seat, y)



## Is (x, y) really inside `room`, or inside something carved out of it?
##
## A unit's MAIN rect is NESTED: the bathroom is cut out of the living room
## but the living rect is never subtracted, and ceiling_pass in the generator
## documents exactly this and handles it by subtraction. Any placer that
## measures "0.105 inside my east wall" off the raw living rect lands inside
## the bathroom wherever the two share that edge -- which on the A/B stacks is
## the east edge and on C/D the west, at X_IN = +/-5.51 / +/-7.71.
##
## This has been fixed twice as a one-unit special case and never generalised,
## so it is a shared helper now. Smallest containing rect wins: if that is not
## the room we were placing for, the spot belongs to the neighbour.
static func nested_room_blocks(floor_data: Dictionary, room: Dictionary,
		x: float, y: float) -> bool:
	var want := str(room.get("id", ""))
	var best := ""
	var best_area := INF
	for r in floor_data.get("rooms", []):
		var q: Array = r.get("rect", [])
		if q.size() < 4:
			continue
		if x < float(q[0]) or x > float(q[2]) 				or y < float(q[1]) or y > float(q[3]):
			continue
		var area := (float(q[2]) - float(q[0])) * (float(q[3]) - float(q[1]))
		if area < best_area:
			best_area = area
			best = str(r.get("id", ""))
	return best != "" and best != want

static func furniture_blocks(floor_data: Dictionary, px: float,
		py: float, height: float, half_width := ART_HALF_W,
		half_height := ART_HALF_H) -> bool:
	for fu in floor_data.get("furniture", []):
		var z0 := float(fu.get("z0", 0.0))
		var z1 := z0 + float(fu.get("h", 0.0))
		if fu.has("rect"):
			var r: Array = fu["rect"]
			# Test the frame footprint, not just its centre hook. This was the
			# source of pictures half swallowed by shelves and upper cabinets.
			if height + half_height >= z0 and height - half_height <= z1 \
					and px >= float(r[0]) - half_width - 0.08 \
					and px <= float(r[2]) + half_width + 0.08 \
					and py >= float(r[1]) - half_width - 0.08 \
					and py <= float(r[3]) + half_width + 0.08:
				return true
		# Exposed risers, radiator pipes, and conduit use p0/p1 instead of a
		# rect. A framed picture pierced by one reads as a placement bug.
		if fu.has("p0") and fu.has("p1"):
			var p0: Array = fu.p0
			var p1: Array = fu.p1
			var floor_z := float(floor_data.get("z", 0.0))
			var low := minf(float(p0[2]), float(p1[2])) - floor_z
			var high := maxf(float(p0[2]), float(p1[2])) - floor_z
			var radius := float(fu.get("r", 0.06)) + half_width + 0.08
			if height + half_height >= low and height - half_height <= high \
					and Vector2(px, py).distance_to(Vector2(
						float(p0[0]), float(p0[1]))) <= radius:
				return true
		# Assemblies carry `at`/`W`/`D`/`H` and no rect, and this test used to
		# skip them entirely -- 702 of the building's 6766 furniture records,
		# one in ten, invisible to the only collision check art gets. Crates,
		# racks and cabinets were all free to swallow a frame.
		if fu.has("asm") and fu.has("at") and not fu.has("rect"):
			var at: Array = fu["at"]
			var az1 := z0 + float(fu.get("H", fu.get("h", 0.0)))
			var ahw := float(fu.get("W", 0.3)) * 0.5 + half_width
			var ahd := float(fu.get("D", 0.3)) * 0.5 + half_width
			if height + half_height >= z0 and height - half_height <= az1 \
					and absf(px - float(at[0])) <= ahw \
					and absf(py - float(at[1])) <= ahd:
				return true
	return false


static func _reservation_key(room: Dictionary, wall: String) -> String:
	return "%s:%s" % [str(room.get("id", "?")), wall]


static func _reserved_blocks(room: Dictionary, wall: String, x: float,
		y: float, height: float, half_width: float,
		half_height: float) -> bool:
	for hook in _reserved.get(_reservation_key(room, wall), []):
		if Vector2(x, y).distance_to(Vector2(hook.x, hook.y)) \
				< half_width + float(hook.get("half_width", ART_HALF_W)) \
						+ VISUAL_GAP \
				and absf(height - float(hook.height)) \
				< half_height + float(hook.get("half_height", ART_HALF_H)) \
						+ VISUAL_GAP:
			return true
	return false


static func _reserve(room: Dictionary, wall: String, x: float, y: float,
		height: float, half_width: float, half_height: float) -> void:
	var key := _reservation_key(room, wall)
	if not _reserved.has(key):
		_reserved[key] = []
	_reserved[key].append({"x": x, "y": y, "height": height,
			"half_width": half_width, "half_height": half_height})


## Table clocks and tabletop photographs compete for the same finite surface
## exactly as two frames compete for one hook.  Keep that reservation in the
## same law so a later art pass cannot place a portrait through Noel's mantel
## clock merely because neither object is on a wall.
static func reserve_surface(room: Dictionary, x: float, y: float,
		height: float, radius: float) -> void:
	var key := str(room.get("id", "?"))
	if not _surface_reserved.has(key):
		_surface_reserved[key] = []
	_surface_reserved[key].append({"x": x, "y": y, "height": height,
			"radius": radius})


static func surface_blocks(room: Dictionary, x: float, y: float,
		height: float, radius := 0.24) -> bool:
	for item in _surface_reserved.get(str(room.get("id", "?")), []):
		if Vector2(x, y).distance_to(Vector2(item.x, item.y)) \
				< radius + float(item.radius) + 0.08 \
				and absf(height - float(item.height)) < 0.34:
			return true
	return false


static func _room_has_rail(room: Dictionary) -> bool:
	return str(room.get("kind", "")) in ["corridor", "hall", "lobby"]


## Backwards-compatible boolean form.
static func wall_backs(floor_data: Dictionary, px: float, py: float,
		height: float, half_height := ART_HALF_H) -> bool:
	return not backing_wall(floor_data, px, py, height, half_height,
			0.0, true).is_empty() \
			or not backing_wall(floor_data, px, py, height, half_height,
			0.0, false).is_empty()


## The wall that actually backs (px, py), or {} when none does.
##
## Three things this now gets right that the boolean version did not.
## ORIENTATION: a north-facing piece needs an east-west wall behind it, and
## without that gate a perpendicular wall passing near the probe validated the
## hook and the frame hung at right angles to its own backing.
## EXTENT: the thickness pad was applied ALONG the run as well as across it,
## so a wall endorsed a hook up to `t/2 + 0.06` past its own end. The piece's
## own half-width is what has to fit, and it must fit inside.
## FACE: the caller needs the wall, not a yes, or it cannot find the plaster.
static func backing_wall(floor_data: Dictionary, px: float, py: float,
		height: float, half_height := ART_HALF_H, half_width := 0.0,
		want_horizontal := true) -> Dictionary:
	# NEAREST, not first. Iteration order is the generator's, not the room's,
	# so "the first wall that validates" can be a parallel wall further off,
	# and the hook is then seated onto a face it was never probing.
	var best: Dictionary = {}
	var best_d := 1e9
	for w in floor_data.get("walls", []):
		var ax: float = float(w["a"][0])
		var ay: float = float(w["a"][1])
		var bx: float = float(w["b"][0])
		var by: float = float(w["b"][1])
		var horizontal := absf(by - ay) < 0.001
		if horizontal != want_horizontal:
			continue
		var cross_pad: float = float(w.get("t", 0.12)) / 2.0 + 0.06
		var hit := false
		if horizontal:
			hit = minf(ax, bx) + half_width <= px \
					and px <= maxf(ax, bx) - half_width \
					and absf(py - ay) <= cross_pad
		else:
			hit = minf(ay, by) + half_width <= py \
					and py <= maxf(ay, by) - half_width \
					and absf(px - ax) <= cross_pad
		if not hit:
			continue
		# Inside the wall — but not hanging over a doorway or window: any
		# opening whose frame crosses the art band disqualifies this spot.
		var along := (px - minf(ax, bx)) if horizontal else (py - minf(ay, by))
		var clear := true
		for c in w.get("openings", []):
			if absf(along - float(c.get("at", -99.0))) \
					> float(c.get("w", 0.0)) / 2.0 + 0.45:
				continue
			var sill := float(c.get("sill", 0.0))
			if sill <= height + half_height \
					and sill + float(c.get("h", 0.0)) >= height - half_height:
				clear = false
		# A railed wall refuses pieces that would cross its cap -- but only on
		# the face that actually carries the band. build_orison records
		# `wains_side` and lays the dado on that side alone, "so the bedroom
		# next door keeps its plaster"; refusing both faces threw away legal
		# wall on the plaster side of every tiled bathroom partition.
		if clear and bool(w.get("wainscot", false)) \
				and height - half_height < RAIL_TOP:
			var side: Variant = w.get("wains_side")
			var banded := true
			if side != null and str(side) != "":
				# THE PROBE SITS OUTSIDE THE ROOM by design, beyond the
				# rect edge, so its side of the centreline is the OPPOSITE of
				# the side the art hangs on. Reading the band from it inverts
				# the test and refuses exactly the faces it should allow.
				var cl := ay if horizontal else ax
				var pc := py if horizontal else px
				banded = (float(side) > 0.0) != (pc > cl)
			if banded:
				clear = false
		if not clear:
			continue
		var wcl := float(w["a"][1]) if horizontal else float(w["a"][0])
		var wd := absf((py if horizontal else px) - wcl)
		if wd < best_d:
			best_d = wd
			best = w
	return best
