class_name CartMaze
extends RefCounted
## MAZE — the Velvet Maze, ported off HTML.
##
## Roll a marble through a maze by TILTING. Wherever it wanders the fog
## lifts, so the maze is not really an obstacle course — it is a way of
## uncovering a picture slowly, with the gilded door at the far corner
## taking the last of the veil when you reach it.
##
## The original carries a curious piece of plumbing: `window.__nativeTilt
## (beta, gamma)`, which exists so the Android wrapper can feed the page
## real accelerometer readings, because a browser tab could not get at
## the sensor it needed. Godot simply HAS that sensor. So the port drops
## the bridge and reads the device directly, which means on a handset
## this plays exactly as it was meant to — you tilt the real phone to
## roll the marble on the phone drawn inside the game. On a desktop
## there is no accelerometer, and the arrow keys nudge instead.
##
## The picture under the fog is the camera roll, the same as PAIRS. What
## the two cartridges do with it differs: pairs makes you take the veil
## apart in pieces, this one makes you walk every corridor to wipe it.

const COLS_BASE := 9
const ROWS_BASE := 6
const MAX_GROW := 8

const INK := Color("120810")
const VELVET := Color("2a1220")
const WALL := Color("170a12")
const GOLD := Color("d4af5e")
const IVORY := Color("efe3d0")
const ROSE := Color("c4788a")

## Fog is kept at a quarter of the panel's resolution. It is a soft mask
## being smeared by a ball, so it has nothing fine in it to lose, and a
## quarter-size buffer is sixteen times fewer pixels to rewrite.
const FOG_DIV := 4

const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
	"X", "XI", "XII"]

enum State { PLAY, WON }

var level := 1
var cols := COLS_BASE
var rows := ROWS_BASE
var state: int = State.PLAY
var moves := 0

var maze: Array = []               # per cell: {n,e,s,w} open flags
var walls: Array[Rect2] = []       # in panel-local pixels
var visited: Array = []
var visit_count := 0

