extends Node
## Does the Velvet Maze generate a solvable chamber, lift its fog along
## the marble's path, and open the door at the end?
##
## The load-bearing check is REACHABILITY. Every other bug here is
## visible in a second of play; a maze with a walled-off pocket looks
## completely normal and simply cannot be finished, because the fog over
## that pocket is a percentage the player can never earn. The recursive
## backtracker guarantees it by construction, so this test is really
## guarding the port of the generator rather than the generator itself.
##
## Runs against a real handset in a real building, the same as the pairs
## suite, because the picture under the fog comes from the camera roll
## and that join is the part worth testing.
##
## REAL WINDOW REQUIRED — no --headless. The handset photographs the
## world through a SubViewport, and headless has nothing to read back,
## so capture() returns "" and every check downstream of the roll fails
## for a reason that has nothing to do with the maze:
##
##   godot --path game res://tests/CartMazeTest.tscn

const PANEL := Rect2(10, 32, 460, 304)

var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.4).timeout
	_run()


## Flood fill through the carved openings. Anything it cannot touch is a
## pocket of permanent fog.
func _reachable(m: CartMaze) -> int:
	var seen := {}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	seen[Vector2i(0, 0)] = true
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		var cell: Dictionary = m.maze[cur.y][cur.x]
		var steps := [
			[Vector2i(0, -1), "n"], [Vector2i(1, 0), "e"],
			[Vector2i(0, 1), "s"], [Vector2i(-1, 0), "w"],
		]
		for st in steps:
			if cell[st[1]]:
				continue                       # wall still standing
			var nx: Vector2i = cur + (st[0] as Vector2i)
			if nx.x < 0 or nx.y < 0 or nx.x >= m.cols or nx.y >= m.rows:
				continue
			if seen.has(nx):
				continue
			seen[nx] = true
			queue.append(nx)
	return seen.size()


func _fog_alpha_at(m: CartMaze, c: int, r: int) -> float:
	var p := m._cell_centre(c, r)
	var x := int((p.x - m._rect.position.x) / CartMaze.FOG_DIV)
	var y := int((p.y - m._rect.position.y) / CartMaze.FOG_DIV)
	x = clampi(x, 0, m.fog_img.get_width() - 1)
	y = clampi(y, 0, m.fog_img.get_height() - 1)
	return m.fog_img.get_pixel(x, y).a


## Walks the marble cell to cell along a route the maze actually allows,
## which is how a player would arrive but without the tilting.
func _drive_to(m: CartMaze, path: Array) -> void:
	for step in path:
		var target: Vector2 = m._cell_centre(step.x, step.y)
		m.ball["x"] = target.x
		m.ball["y"] = target.y
		m.ball["vx"] = 0.0
		m.ball["vy"] = 0.0
		m.tick(0.016)


## Breadth-first route from the corner to the door.
func _solve(m: CartMaze) -> Array:
	var prev := {}
	var start := Vector2i(0, 0)
	var goal := Vector2i(m.exit_c, m.exit_r)
	var queue: Array[Vector2i] = [start]
	prev[start] = start
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			break
		var cell: Dictionary = m.maze[cur.y][cur.x]
		var steps := [
			[Vector2i(0, -1), "n"], [Vector2i(1, 0), "e"],
			[Vector2i(0, 1), "s"], [Vector2i(-1, 0), "w"],
		]
		for st in steps:
			if cell[st[1]]:
				continue
			var nx: Vector2i = cur + (st[0] as Vector2i)
			if nx.x < 0 or nx.y < 0 or nx.x >= m.cols or nx.y >= m.rows:
				continue
			if prev.has(nx):
				continue
			prev[nx] = cur
			queue.append(nx)
	var route: Array = []
	if not prev.has(goal):
		return route
	var walk: Vector2i = goal
	while walk != start:
		route.push_front(walk)
		walk = prev[walk]
	return route


