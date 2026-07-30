extends Node
## Performance benchmark for the Phase 7 target: 60 fps at 1440p while
## walking the whole building. Must run WINDOWED — a headless run reports
## zeroes for every rendering counter, which reads as a pass.
##
##   godot --path game --resolution 2560x1440 res://tests/Perf.tscn
##
## Parks the camera at the stations that historically cost the most (the
## atrium eye sees seven storeys at once; the street sees the whole block)
## and reports objects/draw calls/primitives and the frame time behind
## them. Exit code is the number of stations over budget.

const FRAME_BUDGET_MS := 16.6
const WARMUP := 30
const SAMPLES := 90
## Every station in this building draws thousands of objects. Anything near
## zero means the scene did not load, which must fail rather than pass.
const MIN_OBJECTS := 500

## name, position, look-at. Positions are Godot space (GameBoot.b2g).
const STATIONS := [
	{"name": "lobby", "pos": Vector3(-0.4, 1.72, 9.1),
	 "look": Vector3(3.6, 1.25, 6.6)},
	{"name": "atrium eye (7 storeys)", "pos": Vector3(0.0, 1.8, 0.2),
	 "look": Vector3(0.3, 21.5, 0.0)},
	{"name": "corridor F04", "pos": Vector3(4.3, 11.25, 7.6),
	 "look": Vector3(4.3, 10.8, -6.0)},
	{"name": "apartment 4B", "pos": Vector3(-8.1, 11.25, -3.2),
	 "look": Vector3(-13.2, 10.2, -8.0)},
	{"name": "street elevation", "pos": Vector3(16, 12, 34),
	 "look": Vector3(0, 8, 0)},
	{"name": "roof", "pos": Vector3(-6, 21.4, 9.5),
	 "look": Vector3(2, 19.4, -4)},
]

var root: Node3D
var cam: Camera3D
var over_budget := 0


func _ready() -> void:
	# Without this the benchmark measures the display, not the renderer:
	# every station pins to the refresh interval and a real regression is
	# invisible until it is already costing frames.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false
	await get_tree().create_timer(1.0).timeout
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	print("PERF: viewport %s" % [get_viewport().get_visible_rect().size])
	# Visit every station once before timing anything. Godot compiles
	# shaders lazily on first draw, so whichever station goes first
	# otherwise absorbs the cost of the whole building's materials and
	# reports several times its true frame time.
	for s in STATIONS:
		cam.global_position = s["pos"]
		cam.look_at(s["look"])
		for i in WARMUP:
			await get_tree().process_frame
	_report_mesh_census()
	print("%-24s %7s %7s %9s %8s %7s" %
			["station", "objs", "calls", "prims", "ms", "fps"])
	for s in STATIONS:
		await _measure(s)
	print("PERF RESULT: %s (%d/%d stations over %.1f ms)" %
			["PASS" if over_budget == 0 else "FAIL", over_budget,
			STATIONS.size(), FRAME_BUDGET_MS])
	get_tree().quit(over_budget)


## Where the object count actually lives. Optimizing the wrong half of
## this is how a performance pass ends up costing effort for nothing.
func _report_mesh_census() -> void:
	var per_floor := 0
	for fid in root.floor_nodes:
		per_floor += _count_meshes(root.floor_nodes[fid])
	var props := 0
	var prop_nodes := 0
	for c in root.get_children():
		if c is FunctionalProp:
			prop_nodes += 1
			props += _count_meshes(c)
	print("PERF census: %d floor meshes, %d prop meshes across %d props "
			% [per_floor, props, prop_nodes] +
			"(%.1f each), %d total" %
			[float(props) / maxf(1.0, prop_nodes), per_floor + props])
	var by_type := {}
	for c in root.get_children():
		if c is FunctionalProp:
			var k: String = c.prop_type
			if not by_type.has(k):
				by_type[k] = [0, 0]
			by_type[k][0] += 1
			by_type[k][1] += _count_meshes(c)
	var rows: Array = []
	for k in by_type:
		rows.append([by_type[k][1], k, by_type[k][0]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		if r[0] < 40:
			continue
		print("   %-18s %4d props %6d meshes (%.1f each)" %
				[r[1], r[2], r[0], float(r[0]) / maxf(1.0, r[2])])


func _count_meshes(n: Node) -> int:
	var total := 1 if n is MeshInstance3D else 0
	for c in n.get_children():
		total += _count_meshes(c)
	return total


func _measure(station: Dictionary) -> void:
	cam.global_position = station["pos"]
	cam.look_at(station["look"])
	# let streaming, the light rig and the lerped fixtures settle first
	for i in WARMUP:
		await get_tree().process_frame
	var total := 0.0
	var worst := 0.0
	for i in SAMPLES:
		await get_tree().process_frame
		var ms := 1000.0 / maxf(1.0, Performance.get_monitor(
				Performance.TIME_FPS))
		total += ms
		worst = maxf(worst, ms)
	var avg := total / SAMPLES
	var objs := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var calls := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	# An empty frame is a broken run, not a fast one. Without this a scene
	# that fails to load reports six stations at thousands of fps and the
	# suite says PASS.
	var broken: bool = objs < MIN_OBJECTS
	if avg > FRAME_BUDGET_MS or broken:
		over_budget += 1
	print("%-24s %7d %7d %9d %8.2f %7.1f%s" %
			[station["name"], objs, calls, prims, avg, 1000.0 / avg,
			"  NOTHING RENDERED" if broken
			else ("  OVER" if avg > FRAME_BUDGET_MS else "")])