var ball := {"x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "r": 0.0}
var exit_c := 0
var exit_r := 0

var art_tex: Texture2D
var fog_img: Image
var fog_tex: ImageTexture
var fog_alpha := 1.0

var tilt_ax := 0.0
var tilt_ay := 0.0

var _rect := Rect2()
var _cs := 0.0
var _wall_t := 3.0
var _t := 0.0
var _key_ax := 0.0
var _key_ay := 0.0
var _key_left := 0.0
var _fog_dirty := false
var _last_erase := Vector2(-999, -999)
var _rng := RandomNumberGenerator.new()
var _base_tilt := Vector2.ZERO
var _have_base := false
## Cleared by start(), set by the first layout() of a chamber. A new
## chamber must put the marble back in the corner, and guessing that
## from its coordinates fails on every chamber after the first — it is
## still sitting on the old door, which is not the origin.
var _placed := false


## `roll` is PhoneCamera.roll, exactly as PAIRS takes it.
func start(roll: Array, loader: Callable, n := -1) -> void:
	if n > 0:
		level = n
	state = State.PLAY
	moves = 0
	fog_alpha = 1.0
	_t = 0.0
	var grow: int = mini(level - 1, MAX_GROW)
	# Landscape panel, so the maze grows along the long axis first —
	# the original grew rows fastest because a phone held upright is
	# taller than it is wide, and this screen is the other way round.
	cols = COLS_BASE + grow
	rows = ROWS_BASE + int(floor(grow * 0.6))
	# Deterministic per level: chamber IV is the same chamber for
	# everyone, which the original got from seeding on the level number.
	var seeded := RandomNumberGenerator.new()
	seeded.seed = hash("velvet:%d" % level)
	_gen(seeded)
	visited = []
	for r in rows:
		var row: Array[bool] = []
		for c in cols:
			row.append(false)
		visited.append(row)
	visit_count = 0
	exit_c = cols - 1
	exit_r = rows - 1
	art_tex = null
	if roll.size() > 0:
		_rng.randomize()
		art_tex = loader.call(str(roll[_rng.randi() % roll.size()]))
	_have_base = false
	_placed = false


## Recursive backtracker, the same generator the web build uses. Carving
## from a stack guarantees every cell is reachable, which matters here
## because an unreachable cell is a patch of fog that can never lift.
func _gen(rng: RandomNumberGenerator) -> void:
	maze = []
	for r in rows:
		var row: Array = []
		for c in cols:
			row.append({"n": true, "e": true, "s": true, "w": true,
				"seen": false})
		maze.append(row)
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	maze[0][0]["seen"] = true
	var dirs := [
		[Vector2i(0, -1), "n", "s"],
		[Vector2i(1, 0), "e", "w"],
		[Vector2i(0, 1), "s", "n"],
		[Vector2i(-1, 0), "w", "e"],
	]
	while stack.size() > 0:
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array = []
		for d in dirs:
			var nx: Vector2i = cur + (d[0] as Vector2i)
			if nx.x >= 0 and nx.y >= 0 and nx.x < cols and nx.y < rows 					and not maze[nx.y][nx.x]["seen"]:
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: Array = options[rng.randi() % options.size()]
		var nxt: Vector2i = cur + (pick[0] as Vector2i)
		maze[cur.y][cur.x][pick[1]] = false
		maze[nxt.y][nxt.x][pick[2]] = false
		maze[nxt.y][nxt.x]["seen"] = true
		stack.append(nxt)


## Called whenever the panel rect is known or changes. Builds the wall
## rectangles and a fresh fog buffer, then re-erases everywhere the ball
## has already been so a resize does not put the veil back.
func layout(rect: Rect2) -> void:
	_rect = rect
	if maze.is_empty():
		return
	_cs = floor(minf(rect.size.x / float(cols), rect.size.y / float(rows)))
	_cs = maxf(_cs, 6.0)
	var mw := _cs * cols
	var mh := _cs * rows
	_rect = Rect2(rect.position.x + round((rect.size.x - mw) * 0.5),
			rect.position.y + round((rect.size.y - mh) * 0.5), mw, mh)
	ball["r"] = _cs * 0.28
	_wall_t = maxf(2.0, _cs * 0.11)

	walls = []
	var t := _wall_t
	for r in rows:
		for c in cols:
			var cell: Dictionary = maze[r][c]
			var x: float = _rect.position.x + c * _cs
			var y: float = _rect.position.y + r * _cs
			if cell["n"]:
				walls.append(Rect2(x - t * 0.5, y - t * 0.5, _cs + t, t))
			if cell["w"]:
				walls.append(Rect2(x - t * 0.5, y - t * 0.5, t, _cs + t))
			if c == cols - 1 and cell["e"]:
				walls.append(Rect2(x + _cs - t * 0.5, y - t * 0.5, t,
						_cs + t))
			if r == rows - 1 and cell["s"]:
				walls.append(Rect2(x - t * 0.5, y + _cs - t * 0.5,
						_cs + t, t))

	_fog_reset()
	# Placing the marble has to happen BEFORE the re-erase sweep, or the
	# cell it starts in is marked visited too late and opens under fog.
	if not _placed:
		var home := _cell_centre(0, 0)
		ball["x"] = home.x
		ball["y"] = home.y
		ball["vx"] = 0.0
		ball["vy"] = 0.0
		_placed = true
		_visit(0, 0)
	for r in rows:
		for c in cols:
			if visited[r][c]:
				_erase_at(_cell_centre(c, r), true)


func _cell_centre(c: int, r: int) -> Vector2:
	return Vector2(_rect.position.x + (c + 0.5) * _cs,
			_rect.position.y + (r + 0.5) * _cs)


func _fog_reset() -> void:
	var w := maxi(8, int(_rect.size.x) / FOG_DIV)
	var h := maxi(8, int(_rect.size.y) / FOG_DIV)
	fog_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	fog_img.fill(Color(0.10, 0.05, 0.08, 1.0))
	fog_tex = ImageTexture.create_from_image(fog_img)
	_fog_dirty = false
	_last_erase = Vector2(-999, -999)


## Wipes a soft disc out of the fog at a panel-local point. Alpha only
## ever goes DOWN, so overlapping passes accumulate into a clean trail
## instead of flickering brighter and darker as the ball wobbles.
func _erase_at(p: Vector2, hard := false) -> void:
	if fog_img == null:
		return
	var fx := (p.x - _rect.position.x) / FOG_DIV
	var fy := (p.y - _rect.position.y) / FOG_DIV
	var rad := (_cs * (0.95 if hard else 0.85)) / FOG_DIV
	var x0 := maxi(0, int(fx - rad))
	var x1 := mini(fog_img.get_width() - 1, int(fx + rad))
	var y0 := maxi(0, int(fy - rad))
	var y1 := mini(fog_img.get_height() - 1, int(fy + rad))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x - fx, y - fy).length() / maxf(rad, 0.001)
			if d >= 1.0:
				continue
			# Solid to the middle, feathered at the rim, matching the
			# radial the canvas build punched through with.
			var keep := clampf((d - 0.55) / 0.45, 0.0, 1.0)
			var col := fog_img.get_pixel(x, y)
			if keep < col.a:
				col.a = keep
				fog_img.set_pixel(x, y, col)
	_fog_dirty = true


