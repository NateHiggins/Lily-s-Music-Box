extends Node
## LIVING FIELD CONTRACT (design/LIVING_FIELD_BRIEF.md). Headless, no
## building: one field over a 2A-sized flat, stepped for simulated minutes.
##
##     godot --headless --path game res://tests/LivingFieldTest.tscn

var _failed := 0
var _passed := 0


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  [ok] %s" % label)
	else:
		_failed += 1
		print("  [FAIL] %s" % label)


func _ready() -> void:
	var field = load("res://scripts/reality/living_field.gd").new()
	var rect := Vector4(-13.9, -9.9, 13.9, 9.9)
	field.configure(rect, 3.2, 7)
	var src: int = field.add_source(Vector3(-9.6, 4.2, 5.0), 0)
	_check("the field covers the storey at 0.5 m (%d x %d x %d)" % [field.nx, field.ny, field.nz],
			field.nx >= 50 and field.nz >= 36 and field.ny >= 6)
	var g: Vector4 = field.gravity_at(Vector3(1.0, 4.0, 2.0), 3.0, 0.2)
	var g2: Vector4 = field.gravity_at(Vector3(6.0, 4.0, -3.0), 3.0, 0.2)
	_check("the gravity is a unit vector with an intensity 0.4..1.7 (%.2f, %.2f, %.2f | %.2f)" % [g.x, g.y, g.z, g.w],
			absf(Vector3(g.x, g.y, g.z).length() - 1.0) < 0.01 and g.w >= 0.4 and g.w <= 1.7)
	_check("and it is not the same in two places", Vector3(g.x, g.y, g.z).distance_to(Vector3(g2.x, g2.y, g2.z)) > 0.05)
	var tex = field.texture()
	_check("the field is a 3-D texture", tex is ImageTexture3D and tex.get_depth() == field.ny)

	# DT-5's local emergence swelling is body, not conversion. Prove it can
	# become substantial without birthing agents or leaving persistent stain,
	# then recedes under the field's existing decay when the pressure stops.
	var pressure_field = load("res://scripts/reality/living_field.gd").new()
	pressure_field.configure(Vector4(-2.0, -2.0, 2.0, 2.0), 3.2, 19)
	var pressure_src: int = pressure_field.add_source(Vector3.ZERO, 0)
	var pressure_cells: int = pressure_field.pressurize(
			Vector3(0.0, 3.7, 0.0), pressure_src, 0.92, 0.78)
	var pressure_now: Dictionary = pressure_field.census()
	_check("emergence pressure adds temporary body but no lineage or stain",
			pressure_cells >= 4 and pressure_now.live_voxels >= 1
			and pressure_now.agents == 0 and pressure_now.stained_voxels == 0)
	for _i in 200:
		pressure_field.tick(0.125)
	var pressure_after: Dictionary = pressure_field.census()
	_check("unfed emergence pressure relaxes (%d -> %d live voxels)"
			% [pressure_now.live_voxels, pressure_after.live_voxels],
			pressure_after.live_voxels == 0 and pressure_after.agents == 0)

	# Nothing grows with no intensity.
	field.set_source_intensity(src, 0.0)
	for _i in 40:
		field.tick(0.125)
	var c0: Dictionary = field.census()
	_check("at intensity 0 nothing lives (%d live voxels, %d agents)" % [c0.live_voxels, c0.agents],
			c0.live_voxels == 0 and c0.agents == 0)

	# Growth: a recognised case grows a body from the source.
	field.set_source_intensity(src, 0.6)
	for _i in 80:          # 10 s
		field.tick(0.125)
	var c1: Dictionary = field.census()
	_check("at 0.6 after 10 s the organism has a body (%d live voxels, %d agents)" % [c1.live_voxels, c1.agents],
			c1.live_voxels > 40 and c1.agents >= int((120 + 780 * 0.6) * 0.75) and c1.agents <= int((120 + 780 * 0.6) * 1.3))
	for _i in 240:         # 40 s
		field.tick(0.125)
	var c2: Dictionary = field.census()
	# After the first exploratory surge the organism consolidates a network
	# (its footprint may shrink - that is retraction, the Physarum rule); what
	# must keep growing is where it HAS been, and a body must persist.
	_check("it keeps covering ground and keeps a body (stain %d -> %d, live %d)" % [c1.stained_voxels, c2.stained_voxels, c2.live_voxels],
			c2.stained_voxels > c1.stained_voxels and c2.live_voxels > 100)
	_check("and it leaves a stain where it has been (%d stained voxels)" % c2.stained_voxels,
			c2.stained_voxels > c2.live_voxels * 0.5)

	# Recession: drop the case to a residue; the body withdraws, the stain stays.
	_check("it pools on the floor (%d live floor voxels)" % c2.floor_live, c2.floor_live > 10)
	_check("it has nodes for the lights (%d)" % c2.nodes, c2.nodes >= 1)
	# DT-5: a tentacle belongs on the body's cross-sectional FRONT, not on the
	# strong interior nodes above. The result must be live, exposed to a cell
	# below the isosurface, and respect the same two-metre anchor spacing the
	# production placement owner uses.
	var front: Dictionary = field.emergence_front(0.45)
	_check("it exposes a live emergence front (%.2f body, %d outside neighbours)"
			% [float(front.get("strength", 0.0)), int(front.get("outside_neighbours", 0))],
			not front.is_empty() and float(front.strength) >= 0.45
			and int(front.outside_neighbours) >= 1 and int(front.source) == src)
	var next_front: Dictionary = {}
	if not front.is_empty():
		next_front = field.emergence_front(0.45, [front.position])
	_check("a claimed front is spaced by two metres",
			front.is_empty() or next_front.is_empty()
			or (next_front.position as Vector3).distance_to(
					front.position as Vector3) >= 2.0)
	field.set_source_intensity(src, 0.0)
	for _i in 400:         # 50 s: the body withdraws over a minute, not a second
		field.tick(0.125)
	var c3: Dictionary = field.census()
	_check("at 0 the body recedes (%d -> %d live voxels, %d agents)" % [c2.live_voxels, c3.live_voxels, c3.agents],
			c3.live_voxels < c2.live_voxels * 0.2 and c3.agents == 0)
	_check("the stain outlives the body (%d stained voxels)" % c3.stained_voxels,
			c3.stained_voxels > c2.stained_voxels * 0.5)

	# The pulse: shuttle streaming, 14 s, phase in 0..1.
	var phase: float = field.pulse_phase()
	_check("the shuttle pulse has a phase (%.2f)" % phase, phase >= 0.0 and phase < 1.0)

	# Cost: one step of the 2A field in GDScript.
	field.set_source_intensity(src, 0.8)
	var t0 := Time.get_ticks_usec()
	for _i in 8:
		field.tick(0.125)
	var per_tick := float(Time.get_ticks_usec() - t0) / 8000.0
	print("  tick cost %.2f ms (%d voxels, %d agents; agents at 8 Hz, %d slices relaxed per tick)" % [per_tick, field.census().voxels, field.census().agents, field.SLICES_PER_TICK])
	_check("a tick costs under 6 ms in GDScript", per_tick < 6.0)

	print("LIVING FIELD TEST: %s (%d/%d)" % ["PASS" if _failed == 0 else "FAIL", _passed, _passed + _failed])
	get_tree().quit(0 if _failed == 0 else 1)
