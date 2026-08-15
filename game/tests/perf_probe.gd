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
const PINNED_LIGHT_BUDGET := 16
const PINNED_SHADOW_BUDGET := 16
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
	# THE DENSEST LIT ROOM IN THE GAME, added when the light budget came
	# off. Sixteen fixtures inside one 15.5 x 9.2 m box, all of them
	# exempt from the storey gate, all of them in range of the same merged
	# floor and ceiling meshes — which is precisely the case ACTIVE_N was
	# invented to avoid and therefore the one that has to be measured now
	# that nothing avoids it. Standing just inside the red door looking
	# west down the whole room, which sees every one of them at once.
	{"name": "harukiya (16 fixtures)", "pos": Vector3(3.0, -1.39, 34.0),
	 "look": Vector3(-11.0, -1.9, 33.0)},
	# THE WORST CASE FOR THE ARCADE. Twelve cabinets are placed across the
	# building, but they are scattered one or two per venue rather than standing
	# in a row, and each is gated live at 9 m - so the question is not what
	# twelve cost, it is what the densest reachable point costs. Solved by
	# sampling the F01 plane at 0.25 m: five machines see this spot, and no
	# point sees six. Five 480x360 boards, five phosphor viewports accumulating
	# on top of them, five 3D worlds stepping their own physics.
	{"name": "arcade cluster (5 live)", "pos": Vector3(0.15, 1.72, 29.65),
	 "look": Vector3(3.55, 1.2, 35.35)},
	# M0.5 final-map stations. These are the same production viewpoints used
	# by PassageShot so beauty evidence and performance evidence cannot quietly
	# measure different ownership states.
	{"name": "passage throat reveal", "pos": Vector3(14.0, 1.68, 33.2),
	 "look": Vector3(14.0, 1.52, 48.0)},
	{"name": "passage hall southbound", "pos": Vector3(14.0, 1.68, 39.5),
	 "look": Vector3(14.0, 1.48, 61.0)},
	{"name": "passage hall northbound", "pos": Vector3(14.0, 1.68, 63.6),
	 "look": Vector3(14.0, 1.48, 42.0)},
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
	# And without THIS it measures the wall clock: the day/night director
	# opens the bar, lights the windows and sends eighteen residents home
	# in the evening, and interior stations gain thousands of objects
	# against a morning run (harukiya measured 3,975 objects at 10:00 and
	# 7,662 at 19:20 on the same build). Every other harness pins the
	# canonical 03:00; the benchmark was the last one comparing runs
	# across hours. DAYNIGHT_FORCE still overrides for deliberate
	# time-of-day measurement.
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT", "0")
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	# P5 same-build control. The project requests CPU/Embree occlusion culling,
	# but currently authors zero OccluderInstance3D nodes. This switch prices the
	# empty pass without changing a project setting between builds.
	if OS.get_environment("PERF_OCCLUSION_OFF") == "1":
		get_viewport().use_occlusion_culling = false
		print("PERF OCCLUSION CONTROL: disabled; %d OccluderInstance3D nodes"
				% root.find_children(
						"*", "OccluderInstance3D", true, false).size())
	# Pin the comparison in executable code. Environment overrides are applied
	# before BuildingRoot's production profile and cannot be trusted as proof of
	# the resolved value; the benchmark owns the value it reports.
	root.light_rig.set_budgets(PINNED_LIGHT_BUDGET, PINNED_SHADOW_BUDGET)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false
	await get_tree().create_timer(1.0).timeout
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	# Perf is a free-camera test.  Without this handoff BuildingRoot keeps
	# streaming around the player parked in the lobby while the benchmark
	# camera visits F04, 4B and the roof.  That once made an empty 4B look
	# like a large optimization and made every non-lobby station measure the
	# wrong collection of floors and props.
	root.view_override = cam
	var stations: Array = STATIONS
	var station_filter := OS.get_environment("PERF_STATION")
	if station_filter != "":
		stations = STATIONS.filter(func(station):
			return str(station.name) == station_filter)
		if stations.is_empty():
			printerr("PERF: unknown PERF_STATION=%s" % station_filter)
			get_tree().quit(1)
			return
		print("PERF: focused station %s" % station_filter)
	# Gate A comparison hook. The new host/kiosk blockout is deliberately in a
	# separate STREET proxy batch, so the same imported build, light state and
	# live weather can measure it on and off. This is diagnostic only; ordinary
	# runs submit the gateway and production has no corresponding toggle.
	if OS.get_environment("PERF_GATEWAY_OFF") == "1":
		var hidden := 0
		for candidate in root.floor_nodes["F01"].find_children(
				"*", "GeometryInstance3D", true, false):
			if String(candidate.name).contains(
					"_retail_passage_proxy_gateway_"):
				candidate.visible = false
				hidden += 1
		print("PERF GATEWAY CONTROL: %d blockout buffers hidden" % hidden)
	# T5 comparison hook. The restored shelter is deliberately four local
	# material buffers plus one in-world sign, so a paired fresh-process run can
	# price that exact submission cost without rebuilding or touching collision.
	# The enamel backing is one instance in ExteriorDetailPass's pre-existing box
	# draw and therefore cannot add a submission; leaving it in the control is
	# the stricter comparison.
	if OS.get_environment("PERF_TRANSIT_SHELTER_OFF") == "1":
		var shelter_hidden := 0
		for candidate in root.floor_nodes["F01"].find_children(
				"*", "GeometryInstance3D", true, false):
			if String(candidate.name).contains("_transit_shelter_"):
				candidate.visible = false
				shelter_hidden += 1
		var sign := root.find_child("TransitShelterStopSign", true, false)
		if sign:
			sign.visible = false
			shelter_hidden += 1
		print("PERF TRANSIT SHELTER CONTROL: %d visual owners hidden"
				% shelter_hidden)
	# T2d comparison hook. Production keeps one shared wet-road reflection
	# batch; this removes only that draw so a fresh-process pair can price it.
	if OS.get_environment("PERF_TRAFFIC_POOLS_OFF") == "1":
		root.street_traffic._headlight_pools.visible = false
		print("PERF TRAFFIC POOL CONTROL: one shared draw hidden")
	print("PERF: viewport %s; resolved light/shadow budget %d/%d" % [
			get_viewport().get_visible_rect().size,
			root.light_rig._active_budget, root.light_rig._shadow_budget])
	apply_shadow_policy(root, self)
	# Visit every station once before timing anything. Godot compiles
	# shaders lazily on first draw, so whichever station goes first
	# otherwise absorbs the cost of the whole building's materials and
	# reports several times its true frame time.
	for s in stations:
		cam.global_position = s["pos"]
		cam.look_at(s["look"])
		for i in WARMUP:
			await get_tree().process_frame
	_report_mesh_census()
	if OS.get_environment("PERF_DIAG_ONLY") == "1":
		await _diagnose_corridor_submissions()
		get_tree().quit(0)
		return
	print("%-24s %7s %7s %9s %8s %7s" %
			["station", "objs", "calls", "prims", "ms", "fps"])
	for s in stations:
		await _measure(s)
	print("PERF RESULT: %s (%d/%d stations over %.1f ms)" %
			["PASS" if over_budget == 0 else "FAIL", over_budget,
			stations.size(), FRAME_BUDGET_MS])
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
		if c is FunctionalProp or c is DoorProp:
			prop_nodes += 1
			props += _count_meshes(c)
	print("PERF census: %d floor meshes, %d prop meshes across %d props "
			% [per_floor, props, prop_nodes] +
			"(%.1f each), %d total" %
			[float(props) / maxf(1.0, prop_nodes), per_floor + props])
	var by_type := {}
	for c in root.get_children():
		if c is FunctionalProp or c is DoorProp:
			var k: String = c.prop_type if c is FunctionalProp else "door"
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


