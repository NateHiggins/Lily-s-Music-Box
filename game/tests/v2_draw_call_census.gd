extends "res://tests/v2_performance_matrix.gd"
## Where a station's draw calls come from. Diagnostic only (INERT): it changes
## nothing in the game and judges nothing; it is the instrument for the frame
## time work the performance matrix shows is owed.
##
## At one matrix station, at the heading that draws the most, it reads the
## frame's draw calls, then takes things away one at a time and reads again:
## every lamp's shadows, then each top-level part of the world, then the parts
## of the biggest of those. What a thing costs is what the count falls by when
## it is hidden. Counts, not timings, so the machine need not be quiet. It
## also counts what is standing in the tree: drawn instances and their
## surfaces by owner, lamps and how many of them cast shadows.
##
##   SHOT_DIR                where draw_call_census.json is written
##   ORISON_PERF_STATION     the station (default third_floor_crossing)
##   ORISON_CENSUS_DEPTH     how many levels to open under the biggest (default 2)
##
## Needs a real window, like the matrix: run -Windowed through the lane.

const CENSUS_SCHEMA := "orison.v2-draw-call-census.v1"
const SETTLE_FRAMES := 5
const OPEN_BIGGEST := 6

var _census_rows: Array[Dictionary] = []


func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	world = Runtime.instantiate()
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	if world.startup_failed:
		failures.append("the V2 world did not start")
		_leave()
		return
	player = world.player
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 30:
		await get_tree().process_frame
	var wanted := OS.get_environment("ORISON_PERF_STATION")
	if wanted.is_empty():
		wanted = "third_floor_crossing"
	var station := {}
	for candidate: Dictionary in STATIONS:
		if str(candidate.name) == wanted:
			station = candidate
	if station.is_empty():
		failures.append("no station named %s" % wanted)
		_leave()
		return
	var placed := _place(station)
	if not placed.ok:
		failures.append("%s: %s" % [wanted, placed.why])
		_leave()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not await _settle():
		failures.append("%s: streaming did not settle" % wanted)
	# The heading that draws the most.
	var heaviest := {"yaw": 0.0, "calls": -1}
	for index in HEADINGS:
		var yaw := TAU * float(index) / float(HEADINGS)
		var seen := await _read(placed.position, yaw)
		if int(seen.calls) > int(heaviest.calls):
			heaviest = {"yaw": yaw, "calls": seen.calls}
	var yaw: float = heaviest.yaw
	var whole := await _read(placed.position, yaw)
	print("[V2 CENSUS] %s, heading %d degrees: %d draw calls, %d primitives, %d objects" % [
		wanted, int(rad_to_deg(yaw)), whole.calls, whole.primitives, whole.objects])

	# 1. Shadows: every lamp's shadow off, then back.
	var lamps: Array[Light3D] = []
	for node in world.find_children("*", "Light3D", true, false):
		lamps.append(node as Light3D)
	var shadowed: Array[Light3D] = []
	for lamp in lamps:
		if lamp.shadow_enabled and lamp.is_visible_in_tree():
			shadowed.append(lamp)
	for lamp in shadowed:
		lamp.shadow_enabled = false
	var unshadowed := await _read(placed.position, yaw)
	for lamp in shadowed:
		lamp.shadow_enabled = true
	var lamp_kinds := {}
	for lamp in lamps:
		if lamp.is_visible_in_tree():
			var kind := lamp.get_class() + (" shadowed" if lamp.shadow_enabled else "")
			lamp_kinds[kind] = int(lamp_kinds.get(kind, 0)) + 1
	print("[V2 CENSUS] shadows: %d of %d calls are shadow passes (%d lamps cast them; lit lamps %s)" % [
		int(whole.calls) - int(unshadowed.calls), whole.calls, shadowed.size(), str(lamp_kinds)])

	# 2. Parts of the world, hidden one at a time; then inside the biggest.
	var depth := maxi(1, int(OS.get_environment("ORISON_CENSUS_DEPTH")) if not OS.get_environment("ORISON_CENSUS_DEPTH").is_empty() else 2)
	await _open(world, "", 1, depth, placed.position, yaw, int(whole.calls))
	_census_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.calls) > int(b.calls))
	for row: Dictionary in _census_rows.slice(0, 24):
		print("[V2 CENSUS] %6d calls %9d prims  %s%s" % [row.calls, row.primitives, "  ".repeat(int(row.level) - 1), row.path])

	# 3. What is standing in the tree, by owner.
	var owners := {}
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var drawn := node as GeometryInstance3D
		if not drawn.is_visible_in_tree():
			continue
		var owner_path := str(world.get_path_to(drawn)).get_slice("/", 0)
		var row: Dictionary = owners.get(owner_path, {"instances": 0, "surfaces": 0, "multimesh_instances": 0, "shadow_casters": 0})
		row.instances += 1
		if drawn is MeshInstance3D and (drawn as MeshInstance3D).mesh != null:
			row.surfaces += (drawn as MeshInstance3D).mesh.get_surface_count()
		elif drawn is MultiMeshInstance3D and (drawn as MultiMeshInstance3D).multimesh != null:
			var many := (drawn as MultiMeshInstance3D).multimesh
			row.surfaces += many.mesh.get_surface_count() if many.mesh != null else 0
			row.multimesh_instances += many.visible_instance_count if many.visible_instance_count >= 0 else many.instance_count
		if drawn.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			row.shadow_casters += 1
		owners[owner_path] = row
	var standing: Array = []
	for key: String in owners:
		standing.append(owners[key].merged({"owner": key}))
	standing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.surfaces) > int(b.surfaces))
	for row: Dictionary in standing.slice(0, 12):
		print("[V2 CENSUS] standing %6d surfaces in %6d instances (%d cast shadows)  %s" % [row.surfaces, row.instances, row.shadow_casters, row.owner])

	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		failures.append("SHOT_DIR is not set; nothing was written")
	else:
		DirAccess.make_dir_recursive_absolute(directory)
		var size := get_viewport().get_visible_rect().size
		var file := FileAccess.open(directory.path_join("draw_call_census.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({
			"schema": CENSUS_SCHEMA, "evidence_class": "INERT", "kind": "performance_diagnostic",
			"scope": "One station, one heading, the world as it stands at 20:00 on 10 Nov 1928. A part's cost is the fall in the frame's draw calls when it is hidden; hiding a part also removes it from every shadow pass, and culling can shift, so the parts do not add up to the whole.",
			"station": wanted, "yaw_degrees": rad_to_deg(yaw), "resolution": [int(size.x), int(size.y)],
			"whole": whole, "without_shadows": unshadowed, "shadow_lamps": shadowed.size(), "lit_lamps": lamp_kinds,
			"parts": _census_rows, "standing": standing, "failures": failures,
		}, "\t"))
		file.close()
	_leave()


