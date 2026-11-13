extends "res://tests/v2_performance_matrix.gd"
## Where a station's draw calls come from. Diagnostic only (INERT): it changes
## nothing in the game and judges nothing; it is the instrument for the frame
## time work the performance matrix shows is owed.
##
## At one matrix station, at the heading that draws the most, it reads the
## frame's draw calls, then takes things away one group at a time and reads
## again: the lamps' shadows (all, then by kind of lamp), each large part of
## the world, and the building storey by storey. What a group costs is what
## the count falls by when it is gone. Counts, not timings, so the machine
## need not be quiet.
##
## The frame's count is not steady: it swings by tens of thousands for a few
## frames after anything moves or is shown or hidden (the first run of this
## census read one swollen frame as its whole and so charged every part with
## the swing). So every reading here lets the frame settle and then takes the
## middle of several frames, the whole is read again between groups, and each
## row carries the spread it was read in. A fall smaller than the spread is
## nothing.
##
##   SHOT_DIR                  where draw_call_census.json is written
##   ORISON_PERF_STATION       the station (default third_floor_crossing)
##   ORISON_CENSUS_BUDGET_S    seconds it may spend taking things away (default 240)
##
## Rows are printed as they are read, so a run that is cut short still leaves
## what it had. Needs a real window, like the matrix: run -Windowed through
## the lane.

const CENSUS_SCHEMA := "orison.v2-draw-call-census.v2"
const SETTLE_FRAMES := 6
const TAKE_FRAMES := 9
const PART_MIN_INSTANCES := 20

var _rows: Array[Dictionary] = []
var _at := Vector3.ZERO
var _yaw := 0.0
var _budget_ends := 0
var _cut_short := false


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
	_at = placed.position
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not await _settle():
		failures.append("%s: streaming did not settle" % wanted)
	# The heading that draws the most, each read settled.
	var heaviest := -1
	for index in HEADINGS:
		_yaw = TAU * float(index) / float(HEADINGS)
		var seen := await _read(30)
		if int(seen.calls) > heaviest:
			heaviest = int(seen.calls)
			station["yaw"] = _yaw
	_yaw = float(station.yaw)
	var whole := await _read(40)
	print("[V2 CENSUS] %s, heading %d degrees: %d draw calls (%d to %d over %d frames), %d primitives, %d objects" % [
		wanted, int(rad_to_deg(_yaw)), whole.calls, whole.calls_low, whole.calls_high, TAKE_FRAMES, whole.primitives, whole.objects])
	var budget := float(OS.get_environment("ORISON_CENSUS_BUDGET_S")) if not OS.get_environment("ORISON_CENSUS_BUDGET_S").is_empty() else 240.0
	_budget_ends = Time.get_ticks_msec() + int(budget * 1000.0)

	# 1. Shadows: all lamps, then each kind of lamp alone.
	var lamps: Array[Light3D] = []
	for node in world.find_children("*", "Light3D", true, false):
		var lamp := node as Light3D
		if lamp.is_visible_in_tree():
			lamps.append(lamp)
	var lamp_kinds := {}
	for lamp in lamps:
		var kind := lamp.get_class() + (" shadowed" if lamp.shadow_enabled else "")
		lamp_kinds[kind] = int(lamp_kinds.get(kind, 0)) + 1
	print("[V2 CENSUS] lit lamps: %s" % str(lamp_kinds))
	# Which lamps cast shadows, and how far off they are: the building ranks
	# eight local shadow casters (LightRig) and fades service lights by
	# distance, so a shadowed lamp far from the eye is one neither governs.
	var roster: Array[Dictionary] = []
	for lamp in lamps:
		if not lamp.shadow_enabled:
			continue
		var reach := 0.0
		if lamp is OmniLight3D:
			reach = (lamp as OmniLight3D).omni_range
		elif lamp is SpotLight3D:
			reach = (lamp as SpotLight3D).spot_range
		roster.append({"path": str(world.get_path_to(lamp)), "kind": lamp.get_class(),
			"metres_away": snappedf(lamp.global_position.distance_to(_at), 0.1), "range_m": snappedf(reach, 0.1),
			"fades_with_distance": lamp.distance_fade_enabled, "energy": snappedf(lamp.light_energy, 0.01)})
	roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.metres_away) < float(b.metres_away))
	for row: Dictionary in roster:
		print("[V2 CENSUS] shadow lamp %5.1f m away, range %4.1f m, %s  %s" % [row.metres_away, row.range_m,
			"fades" if row.fades_with_distance else "no fade", row.path])
	for kind: String in ["", "OmniLight3D", "SpotLight3D", "DirectionalLight3D"]:
		var mine: Array[Light3D] = []
		for lamp in lamps:
			if lamp.shadow_enabled and (kind.is_empty() or lamp.get_class() == kind):
				mine.append(lamp)
		if mine.is_empty():
			continue
		var shadows_off := func() -> void:
			for lamp in mine:
				lamp.shadow_enabled = false
		var shadows_on := func() -> void:
			for lamp in mine:
				lamp.shadow_enabled = true
		whole = await _take_away("shadows of %s (%d lamps)" % ["every lamp" if kind.is_empty() else kind, mine.size()],
			"shadows", whole, shadows_off, shadows_on)

	# 2. The large parts of the world.
	for child in world.get_children():
		var part := child as Node3D
		if part == null or not part.visible or part == player:
			continue
		if part.find_children("*", "GeometryInstance3D", true, false).size() < PART_MIN_INSTANCES:
			continue
		var hide_part := func() -> void:
			part.visible = false
		var show_part := func() -> void:
			part.visible = true
		whole = await _take_away(str(part.name), "part", whole, hide_part, show_part)

	# 3. The building, storey by storey: its children carry their storey in
	# their names (B1_, F01_ .. F06_, ROOF); the rest is the shell and the
	# fittings that belong to no one storey.
	var building := world.get_node_or_null("OrisonV2Blockout") as Node3D
	if building != null:
		var storeys := {}
		var tag := RegEx.new()
		tag.compile("^(B1|F0[0-9]|ROOF)_")
		for child in building.get_children():
			var piece := child as Node3D
			if piece == null or not piece.visible:
				continue
			var found := tag.search(str(piece.name))
			var storey := found.get_string(1) if found != null else "unlettered"
			if not storeys.has(storey):
				storeys[storey] = []
			(storeys[storey] as Array).append(piece)
		var names := storeys.keys()
		names.sort()
		for storey: String in names:
			var pieces: Array = storeys[storey]
			var hide_storey := func() -> void:
				for piece: Node3D in pieces:
					piece.visible = false
			var show_storey := func() -> void:
				for piece: Node3D in pieces:
					piece.visible = true
			whole = await _take_away("building, %s (%d pieces)" % [storey, pieces.size()], "storey", whole, hide_storey, show_storey)
			# The same storey still drawn but casting no shadow: its share of
			# the shadow passes alone.
			var casters: Array = []
			for piece: Node3D in pieces:
				var drawn_here: Array[Node] = piece.find_children("*", "GeometryInstance3D", true, false)
				if piece is GeometryInstance3D:
					drawn_here.append(piece)
				for node in drawn_here:
					var drawn := node as GeometryInstance3D
					if drawn.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
						casters.append([drawn, drawn.cast_shadow])
			if not casters.is_empty():
				var cast_none := func() -> void:
					for pair: Array in casters:
						(pair[0] as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var cast_again := func() -> void:
					for pair: Array in casters:
						(pair[0] as GeometryInstance3D).cast_shadow = int(pair[1]) as GeometryInstance3D.ShadowCastingSetting
				whole = await _take_away("building, %s, drawn but casting no shadow (%d casters)" % [storey, casters.size()],
					"storey_shadow", whole, cast_none, cast_again)

	# 4. What is standing in the tree, by owner.
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
	for row: Dictionary in standing.slice(0, 10):
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
			"scope": "One station, one heading, the world as it stands at 20:00 on 10 Nov 1928. A group's cost is the fall in the frame's draw calls when it is taken away, each reading the middle of %d settled frames. Hiding a group also removes it from every shadow pass, and culling can shift, so the groups do not add up to the whole. A fall inside a row's spread is nothing." % TAKE_FRAMES,
			"station": wanted, "yaw_degrees": rad_to_deg(_yaw), "resolution": [int(size.x), int(size.y)],
			"whole": whole, "lit_lamps": lamp_kinds, "shadow_lamps": roster, "rows": _rows, "standing": standing,
			"cut_short": _cut_short, "budget_s": budget, "failures": failures,
		}, "\t"))
		file.close()
	if _cut_short:
		print("[V2 CENSUS] cut short at its time budget of %d s; the rows above are what it read" % int(budget))
	_leave()