## DIAGNOSTIC ONLY — inert unless PERF_SHADOW_OFF is set, so production
## behaviour is unchanged and no visual policy is committed by measuring one.
##
## Takes comma-separated node-name substrings and clears cast_shadow on every
## matching GeometryInstance3D. Buffers are merged per (floor, category,
## material), so a token like `_furnish_` selects a SOURCE CATEGORY and
## `_furnish_porcelain` selects one material within it — which is the finest
## grain a runtime test can honestly claim. Anything narrower than a buffer
## has to be proved by splitting the buffer in the builder, not here.
##
## `*` matches everything. That is the control, NOT a policy: the brief bans
## global shadow suppression as a shipping option and allows it only as the
## upper bound the real policies are scored against.
##
## Shared with shadow_policy_shot.gd so the render and the measurement can
## never be suppressing different sets. Reports what it touched, by buffer,
## because a number attributed to the wrong category is worse than no number.
static func apply_shadow_policy(scene_root: Node, ctx: Node) -> Dictionary:
	var out := {"tokens": "", "instances": 0, "buffers": {}}
	var spec := OS.get_environment("PERF_SHADOW_OFF")
	if spec == "":
		return out
	# A leading `-` excludes and always wins, so a policy can say "the shop
	# stock but not the Passage shell" without listing every material. The
	# shell is architecture and architecture is out of scope by instruction.
	var tokens: Array[String] = []
	var block: Array[String] = []
	for t in spec.split(","):
		var s := t.strip_edges()
		if s.begins_with("-"):
			block.append(s.substr(1))
		elif s != "":
			tokens.append(s)
	if tokens.is_empty():
		return out
	var hit := {}
	var n := _suppress_shadows(scene_root, tokens, hit, block)
	out["tokens"] = spec
	out["instances"] = n
	out["buffers"] = hit
	var rows: Array = []
	for k in hit:
		rows.append([hit[k], k])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("PERF SHADOW POLICY [%s]: %d instances suppressed across %d buffers"
			% [spec, n, hit.size()])
	for r in rows:
		print("   SHADOW-OFF %-46s x%d" % [r[1], r[0]])
	if ctx != null:
		pass
	return out


