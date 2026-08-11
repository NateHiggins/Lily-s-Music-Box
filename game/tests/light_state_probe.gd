extends Node
## What every apartment fixture is actually set to, at a fixed hour.
##
##     DAYNIGHT_FORCE=night godot --headless --path game res://tests/LightStateProbe.tscn
##
## Written because twelve of twenty-eight rooms on F02 render effectively black
## and LightingAudit passes: the audit checks fixture COVERAGE, never brightness.
## A room can hold three correctly-mapped fixtures and still be a black frame.

func _ready() -> void:
	var root: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.2).timeout
	root.show_all_floors = true
	await get_tree().create_timer(0.6).timeout

	var rows: Array = []
	for f in get_tree().get_nodes_in_group("light_fixtures"):
		var n := String(f.name)
		var light: Light3D = null
		for c in f.find_children("*", "Light3D", true, false):
			light = c
			break
		if light == null:
			rows.append([n, f.prop_type, "NO LIGHT NODE", 0.0, 0.0, false])
			continue
		rows.append([n, f.prop_type, "",
				light.light_energy,
				light.get_param(Light3D.PARAM_RANGE),
				light.visible and f.visible])
	rows.sort_custom(func(a, b): return String(a[0]) < String(b[0]))
	print("fixture                    type            energy   range   on")
	for r in rows:
		print("%-26s %-14s %7.2f %7.2f   %s%s"
				% [r[0], r[1], r[3], r[4], "yes" if r[5] else "NO", r[2]])
	print("\n%d fixtures on floor 2" % rows.size())
	get_tree().quit(0)