func _visit(c: int, r: int) -> void:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return
	if visited[r][c]:
		return
	visited[r][c] = true
	visit_count += 1


func unveiled_percent() -> int:
	if cols * rows == 0:
		return 0
	return int(round(100.0 * visit_count / float(cols * rows)))


## The handset's own tilt, in degrees, relative to however it was being
## held when the chamber opened. Reading the accelerometer here rather
## than taking it from the host is the whole point of the port.
func _read_tilt() -> void:
	var acc := Input.get_accelerometer()
	if acc == Vector3.ZERO:
		return
	# Gravity down the screen is +Y; tipping right pushes X. Degrees off
	# flat, near enough for a marble, without a trig-heavy conversion.
	var cur := Vector2(rad_to_deg(atan2(acc.x, -acc.z)),
			rad_to_deg(atan2(acc.y, -acc.z)))
	if not _have_base:
		_base_tilt = cur
		_have_base = true
	tilt_ax = clampf(cur.x - _base_tilt.x, -28.0, 28.0)
	tilt_ay = clampf(cur.y - _base_tilt.y, -28.0, 28.0)


func recentre() -> void:
	_have_base = false


func key(action: String) -> void:
	if state == State.WON:
		if action == "ok":
			start([], func(_p): return null, level + 1)
			layout(_rect)
		return
	# Discrete presses rather than held keys, because the OS hands the
	# cartridge events and not a keyboard state. A press is a shove that
	# fades, so holding the key down repeats it and the marble rolls.
	match action:
		"left":
			_key_ax = -16.0
			_key_left = 0.35
		"right":
			_key_ax = 16.0
			_key_left = 0.35
		"up":
			_key_ay = -16.0
			_key_left = 0.35
		"down":
			_key_ay = 16.0
			_key_left = 0.35
		"ok":
			recentre()


func tick(delta: float) -> void:
	_t += delta
	if maze.is_empty() or _cs <= 0.0:
		return
	if state == State.WON:
		fog_alpha = maxf(0.0, fog_alpha - delta * 0.55)
		return
	_read_tilt()
	if _key_left > 0.0:
		_key_left = maxf(0.0, _key_left - delta)
		if _key_left <= 0.0:
			_key_ax = 0.0
			_key_ay = 0.0

	var ax := tilt_ax + _key_ax
	var ay := tilt_ay + _key_ay
	var acc := _cs * 0.9
	ball["vx"] = ball["vx"] + ax * acc * delta * 0.1
	ball["vy"] = ball["vy"] + ay * acc * delta * 0.1
	var drag := pow(0.32, delta)          # heavy, like rolling on velvet
	ball["vx"] = ball["vx"] * drag
	ball["vy"] = ball["vy"] * drag
	var vmax := _cs * 14.0
	var sp := Vector2(ball["vx"], ball["vy"]).length()
	if sp > vmax:
		ball["vx"] = ball["vx"] * vmax / sp
		ball["vy"] = ball["vy"] * vmax / sp

	# Sub-stepped, or a fast marble tunnels straight through a wall it
	# never occupied a frame inside.
	for i in 4:
		ball["x"] = ball["x"] + ball["vx"] * delta / 4.0
		ball["y"] = ball["y"] + ball["vy"] * delta / 4.0
		_collide()

	var p := Vector2(ball["x"], ball["y"])
	var cc := int(floor((p.x - _rect.position.x) / _cs))
	var cr := int(floor((p.y - _rect.position.y) / _cs))
	_visit(cc, cr)
	if p.distance_to(_last_erase) > _cs * 0.18:
		_erase_at(p)
		_last_erase = p

	if cc == exit_c and cr == exit_r:
		if p.distance_to(_cell_centre(exit_c, exit_r)) < _cs * 0.34:
			_win()