static func _suppress_shadows(node: Node, tokens: Array[String],
		hit: Dictionary, block: Array[String]) -> int:
	# Arcade cabinets own their World3D; their shadows are not in this frame
	# and suppressing them would change the cabinets rather than the building.
	if node is SubViewport:
		return 0
	var n := 0
	if node is GeometryInstance3D:
		var g := node as GeometryInstance3D
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var name := String(g.name)
			var excluded := false
			for b in block:
				if name.findn(b) >= 0:
					excluded = true
					break
			if not excluded:
				for t in tokens:
					if t == "*" or name.findn(t) >= 0:
						g.cast_shadow = \
								GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						hit[name] = int(hit.get(name, 0)) + 1
						n += 1
						break
	for c in node.get_children():
		n += _suppress_shadows(c, tokens, hit, block)
	return n


## RenderingServer's "objects" count is submission work, not scene-tree
## objects: one mesh can appear again in several shadow views.  These toggles
## isolate those repeat submissions from actual visible content and make the
## forty-thousand-object corridor actionable instead of mysterious.
func _diagnose_corridor_submissions() -> void:
	# Whichever station is currently worst, not whichever was worst when this
	# was written. PERF_DIAG_STATION takes any substring of a station name;
	# without it the corridor is kept as the default this was built for.
	var wanted := OS.get_environment("PERF_DIAG_STATION")
	var station: Dictionary = STATIONS[2]
	if wanted != "":
		for s in STATIONS:
			if String(s["name"]).findn(wanted) >= 0:
				station = s
				break
	print("\nPERF DIAG: %s submission decomposition" % station["name"])
	await _diag_snapshot("baseline", station)
	# Freeze only BuildingRoot's streaming decision after the corridor has
	# settled. Otherwise its physics tick quite correctly restores prop and
	# floor visibility while this diagnostic is trying to suppress them.
	root.set_physics_process(false)

	# And freeze the cabinets, which stream on _process rather than physics and
	# so survived that. Every list below is held across an await, and an arcade
	# machine whose camera has been away long enough gives its whole world back -
	# lights, meshes and all - leaving this function holding freed references. It
	# died three snapshots in, twice, before reaching the two that matter most.
	# Guarding each access would work; not moving the furniture mid-measurement
	# is better, and a frozen scene is what a benchmark wanted anyway.
	# Walk the whole tree, not root's children: cabinets are spawned by ArcadeRow
	# from the layout's furniture and live under their floor node, so the obvious
	# loop over root.get_children() finds none of them.
	_freeze_cabinets(root)

	var lights: Array[Light3D] = []
	_collect_lights(root, lights)
	var light_shadows := PackedByteArray()
	for light in lights:
		light_shadows.append(1 if light.shadow_enabled else 0)
		light.shadow_enabled = false
	await _diag_snapshot("all light shadows off", station)
	for i in lights.size():
		if is_instance_valid(lights[i]):
			lights[i].shadow_enabled = light_shadows[i] == 1

	var light_visibility := PackedByteArray()
	for light in lights:
		light_visibility.append(1 if light.visible else 0)
		light.visible = false
	await _diag_snapshot("all illumination hidden", station)
	for i in lights.size():
		if is_instance_valid(lights[i]):
			lights[i].visible = light_visibility[i] == 1

	var geometry: Array[GeometryInstance3D] = []
	_collect_geometry(root, geometry)
	var cast_modes := PackedInt32Array()
	for item in geometry:
		cast_modes.append(item.cast_shadow)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _diag_snapshot("all geometry cast off", station)
	for i in geometry.size():
		if is_instance_valid(geometry[i]):
			geometry[i].cast_shadow = cast_modes[i]

	var props: Array[Node3D] = []
	var prop_visibility := PackedByteArray()
	for child in root.get_children():
		if child is FunctionalProp:
			props.append(child)
			prop_visibility.append(1 if child.visible else 0)
			child.visible = false
	await _diag_snapshot("functional props hidden", station)
	for i in props.size():
		if is_instance_valid(props[i]):
			props[i].visible = prop_visibility[i] == 1

	# Only 22 of 56 prop scripts call merge_static(), and the census says props
	# still average 9.1 meshes each. Before anyone spends a week adding merges
	# family by family, this says what the whole exercise is worth: batch every
	# prop in place, by material, and re-measure. An upper bound, because it
	# ignores whether a given family can actually afford to lose its separate
	# nodes - animated parts, retextured surfaces, anything that moves.
	#
	# THE ONE THAT DISCRIMINATES. Everything above hides geometry, so a saving
	# could be rendering or could be the script attached to it. This leaves every
	# prop on screen, exactly as drawn, and only stops it thinking. If the frame
	# collapses anyway, the atrium is 604 props running _process and no amount of
	# LOD, batching or shadow policy will touch it.
	var ticking: Array[Node] = []
	for child in root.get_children():
		if child is FunctionalProp and child.is_processing():
			ticking.append(child)
			child.set_process(false)
	print("   (silenced %d prop _process callbacks, all still drawn)" % ticking.size())
	await _diag_snapshot("props drawn but not ticking", station)
	for node in ticking:
		if is_instance_valid(node):
			node.set_process(true)

	# If it is not draw calls, it is what those calls draw. The atrium submits
	# ~38M primitives because it sees seven storeys of props at full detail from
	# twenty metres, and nothing in this project has ever set a visibility range.
	# Fading props out past 12 m is not a shippable policy - it is the cheapest
	# possible stand-in for prop LODs, to find out whether that whole avenue is
	# worth opening before anyone authors a single reduced mesh.
	var geo2: Array[GeometryInstance3D] = []
	for child in root.get_children():
		if child is FunctionalProp:
			_collect_geometry(child, geo2)
	for item in geo2:
		item.visibility_range_end = 12.0
		item.visibility_range_end_margin = 2.0
	await _diag_snapshot("props culled past 12 m", station)
	for item in geo2:
		if is_instance_valid(item):
			item.visibility_range_end = 0.0

	# Destructive, so it goes last.
	var merged := 0
	for child in root.get_children():
		if child is FunctionalProp:
			merged += child.merge_static(child)
	print("   (merged %d meshes away)" % merged)
	await _diag_snapshot("every prop batched", station)


