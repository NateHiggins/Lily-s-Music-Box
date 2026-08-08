class_name CartShards
extends RefCounted
## SHARDS — Shattered, ported off HTML.
##
## A picture is broken into triangles of glass and scattered. Tilt to
## slide them; when a piece drifts near the hole it came from it is
## drawn in and locks with a gold hairline where the crack was. Seat
## every piece and the picture is whole, cracks and all.
##
## The web build has two inputs: tilt, and dragging a shard with a
## finger. There is no finger here — this is a phone drawn inside a
## game, and the player's hands are on a keyboard or a controller — so
## the port keeps the one the original designed for phones and drops
## the fallback. Same reading as MAZE: accelerometer where there is one,
## key shoves where there is not.
##
## Triangulation is the original's jittered grid, and the reason it has
## to be a grid is subtle: neighbouring triangles SHARE their jittered
## corners, so the pieces tile the frame exactly with no slivers of
## background between them. Border vertices only jitter along the
## border, so the outer edge of the picture stays a clean rectangle.
##
## Picture comes from the camera roll, the same as PAIRS and MAZE.

const SNAP_DIST := 18.0      # near enough home to be drawn in
const SNAP_SPEED := 55.0     # and slow enough to settle there
const MAGNET_DIST := 70.0    # gentle pull once it is close
const GRAVITY := 1000.0      # px/s^2 at full tilt
const FRICTION := 0.985

const GOLD := Color("d4af5e")
const INK := Color("120810")
const VELVET := Color("2a1220")

enum State { PLAY, WON }

var shards: Array = []
var state: int = State.PLAY
var count := 12
var art_tex: Texture2D

var tilt_ax := 0.0
var tilt_ay := 0.0

var _rect := Rect2()
var _fit := Rect2()          # where the picture lands, cover-fitted
var _t := 0.0
var _key_ax := 0.0
var _key_ay := 0.0
var _key_left := 0.0
var _rng := RandomNumberGenerator.new()
var _base_tilt := Vector2.ZERO
var _have_base := false
var _built := false


func start(roll: Array, loader: Callable, pieces := 12) -> void:
	count = pieces
	state = State.PLAY
	_t = 0.0
	_have_base = false
	_built = false
	shards = []
	art_tex = null
	if roll.size() > 0:
		_rng.randomize()
		art_tex = loader.call(str(roll[_rng.randi() % roll.size()]))


func locked_count() -> int:
	var n := 0
	for s in shards:
		if s["locked"]:
			n += 1
	return n


## Builds the jittered grid and scatters the pieces. Called from draw()
## once the panel rect is known, because every coordinate here is in
## panel pixels and there is nothing to compute before that.
func layout(rect: Rect2) -> void:
	_rect = rect
	_fit = rect
	var cells := count / 2
	# Landscape panel, so the grid is wider than it is tall — the web
	# build's 2x3 would give tall splinters on a screen this shape.
	var cols := 3 if count <= 12 else 4
	var rows := int(cells / cols)
	var cw := rect.size.x / float(cols)
	var ch := rect.size.y / float(rows)
	var jx := cw * 0.3
	var jy := ch * 0.3
	_rng.randomize()

	var verts: Array = []
	for j in rows + 1:
		var row: Array[Vector2] = []
		for i in cols + 1:
			var x := rect.position.x + i * cw
			var y := rect.position.y + j * ch
			# Interior corners wander; edge corners stay on the edge so
			# the picture keeps a clean rectangular border.
			if i > 0 and i < cols:
				x += _rng.randf_range(-jx, jx)
			if j > 0 and j < rows:
				y += _rng.randf_range(-jy, jy)
			row.append(Vector2(x, y))
		verts.append(row)

	shards = []
	for j in rows:
		for i in cols:
			var a: Vector2 = verts[j][i]
			var b: Vector2 = verts[j][i + 1]
			var c: Vector2 = verts[j + 1][i + 1]
			var d: Vector2 = verts[j + 1][i]
			# Which way the quad splits is a coin toss, so the break
			# never reads as a grid.
			var tris: Array = [[a, b, c], [a, c, d]]
			if _rng.randf() < 0.5:
				tris = [[a, b, d], [b, c, d]]
			for t in tris:
				shards.append(_make_shard(t))
	_built = true