func _run() -> void:
	var carrier = root.get("phone_carrier")
	var phone = carrier.phone
	var cam = phone.cam
	var m: CartMaze = phone.maze

	# A roll with something in it, taken here, now.
	for p in cam.roll.duplicate():
		DirAccess.remove_absolute(str(p))
	cam.roll.clear()
	root.player.global_position = Vector3(-0.4, 0.0, 8.6)
	root.player.camera.make_current()
	phone.os_sim.screen = PhoneOS.Screen.APP
	phone.os_sim.app_id = "cam"
	phone.os_sim.gallery_open = false
	carrier.raised = true
	for i in 24:
		await get_tree().process_frame
	for i in 3:
		root.player.rotation.y = deg_to_rad(-150.0 + i * 50.0)
		for f in 10:
			await get_tree().process_frame
		cam.capture()
	_check("three photographs on the roll", cam.roll.size() == 3)

	m.start(cam.roll, func(p): return cam.load_photo(p), 1)
	m.layout(PANEL)
	_check("chamber I is %dx%d" % [m.cols, m.rows],
			m.cols == CartMaze.COLS_BASE and m.rows == CartMaze.ROWS_BASE)
	_check("a photograph waits under the fog", m.art_tex != null)

	# The invariant: no walled-off pockets, in this chamber or deeper
	# ones where the generator has more room to go wrong.
	var all_reach := true
	for lvl in [1, 2, 5, 9]:
		m.start(cam.roll, func(p): return cam.load_photo(p), lvl)
		m.layout(PANEL)
		var want := m.cols * m.rows
		var got := _reachable(m)
		if got != want:
			all_reach = false
			print("      chamber %d: %d of %d cells reachable"
					% [lvl, got, want])
	_check("every cell of every chamber is reachable", all_reach)

	# Same chamber twice must be the same chamber.
	m.start(cam.roll, func(p): return cam.load_photo(p), 4)
	m.layout(PANEL)
	var first_walls := m.walls.size()
	var first_open: bool = m.maze[0][0]["e"]
	m.start(cam.roll, func(p): return cam.load_photo(p), 4)
	m.layout(PANEL)
	_check("chamber IV is the same chamber every time",
			m.walls.size() == first_walls and m.maze[0][0]["e"] == first_open)

	# Fog.
	m.start(cam.roll, func(p): return cam.load_photo(p), 1)
	m.layout(PANEL)
	var far := Vector2i(m.exit_c, m.exit_r)
	_check("fog starts opaque over the far corner",
			_fog_alpha_at(m, far.x, far.y) > 0.9)
	_check("the starting cell is already clear",
			_fog_alpha_at(m, 0, 0) < 0.2)
	_check("nothing unveiled but the first cell",
			m.unveiled_percent() == int(round(100.0 / (m.cols * m.rows))))

	# Walls hold.
	m.ball["x"] = m._rect.position.x + m._cs * 0.5
	m.ball["y"] = m._rect.position.y + m._cs * 0.5
	m.tilt_ax = -28.0
	m.tilt_ay = -28.0
	for i in 60:
		m.tick(0.016)
	m.tilt_ax = 0.0
	m.tilt_ay = 0.0
	_check("the marble cannot leave the maze",
			m.ball["x"] >= m._rect.position.x
			and m.ball["y"] >= m._rect.position.y
			and m.ball["x"] <= m._rect.position.x + m._rect.size.x
			and m.ball["y"] <= m._rect.position.y + m._rect.size.y)

	# Solve it.
	var route := _solve(m)
	_check("the door can be reached from the corner", route.size() > 0)
	_drive_to(m, route)
	_check("reaching the door wins the chamber",
			m.state == CartMaze.State.WON)
	_check("the trail lifted the fog behind it (%d%%)"
			% m.unveiled_percent(), m.unveiled_percent() > 20)
	_check("fog over the door is gone",
			_fog_alpha_at(m, far.x, far.y) < 0.2)

	# The veil keeps lifting after the win until the picture is bare.
	for i in 180:
		m.tick(0.016)
	_check("winning clears the veil entirely", m.fog_alpha <= 0.0)

	# Deeper.
	m.key("ok")
	_check("enter opens the next chamber",
			m.level == 2 and m.state == CartMaze.State.PLAY)
	_check("the next chamber is larger", m.cols > CartMaze.COLS_BASE)

	print("[MAZE] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