func _diag_snapshot(label: String, station: Dictionary) -> void:
	cam.global_position = station.pos
	cam.look_at(station.look)
	for i in WARMUP:
		await get_tree().process_frame
	var total := 0.0
	for i in 45:
		await get_tree().process_frame
		total += 1000.0 / maxf(1.0, Performance.get_monitor(
				Performance.TIME_FPS))
	# `proc` is TIME_PROCESS, and it is NOT script time - it is the whole process
	# step, engine rendering submission included, which is why it tracks the
	# frame almost exactly. Reading it as "GDScript" led straight to the wrong
	# conclusion once already; the "props drawn but not ticking" row is what
	# actually separates the two, and it says user scripts are not the cost.
	#
	# Godot 4 exposes no GPU timer to GDScript, so watch the card from outside
	# with nvidia-smi. Doing that showed an RTX 4080 at 210-1200 MHz of 3105 and
	# 19-52% utilisation through an 80 ms frame: this is CPU-bound.
	print("   %-28s %7d objs %7d calls %8.2f ms  (proc %5.2f  phys %5.2f)" % [
		label,
		RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		total / 45.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])


func _collect_lights(node: Node, into: Array[Light3D]) -> void:
	if node is Light3D:
		into.append(node)
	for child in node.get_children():
		_collect_lights(child, into)


func _collect_geometry(node: Node, into: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect_geometry(child, into)


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


## Stop the arcade streaming for the duration of a diagnostic. A machine that
## unloads mid-run frees lights and meshes the caller is still holding, and it is
## timing-dependent: at 37 ms a frame two snapshots fit inside the unload delay,
## at 73 ms they do not, so this failed only on the slower runs.
func _freeze_cabinets(node: Node) -> void:
	if node is ArcadeCabinetProp:
		node.set_process(false)
	for child in node.get_children():
		_freeze_cabinets(child)