func _make_shard(pts: Array) -> Dictionary:
	var poly := PackedVector2Array(pts)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.y)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.y)
	var s := {
		"pts": poly, "lo": lo, "hi": hi,
		"off": Vector2.ZERO, "v": Vector2.ZERO,
		"locked": false, "flash": 0.0,
	}
	# Scatter beyond the magnet's reach. Clamping to the frame can drag
	# a piece back toward its hole, so the throw is clamped first and
	# re-rolled if it lands too close to count as scattered.
	var reach := MAGNET_DIST * 1.4
	var span := maxf(20.0, minf(_rect.size.x, _rect.size.y) * 0.45 - reach)
	for tries in 40:
		var ang := _rng.randf() * TAU
		var rad := reach + _rng.randf() * span
		var off := Vector2(cos(ang), sin(ang)) * rad
		off = _clamp_off(s, off)
		s["off"] = off
		if off.length() >= MAGNET_DIST * 1.3:
			break
	return s


func _clamp_off(s: Dictionary, off: Vector2) -> Vector2:
	var lo: Vector2 = s["lo"]
	var hi: Vector2 = s["hi"]
	if lo.x + off.x < _rect.position.x:
		off.x = _rect.position.x - lo.x
	if hi.x + off.x > _rect.position.x + _rect.size.x:
		off.x = _rect.position.x + _rect.size.x - hi.x
	if lo.y + off.y < _rect.position.y:
		off.y = _rect.position.y - lo.y
	if hi.y + off.y > _rect.position.y + _rect.size.y:
		off.y = _rect.position.y + _rect.size.y - hi.y
	return off


func _read_tilt() -> void:
	var acc := Input.get_accelerometer()
	if acc == Vector3.ZERO:
		return
	var cur := Vector2(rad_to_deg(atan2(acc.x, -acc.z)),
			rad_to_deg(atan2(acc.y, -acc.z)))
	if not _have_base:
		_base_tilt = cur
		_have_base = true
	tilt_ax = clampf(cur.x - _base_tilt.x, -40.0, 40.0)
	tilt_ay = clampf(cur.y - _base_tilt.y, -40.0, 40.0)


func recentre() -> void:
	_have_base = false


func key(action: String) -> void:
	if state == State.WON:
		if action == "ok":
			# Break it again, same picture, new cracks.
			var keep := art_tex
			start([], func(_p): return null, count)
			art_tex = keep
			layout(_rect)
		return
	match action:
		"left":
			_key_ax = -24.0
			_key_left = 0.35
		"right":
			_key_ax = 24.0
			_key_left = 0.35
		"up":
			_key_ay = -24.0
			_key_left = 0.35
		"down":
			_key_ay = 24.0
			_key_left = 0.35
		"ok":
			recentre()


func tick(delta: float) -> void:
	_t += delta
	if not _built or state == State.WON:
		for s in shards:
			s["flash"] = maxf(0.0, s["flash"] - delta * 2.0)
		return
	_read_tilt()
	if _key_left > 0.0:
		_key_left = maxf(0.0, _key_left - delta)
		if _key_left <= 0.0:
			_key_ax = 0.0
			_key_ay = 0.0
	# The original's tilt is a unit-ish gravity vector, degrees over 40.
	var g := Vector2(clampf((tilt_ax + _key_ax) / 40.0, -1.0, 1.0),
			clampf((tilt_ay + _key_ay) / 40.0, -1.0, 1.0))

	for s in shards:
		if s["locked"]:
			s["flash"] = maxf(0.0, s["flash"] - delta * 2.0)
			continue
		var v: Vector2 = s["v"]
		var off: Vector2 = s["off"]
		v += g * GRAVITY * delta
		var d := off.length()
		if d < MAGNET_DIST:
			v -= off * 6.0 * delta * 60.0
		v *= FRICTION
		off += v * delta

		# Walls of the frame, with most of the energy absorbed.
		var lo: Vector2 = s["lo"]
		var hi: Vector2 = s["hi"]
		if lo.x + off.x < _rect.position.x:
			off.x = _rect.position.x - lo.x
			v.x *= -0.35
		if hi.x + off.x > _rect.position.x + _rect.size.x:
			off.x = _rect.position.x + _rect.size.x - hi.x
			v.x *= -0.35
		if lo.y + off.y < _rect.position.y:
			off.y = _rect.position.y - lo.y
			v.y *= -0.35
		if hi.y + off.y > _rect.position.y + _rect.size.y:
			off.y = _rect.position.y + _rect.size.y - hi.y
			v.y *= -0.35

		s["off"] = off
		s["v"] = v
		if off.length() < SNAP_DIST and v.length() < SNAP_SPEED:
			_lock(s)

	if locked_count() >= shards.size() and shards.size() > 0:
		state = State.WON


