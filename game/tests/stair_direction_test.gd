extends Node
## K2-D — the paired stair plate, on a bench.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/StairDirectionTest.tscn `
##         -ProjectPath <checkout>/game
##
## WHAT THE AUDIT FOUND, AND IT IS WORSE THAN A MISSING SIGN.
##
## The building's only stair plate on a residential floor hangs at
## b(4.98, 2.92); its readable face looks WEST, so a reader stands in the east
## corridor facing EAST and their LEFT is NORTH. It carried "←  FIRE EXIT —
## STAIRS": north.
##
## Measured at body height on all six residential floors, THE EAST CORRIDOR'S
## WEST WALL IS UNBROKEN FROM y +4.4 TO y -6.8 AND OPENS ONLY AT y -9.2..-7.2 —
## six open samples per floor, EVERY ONE SOUTH OF THE PLATE, none north of it.
## The sign pointed away from the only route to the thing it named.
##
## And from the pose where a man takes his first report — b(4.84, -2.27, 1.62),
## facing the register — that plate is 5.19 m behind his shoulder at yaw +88.5,
## edge-on and unreadable.
##
## So: the arrow is corrected to match the building, and the plate gets the pair
## a corridor with a desk in it would carry — on the opposite wall, facing the
## desk, pointing at the same opening from the other side.

const SignageScript := preload("res://scripts/building/wayfinding_signage_pass.gd")
const PASS_PATH := "res://scripts/building/wayfinding_signage_pass.gd"

var failures := 0
var checks := 0


## The pass reads `world.reality_controllers` to number apartment doors; the
## plates this suite is about are built from measured coordinates and need none.
class StubWorld:
	extends Node3D
	var reality_controllers: Dictionary = {}


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	_the_pair_exists()
	_both_plates_point_the_same_way()
	_it_is_building_fabric_and_nothing_else()
	_source_discipline()
	_finish()


func _built() -> Node3D:
	var pass_node: Node3D = SignageScript.new()
	add_child(pass_node)
	var world := StubWorld.new()
	add_child(world)
	pass_node.call("build", world)
	return pass_node


func _the_pair_exists() -> void:
	var pass_node := _built()
	var stats_pairs := 0
	for n in pass_node.find_children("StairDirectionPair_*", "", true, false):
		stats_pairs += 1
	_check(stats_pairs == 6,
			"one paired plate on each residential floor (%d)" % stats_pairs)
	var f01: Node3D = pass_node.find_child("StairDirectionPair_F01", true,
			false) as Node3D
	_check(f01 != null, "and F01 has one")
	if f01 == null:
		return
	var b := Vector3(f01.position.x, -f01.position.z, f01.position.y)
	_check(absf(b.x - 3.56) < 0.01,
			"hung on the corridor's WEST wall at x %.2f (face measured at "
					% b.x + "x 3.52)")
	_check(absf(b.y + 2.10) < 0.01,
			"opposite the register at y %.2f" % b.y)
	# The readable face must look EAST, at a man who has turned from the desk.
	var face := f01.transform.basis.z
	_check(face.x > 0.99,
			"and its readable face looks EAST (%.2f, %.2f), which is where the "
					% [face.x, -face.z] + "desk is")
	pass_node.queue_free()


func _both_plates_point_the_same_way() -> void:
	var pass_node := _built()
	var legends := {}
	for nm in ["FireDirection_F01", "StairDirectionPair_F01"]:
		var n: Node = pass_node.find_child(nm, true, false)
		var found: Array[String] = []
		if n != null:
			_sweep(n, found)
		legends[nm] = found
	# THE CORRECTION. A reader of the fire plate faces EAST, so their RIGHT is
	# SOUTH — and south is where the corridor opens.
	var fire := " ".join(PackedStringArray(legends["FireDirection_F01"]))
	_check(fire.contains("FIRE EXIT — STAIRS  →"),
			"the fire plate now points SOUTH: \"%s\"" % fire.split("STREET")[0].strip_edges())
	_check(not fire.contains("←  FIRE EXIT"),
			"and no longer points north, away from the only opening")
	# THE PAIR. A reader of it faces WEST, so their LEFT is SOUTH — the same
	# opening, from the other side of the corridor.
	var pair := " ".join(PackedStringArray(legends["StairDirectionPair_F01"]))
	_check(pair.contains("←  STAIRS"),
			"the pair points SOUTH too, with the opposite glyph: \"%s\""
					% pair.strip_edges())
	_check(pair.contains("ALL FLOORS") and pair.contains("FLOOR 1"),
			"and says which floor it is on and what it serves")
	_check(not pair.contains("2A") and not pair.contains("chirp")
			and not pair.contains("WORK ORDER"),
			"IT KNOWS NOTHING ABOUT TONIGHT'S JOB — it is a building's sign, "
					+ "not a quest marker")
	for banned in ["waypoint", "marker", "objective", "press", "[E]", "HUD"]:
		_check(not pair.to_lower().contains(banned.to_lower()),
				"and never says `%s`" % banned)
	pass_node.queue_free()


func _it_is_building_fabric_and_nothing_else() -> void:
	var pass_node := _built()
	var f01: Node3D = pass_node.find_child("StairDirectionPair_F01", true,
			false) as Node3D
	if f01 == null:
		return
	_check(_count(f01, "Area3D") == 0, "no interaction area")
	_check(_count(f01, "CollisionObject3D") == 0, "no collision body")
	_check(_count(f01, "Light3D") == 0, "no light of its own")
	_check(_count(f01, "AudioStreamPlayer3D") == 0, "no sound of its own")
	_check(f01.get_script() == null,
			"and no script: it cannot mutate anything, because it is a sign")
	_check(not RealityState.data.has("stair_hint")
			and not RealityState.data.has("wayfinding")
			and not RealityState.data.has("stair_pairs"),
			"K2-D wrote no save key of its own")
	# Two builds produce the same plate: nothing here is random or stateful.
	var again := _built()
	var b1 := f01.position
	var f2: Node3D = again.find_child("StairDirectionPair_F01", true,
			false) as Node3D
	_check(f2 != null and f2.position.is_equal_approx(b1),
			"and building it twice puts it in exactly the same place")
	pass_node.queue_free()
	again.queue_free()


func _sweep(node: Node, out: Array[String]) -> void:
	if node is Label3D:
		out.append(str((node as Label3D).text))
	for child in node.get_children():
		_sweep(child, out)


func _count(node: Node, type_name: String) -> int:
	var n := 0
	if node.is_class(type_name):
		n += 1
	for child in node.get_children():
		n += _count(child, type_name)
	return n


func _source_discipline() -> void:
	var text := FileAccess.get_file_as_string(PASS_PATH)
	var start := text.find("func _build_stair_pair_plates")
	var stop := text.find("func _build_front_directory")
	_check(start > 0 and stop > start, "the pair is its own small function")
	var body := text.substr(start, stop - start).to_lower()
	for word in ["realitystate", "commit(", "workorders", "realitycases",
			"first_shift", "ritual", "job_stage", "doorprop", "leaf_state",
			"randf", "randi", "player"]:
		_check(not body.contains(word),
				"and it never touches `%s`" % word)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [stair direction ok] ", label)
	else:
		failures += 1
		printerr("  [STAIR DIRECTION FAIL] ", label)


func _finish() -> void:
	print("STAIR DIRECTION TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