## Hold the player on the station, let the frame settle, then take the middle
## of several frames.
func _read(settle := SETTLE_FRAMES) -> Dictionary:
	for i in settle:
		_hold()
		await get_tree().process_frame
	var calls: Array[int] = []
	var primitives: Array[int] = []
	var objects: Array[int] = []
	for i in TAKE_FRAMES:
		_hold()
		await get_tree().process_frame
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		objects.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	calls.sort()
	primitives.sort()
	objects.sort()
	return {"calls": calls[calls.size() / 2], "calls_low": calls[0], "calls_high": calls[-1],
		"primitives": primitives[primitives.size() / 2], "objects": objects[objects.size() / 2]}


func _hold() -> void:
	player.velocity = Vector3.ZERO
	player.global_position = _at
	player.rotation.y = _yaw


## Take one group away, read, put it back, read the whole again. Returns the
## fresh whole. Skips, and says so once, when the time budget is spent.
func _take_away(label: String, kind: String, whole: Dictionary, away: Callable, back: Callable) -> Dictionary:
	if Time.get_ticks_msec() > _budget_ends:
		_cut_short = true
		return whole
	away.call()
	var without := await _read()
	back.call()
	var again := await _read()
	# Measured against the nearer of the two wholes around it.
	var base := maxi(int(whole.calls), int(again.calls)) if absi(int(whole.calls) - int(again.calls)) < 2000 else int(again.calls)
	var spread := maxi(int(without.calls_high) - int(without.calls_low), int(again.calls_high) - int(again.calls_low))
	var row := {"label": label, "kind": kind, "calls": base - int(without.calls), "spread": spread,
		"share": snappedf(float(base - int(without.calls)) / float(maxi(1, base)), 0.001),
		"primitives": int(again.primitives) - int(without.primitives), "objects": int(again.objects) - int(without.objects),
		"whole_before": whole.calls, "whole_after": again.calls}
	_rows.append(row)
	print("[V2 CENSUS] %7d calls (%4.1f%%, spread %5d) %10d prims  %s" % [row.calls, float(row.share) * 100.0, spread, row.primitives, label])
	return again
