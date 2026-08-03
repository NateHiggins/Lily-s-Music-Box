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

const RAIL_TOP := 1.08     # wainscot cap height; art bottoms stay above
const ART_HALF_H := 0.34   # conservative half-height for clearance tests


static func legal_spot(floor_data: Dictionary, room: Dictionary,
		want_wall: String, want_along: float, height: float) -> Dictionary:
	var rect: Array = room.rect
	var walls_order: Array = [want_wall]
	for w in ["north", "south", "east", "west"]:
		if w != want_wall:
			walls_order.append(w)
	var alongs: Array = [want_along, 0.3, 0.5, 0.7, 0.25, 0.75, 0.4,
			0.6, 0.2, 0.8]
	# Walls with a rail push low pieces up above the cap, once, before
	# the search — a piece authored at rail height is a request, not a fact.
	var hang_height := maxf(height, RAIL_TOP + ART_HALF_H + 0.06) \
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
			if not wall_backs(floor_data, bx, by, hang_height):
				continue
			if furniture_blocks(floor_data, x, y):
				continue
			return {"ok": true, "x": x, "y": y, "yaw": yaw, "wall": wall,
					"height": hang_height}
	return {"ok": false}


static func furniture_blocks(floor_data: Dictionary, px: float,
		py: float) -> bool:
	for fu in floor_data.get("furniture", []):
		if not fu.has("rect"):
			continue
		var r: Array = fu["rect"]
		if float(fu.get("h", 0.0)) < 0.9:
			continue        # low pieces sit under a hung frame happily
		if px >= float(r[0]) - 0.1 and px <= float(r[2]) + 0.1 \
				and py >= float(r[1]) - 0.1 and py <= float(r[3]) + 0.1:
			return true
	return false


static func _room_has_rail(room: Dictionary) -> bool:
	return str(room.get("kind", "")) in ["corridor", "hall", "lobby"]


## True when a real wall stands at (px, py) and no opening's frame swings
## through the band the art would occupy.
static func wall_backs(floor_data: Dictionary, px: float, py: float,
		height: float) -> bool:
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
			if sill <= height + ART_HALF_H \
					and sill + float(c.get("h", 0.0)) >= height - ART_HALF_H:
				clear = false
		# A railed wall also refuses pieces that would cross its cap.
		if clear and bool(w.get("wainscot", false)) \
				and height - ART_HALF_H < RAIL_TOP:
			clear = false
		if clear:
			return true
	return false
