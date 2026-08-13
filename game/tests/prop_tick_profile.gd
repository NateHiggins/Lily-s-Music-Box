extends Node
## WHERE the prop-tick milliseconds actually live, by source class.
##
##     godot --path game --resolution 2560x1440 res://tests/PropTickProfile.tscn
##
## The northbound diagnostic says silencing every FunctionalProp _process
## recovers ~5 ms, and the rejected off-screen gate proved the recoverable
## part is NOT the hidden props (they were worth ~0.05 ms between them).
## So the cost is a small number of expensive classes, and any narrow,
## lifecycle-correct reduction has to know which ones. This measures that,
## two ways, from the same pinned station:
##
##  1. DIRECT: every ticking prop's _process is called K times under a
##     microsecond clock, per class. Attribution, not inference — the sum
##     over classes should land near the diagnostic's ceiling. (Calling
##     _process by hand advances cosmetic state; this scene never saves
##     and quits when done, so nothing leaks.)
##  2. TREATMENT: per class, set_process(false) on its members, measure
##     the station frame time against an in-run baseline, restore.
##     Validates the direct number against reality for the top classes.
##
## The station, the pinned 16/16 budget and the measurement loop are the
## perf harness's own, so these numbers and the benchmark's cannot
## quietly describe different configurations.

const PERF := preload("res://tests/perf_probe.gd")
const WARMUP := 30
const SAMPLES := 45
const DIRECT_CALLS := 120

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	root.light_rig.set_budgets(PERF.PINNED_LIGHT_BUDGET,
			PERF.PINNED_SHADOW_BUDGET)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false
	await get_tree().create_timer(1.5).timeout
	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	var station: Dictionary = PERF.STATIONS[10]
	assert(String(station["name"]).contains("northbound"))
	cam.global_position = station["pos"]
	cam.look_at(station["look"])
	print("[TICKPROF] station %s; resolved budget %d/%d" % [station["name"],
			root.light_rig._active_budget, root.light_rig._shadow_budget])
	for i in WARMUP:
		await get_tree().process_frame

	# The population: ticking FunctionalProps, grouped by prop_type.
	var by_class := {}
	var props: Array = []
	_collect(root, props)
	for p in props:
		if not p.is_processing():
			continue
		var k: String = String(p.prop_type)
		if not by_class.has(k):
			by_class[k] = {"props": [], "visible": 0}
		by_class[k]["props"].append(p)
		if p.is_visible_in_tree():
			by_class[k]["visible"] += 1

	# 1. DIRECT per-class cost.
	print("[TICKPROF] %-20s %5s %4s %10s %10s"
			% ["class", "count", "vis", "us/call", "ms/frame"])
	var rows: Array = []
	var direct_total := 0.0
	for k in by_class:
		var members: Array = by_class[k]["props"]
		var t0 := Time.get_ticks_usec()
		for i in DIRECT_CALLS:
			for p in members:
				p._process(0.016666)
		var per_call := float(Time.get_ticks_usec() - t0) / DIRECT_CALLS
		var ms_frame := per_call / 1000.0
		direct_total += ms_frame
		rows.append([ms_frame, k, members.size(), by_class[k]["visible"],
				per_call / maxf(1.0, members.size())])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		print("[TICKPROF] %-20s %5d %4d %10.2f %10.3f"
				% [r[1], r[2], r[3], r[4], r[0]])
	print("[TICKPROF] DIRECT TOTAL %.3f ms/frame across %d classes"
			% [direct_total, rows.size()])

	# 2. TREATMENT: frame time with each of the top classes silenced.
	var base_ms := await _measure()
	print("[TICKPROF] baseline (all ticking)      %7.2f ms" % base_ms)
	for r in rows:
		var k: String = r[1]
		var members: Array = by_class[k]["props"]
		for p in members:
			p.set_process(false)
		var ms := await _measure()
		for p in members:
			if is_instance_valid(p):
				p.set_process(true)
		print("[TICKPROF] without %-20s %7.2f ms  (delta %+.2f)"
				% [k, ms, ms - base_ms])
	var base2 := await _measure()
	print("[TICKPROF] baseline recheck            %7.2f ms" % base2)
	var all_members: Array = []
	for k in by_class:
		all_members.append_array(by_class[k]["props"])
	for p in all_members:
		p.set_process(false)
	var none_ms := await _measure()
	print("[TICKPROF] without ALL prop ticks      %7.2f ms  (delta %+.2f)"
			% [none_ms, none_ms - (base_ms + base2) * 0.5])
	get_tree().quit(0)


func _measure() -> float:
	for i in 10:
		await get_tree().process_frame
	var total := 0.0
	for i in SAMPLES:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		total += (Time.get_ticks_usec() - t0) / 1000.0
	return total / SAMPLES


func _collect(n: Node, out: Array) -> void:
	if n is FunctionalProp:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
