extends Node
## How much per-frame work is spent on props the player cannot see.
##
##     godot --path game res://tests/PropTickProbe.tscn
##
## `_apply_visibility` (building_root.gd:1478) ALREADY decides, per prop and
## per station, whether it should be shown: active storey, atrium eye,
## exterior view, and Passage-vs-Orison zone ownership via the
## `passage_runtime` group. Nothing consumes that decision for processing, so
## a prop hidden on a foreign floor or in the wrong zone keeps running
## `_process` every frame.
##
## This measures the gap rather than assuming it: at each of the eleven perf
## stations, how many props are invisible AND still ticking, and what they
## are. Stations come from perf_probe so the census cannot drift away from
## the benchmark it is meant to explain.

const PERF := preload("res://tests/perf_probe.gd")

var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout

	var eye := Node3D.new()
	add_child(eye)
	root.view_override = eye

	var props: Array = []
	_collect(root, props)
	var ticking := 0
	for p in props:
		if p.is_processing():
			ticking += 1
	print("[TICK] %d FunctionalProps in the building, %d with _process enabled"
			% [props.size(), ticking])
	print("[TICK] %-26s %6s %6s %6s %6s"
			% ["station", "props", "vis", "hidden", "WASTE"])

	var totals := {}
	for s in PERF.STATIONS:
		eye.global_position = s["pos"]
		# _apply_visibility runs off the override's position, so give the
		# tree a physics frame to actually run building_root._physics_process
		# rather than trusting a hand-called copy of the same logic.
		await get_tree().physics_frame
		await get_tree().physics_frame
		var vis := 0
		var waste := 0
		var by_type := {}
		for p in props:
			if p.visible:
				vis += 1
			elif p.is_processing():
				waste += 1
				var k: String = String(p.prop_type)
				by_type[k] = int(by_type.get(k, 0)) + 1
				totals[k] = int(totals.get(k, 0)) + 1
		print("[TICK] %-26s %6d %6d %6d %6d"
				% [String(s["name"]).substr(0, 26), props.size(), vis,
				props.size() - vis, waste])
		var rows: Array = []
		for k in by_type:
			rows.append([by_type[k], k])
		rows.sort_custom(func(a, b): return a[0] > b[0])
		var head := ""
		for i in mini(6, rows.size()):
			head += "%s x%d  " % [rows[i][1], rows[i][0]]
		if head != "":
			print("[TICK]      %s" % head)

	var rows2: Array = []
	for k in totals:
		rows2.append([totals[k], k])
	rows2.sort_custom(func(a, b): return a[0] > b[0])
	print("\n[TICK] wasted ticks summed over all 11 stations, by prop type:")
	for r in rows2:
		print("[TICK]   %-24s %5d" % [r[1], r[0]])
	get_tree().quit(0)


func _collect(n: Node, out: Array) -> void:
	if n is FunctionalProp:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