func _collide() -> void:
	var r: float = ball["r"]
	for w in walls:
		var cx := clampf(ball["x"], w.position.x, w.position.x + w.size.x)
		var cy := clampf(ball["y"], w.position.y, w.position.y + w.size.y)
		var dx: float = ball["x"] - cx
		var dy: float = ball["y"] - cy
		var d2 := dx * dx + dy * dy
		if d2 >= r * r or d2 == 0.0:
			continue
		var d := sqrt(d2)
		var nx := dx / d
		var ny := dy / d
		var push := r - d
		ball["x"] = ball["x"] + nx * push
		ball["y"] = ball["y"] + ny * push
		var vn: float = ball["vx"] * nx + ball["vy"] * ny
		if vn < 0.0:
			ball["vx"] = ball["vx"] - 1.45 * vn * nx
			ball["vy"] = ball["vy"] - 1.45 * vn * ny
	ball["x"] = clampf(ball["x"], _rect.position.x + r,
			_rect.position.x + _rect.size.x - r)
	ball["y"] = clampf(ball["y"], _rect.position.y + r,
			_rect.position.y + _rect.size.y - r)


func _win() -> void:
	state = State.WON
	moves += 1


func draw(ci: CanvasItem, rect: Rect2, font: Font) -> void:
	if maze.is_empty():
		return
	if not _rect.size.is_equal_approx(rect.size) or _cs <= 0.0:
		layout(rect)
	# Ground first, so the panel is never bare where the maze does not
	# reach after the aspect fit.
	ci.draw_rect(rect, INK)

	if art_tex:
		_draw_cover(ci, art_tex, _rect)
	else:
		ci.draw_rect(_rect, VELVET)

	if fog_alpha > 0.0 and fog_tex:
		if _fog_dirty:
			fog_tex.update(fog_img)
			_fog_dirty = false
		ci.draw_texture_rect(fog_tex, _rect, false,
				Color(1, 1, 1, fog_alpha))

	# On a win the walls go with the fog, so the last thing that happens
	# is the maze itself getting out of the way of the picture.
	var fade := fog_alpha if state == State.WON else 1.0
	if fade <= 0.0:
		return

	for w in walls:
		ci.draw_rect(w, Color(WALL.r, WALL.g, WALL.b, fade))
	var edge := maxf(1.0, _wall_t * 0.22)
	var lip := Color(GOLD.r, GOLD.g, GOLD.b, 0.32 * fade)
	for w in walls:
		if w.size.x > w.size.y:
			ci.draw_rect(Rect2(w.position, Vector2(w.size.x, edge)), lip)
		else:
			ci.draw_rect(Rect2(w.position, Vector2(edge, w.size.y)), lip)

	# The gilded door, breathing so the eye finds it.
	var e := _cell_centre(exit_c, exit_r)
	var pulse := 0.55 + 0.45 * sin(_t * 2.6)
	for i in 4:
		var rr := _cs * 0.6 * (1.0 - i * 0.22)
		ci.draw_circle(e, rr, Color(GOLD.r, GOLD.g, GOLD.b,
				0.10 * pulse * fade))
	ci.draw_arc(e, _cs * 0.22, 0.0, TAU, 20,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.85 * fade), 1.4)
	ci.draw_arc(e, _cs * 0.10 * (0.8 + 0.4 * pulse), 0.0, TAU, 14,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.85 * fade), 1.2)

	# The marble: a pearl, lit from the upper left.
	var b := Vector2(ball["x"], ball["y"])
	var br: float = ball["r"]
	ci.draw_circle(b + Vector2(0, br * 0.22), br,
			Color(0, 0, 0, 0.45 * fade))
	ci.draw_circle(b, br, Color(0.85, 0.77, 0.67, fade))
	ci.draw_circle(b - Vector2(br * 0.3, br * 0.34), br * 0.52,
			Color(0.97, 0.93, 0.86, fade))
	ci.draw_arc(b, br, 0.0, TAU, 18,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.5 * fade), 1.0)


## Fills `dst` with the texture without squashing it, by cropping the
## source instead of letterboxing the target.
func _draw_cover(ci: CanvasItem, tex: Texture2D, dst: Rect2) -> void:
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var want := dst.size.x / dst.size.y
	var have := ts.x / ts.y
	var src := Rect2(Vector2.ZERO, ts)
	if have > want:
		var sw := ts.y * want
		src = Rect2((ts.x - sw) * 0.5, 0.0, sw, ts.y)
	else:
		var sh := ts.x / want
		src = Rect2(0.0, (ts.y - sh) * 0.5, ts.x, sh)
	ci.draw_texture_rect_region(tex, dst, src)


func chamber() -> String:
	return ROMAN[(level - 1) % ROMAN.size()]


func status() -> String:
	if state == State.WON:
		return "chamber %s unveiled.  enter: go deeper" % chamber()
	if art_tex == null:
		return "chamber %s   %d%%  ..  nothing behind this yet" % [
			chamber(), unveiled_percent()]
	return "chamber %s   %d%% unveiled   enter: re-centre" % [
		chamber(), unveiled_percent()]
