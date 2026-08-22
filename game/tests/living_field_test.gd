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
	var rect := Vector4(-13.65, 0.45, -5.51, 9.65)
	field.configure(rect, 3.2, Vector3(-9.6, 4.2, 5.0), 7)
	_check("the field covers the flat at 0.25 m (%d x %d x %d)" % [field.nx, field.ny, field.nz],
			field.nx >= 30 and field.nz >= 30 and field.ny >= 12)
	var tex = field.texture()
	_check("the field is a 3-D texture", tex is ImageTexture3D and tex.get_depth() == field.ny)

	# Nothing grows with no intensity.
	field.intensity = 0.0
	for _i in 40:
		field.tick(0.125)
	var c0: Dictionary = field.census()
	_check("at intensity 0 nothing lives (%d live voxels, %d agents)" % [c0.live_voxels, c0.agents],
			c0.live_voxels == 0 and c0.agents == 0)

	# Growth: a recognised case grows a body from the source.
	field.intensity = 0.6
	for _i in 80:          # 10 s
		field.tick(0.125)
	var c1: Dictionary = field.census()
	_check("at 0.6 after 10 s the organism has a body (%d live voxels, %d agents)" % [c1.live_voxels, c1.agents],
			c1.live_voxels > 40 and c1.agents == 120 + int(780 * 0.6))
	for _i in 240:         # 40 s
		field.tick(0.125)
	var c2: Dictionary = field.census()
	# After the first exploratory surge the organism consolidates a network
	# (its footprint may shrink - that is retraction, the Physarum rule); what
	# must keep growing is where it HAS been, and a body must persist.
	_check("it keeps covering ground and keeps a body (stain %d -> %d, footprint %d -> %d, live %d)" % [c1.stained_voxels, c2.stained_voxels, c1.extent_cells, c2.extent_cells, c2.live_voxels],
			c2.stained_voxels > c1.stained_voxels and c2.live_voxels > 100)
	_check("and it leaves a stain where it has been (%d stained voxels)" % c2.stained_voxels,
			c2.stained_voxels > c2.live_voxels * 0.5)

	# Recession: drop the case to a residue; the body withdraws, the stain stays.
	field.intensity = 0.0
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
	field.intensity = 0.8
	var t0 := Time.get_ticks_usec()
	for _i in 8:
		field.tick(0.125)
	var per_tick := float(Time.get_ticks_usec() - t0) / 8000.0
	print("  tick cost %.2f ms (%d voxels, %d agents; agents at 8 Hz, %d slices relaxed per tick)" % [per_tick, field.census().voxels, field.census().agents, field.SLICES_PER_TICK])
	_check("a tick costs under 6 ms in GDScript", per_tick < 6.0)

	print("LIVING FIELD TEST: %s (%d/%d)" % ["PASS" if _failed == 0 else "FAIL", _passed, _passed + _failed])
	get_tree().quit(0 if _failed == 0 else 1)