## Put the player on the station at a heading, let the frame counters settle
## and read them.
func _read(at: Vector3, yaw: float) -> Dictionary:
	for i in SETTLE_FRAMES:
		player.velocity = Vector3.ZERO
		player.global_position = at
		player.rotation.y = yaw
		await get_tree().process_frame
	return {
		"calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}


## Hide each drawn child of `parent` in turn and record what the frame loses;
## then open the biggest of them the same way, down to `depth` levels.
func _open(parent: Node, prefix: String, level: int, depth: int, at: Vector3, yaw: float, whole_calls: int) -> void:
	var found: Array[Dictionary] = []
	for child in parent.get_children():
		var part := child as Node3D
		if part == null or not part.visible or part == player:
			continue
		if part.find_children("*", "GeometryInstance3D", true, false).is_empty() and not (part is GeometryInstance3D):
			continue
		part.visible = false
		var without := await _read(at, yaw)
		part.visible = true
		var lost := whole_calls - int(without.calls)
		if lost <= 0:
			continue
		var row := {"path": prefix + str(part.name), "level": level, "calls": lost,
			"primitives": 0, "share": snappedf(float(lost) / float(maxi(1, whole_calls)), 0.001), "node": part}
		found.append(row)
	# Primitives lost are read against a fresh whole, since the counters drift.
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.calls) > int(b.calls))
	for row: Dictionary in found:
		var part: Node3D = row.node
		row.erase("node")
		_census_rows.append(row)
		if level < depth and found.find(row) < OPEN_BIGGEST and int(row.calls) > whole_calls / 50:
			await _open(part, str(row.path) + "/", level + 1, depth, at, yaw, whole_calls)