func _lock(s: Dictionary) -> void:
	s["locked"] = true
	s["off"] = Vector2.ZERO
	s["v"] = Vector2.ZERO
	s["flash"] = 1.0


## Texture coordinates for a panel-space point, so a displaced shard
## still carries the piece of picture cut from its own hole.
func _uv(p: Vector2) -> Vector2:
	if _fit.size.x <= 0.0 or _fit.size.y <= 0.0:
		return Vector2.ZERO
	return Vector2((p.x - _fit.position.x) / _fit.size.x,
			(p.y - _fit.position.y) / _fit.size.y)


func draw(ci: CanvasItem, rect: Rect2, _font: Font) -> void:
	if not _built or not _rect.size.is_equal_approx(rect.size):
		layout(rect)
	ci.draw_rect(rect, INK)

	var uvs_for := func(s: Dictionary, off: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in s["pts"]:
			out.append(_uv(p))
		return out

	# Seated glass first: in place, with a hairline where it cracked.
	for s in shards:
		if not s["locked"]:
			continue
		_poly(ci, s, Vector2.ZERO, uvs_for.call(s, Vector2.ZERO))
		var flash: float = s["flash"]
		_outline(ci, s, Vector2.ZERO,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.12 + flash * 0.7), 1.0)

	# The holes still waiting, as dashed ghosts.
	for s in shards:
		if s["locked"]:
			continue
		_dashed(ci, s, Color(GOLD.r, GOLD.g, GOLD.b, 0.14))

	# Loose glass on top, lifted off the surface.
	for s in shards:
		if s["locked"]:
			continue
		var off: Vector2 = s["off"]
		_poly(ci, s, off + Vector2(0, 3), uvs_for.call(s, off),
				Color(0, 0, 0, 0.5))
		_poly(ci, s, off, uvs_for.call(s, off), Color(1, 1, 1, 0.96))
		_outline(ci, s, off, Color(GOLD.r, GOLD.g, GOLD.b, 0.65), 1.5)


func _poly(ci: CanvasItem, s: Dictionary, off: Vector2,
		uvs: PackedVector2Array, tint := Color.WHITE) -> void:
	var pts := PackedVector2Array()
	for p in s["pts"]:
		pts.append(p + off)
	if art_tex and tint.a > 0.9:
		ci.draw_colored_polygon(pts, tint, uvs, art_tex)
	else:
		var flat := VELVET if tint == Color.WHITE else tint
		ci.draw_colored_polygon(pts, flat)


func _outline(ci: CanvasItem, s: Dictionary, off: Vector2, col: Color,
		width: float) -> void:
	var pts: PackedVector2Array = s["pts"]
	for i in pts.size():
		var a: Vector2 = pts[i] + off
		var b: Vector2 = pts[(i + 1) % pts.size()] + off
		ci.draw_line(a, b, col, width)


## Godot's canvas has no dash pattern, so the ghost is stitched by hand.
func _dashed(ci: CanvasItem, s: Dictionary, col: Color) -> void:
	var pts: PackedVector2Array = s["pts"]
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var walked := 0.0
		while walked < length:
			var seg := minf(4.0, length - walked)
			ci.draw_line(a + dir * walked, a + dir * (walked + seg),
					col, 1.0)
			walked += seg + 5.0


func status() -> String:
	if state == State.WON:
		return "whole again, cracks and all.  enter: break it"
	if art_tex == null:
		return "%d/%d  ..  nothing to piece together yet" % [
			locked_count(), shards.size()]
	return "%d/%d seated   enter: re-centre" % [
		locked_count(), shards.size()]
