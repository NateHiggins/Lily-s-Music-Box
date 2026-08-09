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

# The generated corridor cap is the high picture rail at 1.55 m (the old
# value, 1.08, described the panel field and put the rail through every
# frame). Hall art belongs wholly above it.
const RAIL_TOP := 1.56
const ART_HALF_H := 0.34   # conservative half-height for clearance tests
const ART_HALF_W := 0.38
const VISUAL_GAP := 0.18

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
			if not wall_backs(floor_data, bx, by, hang_height, half_height):
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


## True when a real wall stands at (px, py) and no opening's frame swings
## through the band the art would occupy.
static func wall_backs(floor_data: Dictionary, px: float, py: float,
		height: float, half_height := ART_HALF_H) -> bool:
	for w in floor_data.get("walls", []):
		var ax: float = float(w["a"][0])
		var ay: float = float(w["a"][1])
		var bx: float = float(w["b"][0])
		var by: float = float(w["b"][1])
		var pad: float = float(w.get("t", 0.12)) / 2.0 + 0.06
		var hit := false
		if absf(by - ay) < 0.001:
			hit = minf(ax, bx) - pad <= px and px <= maxf(ax, bx) + pad \
					and absf(py - ay) <= pad
		else:
			hit = minf(ay, by) - pad <= py and py <= maxf(ay, by) + pad \
					and absf(px - ax) <= pad
		if not hit:
			continue
		# Inside the wall — but not hanging over a doorway or window: any
		# opening whose frame crosses the art band disqualifies this spot.
		var horizontal := absf(by - ay) < 0.001
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
		# A railed wall also refuses pieces that would cross its cap.
		if clear and bool(w.get("wainscot", false)) \
				and height - half_height < RAIL_TOP:
			clear = false
		if clear:
			return true
	return false
