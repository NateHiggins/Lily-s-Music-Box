extends Node
## K2-F — which way the apartments lie, on a bench.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/UnitDirectionTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE MEASURED PROBLEM. Climbing K2-E's flight with the production body lands
## a player on F02 at b(2.50, -2.26). From there the 2A door is 7.95 m away and
## BLOCKED; its brass number is blocked; so is every other unit plate, the floor
## directory, the fire plate and K2-D's corridor pair. THE ONLY CLEAR CUE IS
## K2-E'S LANDING PLATE, and it named the floor and nothing else.
##
## A floor number is not an apartment.
##
## THE SIDES ARE DERIVED, NOT DECLARED. The line is built from the doors this
## pass has already numbered, so it cannot drift from the building. Measured
## recurrence — A and B west, C and D east, every unit door at x +-5.33, on all
## six floors — is a fact the builder reads, not a rule it asserts.

const SignageScript := preload("res://scripts/building/wayfinding_signage_pass.gd")
const PASS_PATH := "res://scripts/building/wayfinding_signage_pass.gd"

var failures := 0
var checks := 0


class StubWorld:
	extends Node3D
	var reality_controllers: Dictionary = {}


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	_finish_after()


func _finish_after() -> void:
	var pass_node := _built()
	_the_line_exists(pass_node)
	_it_is_still_only_a_sign(pass_node)
	_idempotent()
	_source_discipline()
	pass_node.queue_free()
	_finish()


func _built() -> Node3D:
	var pass_node: Node3D = SignageScript.new()
	add_child(pass_node)
	var world := StubWorld.new()
	add_child(world)
	pass_node.call("build", world)
	return pass_node


func _legends(node: Node) -> Array[String]:
	var out: Array[String] = []
	_sweep(node, out)
	return out


func _sweep(node: Node, out: Array[String]) -> void:
	if node == null:
		return
	if node is Label3D:
		out.append(str((node as Label3D).text))
	for child in node.get_children():
		_sweep(child, out)


## The plate carries one label per side; this joins them for the checks that
## only care whether anything was printed at all.
func _units_line(pass_node: Node3D, fid: String) -> String:
	var joined := ""
	for line in _legends(pass_node.find_child("LandingPlate_" + fid, true,
			false)):
		if line.contains("←") or line.contains("→"):
			joined += line + "   "
	return joined.strip_edges()


## GRACEFUL WHEN THERE ARE NO DOORS, which is what a bare bench is. The units
## line is DERIVED from the doors `_build_apartment_numbers` numbered, and that
## needs a real building: `world.reality_controllers` is empty here, so the pass
## numbers nothing. The right behaviour is then to print no units line at all
## rather than an empty arrow or a guess — and the plate must still carry
## everything K2-E put on it.
##
## The glyph-against-door proof cannot live on this bench for the same reason.
## It is in the production-live suite, where there are doors to be wrong about.
func _the_line_exists(pass_node: Node3D) -> void:
	var doors: Dictionary = pass_node.get("_numbered_doors")
	_check(doors.is_empty(),
			"a bench has no apartment doors to number (%d)" % doors.size())
	for fid in ["F01", "F02", "F06"]:
		var line := _units_line(pass_node, fid)
		_check(line == "",
				"%s prints NO units line rather than an empty arrow" % fid)
	# And K2-E's plate is intact underneath.
	var f02 := " ".join(PackedStringArray(_legends(
			pass_node.find_child("LandingPlate_F02", true, false))))
	_check(f02.contains("FLOOR 2"), "the floor number survives")
	_check(f02.contains("↑") and f02.contains("↓"),
			"and so does K2-E's vertical line: \"%s\"" % f02.strip_edges())
	var f01 := " ".join(PackedStringArray(_legends(
			pass_node.find_child("LandingPlate_F01", true, false))))
	_check(f01.contains("FLOOR 1 — STREET") and not f01.contains("↓"),
			"and F01 still says street level is this floor, with no down")
	var f06 := " ".join(PackedStringArray(_legends(
			pass_node.find_child("LandingPlate_F06", true, false))))
	_check(f06.contains("TOP FLOOR") and not f06.contains("↑"),
			"and the top floor still offers no up")


func _it_is_still_only_a_sign(pass_node: Node3D) -> void:
	var f02: Node3D = pass_node.find_child("LandingPlate_F02", true,
			false) as Node3D
	_check(_count(f02, "Area3D") == 0, "no interaction area")
	_check(_count(f02, "CollisionObject3D") == 0, "no collision body")
	_check(_count(f02, "Light3D") == 0, "no light")
	_check(_count(f02, "AudioStreamPlayer3D") == 0, "no audio")
	_check(f02.get_script() == null, "no script")
	_check(not RealityState.data.has("unit_direction")
			and not RealityState.data.has("landing_plates"),
			"K2-F wrote no save key of its own")


func _idempotent() -> void:
	var a := _built()
	var b := _built()
	for fid in ["F01", "F02", "F03", "F04", "F05", "F06"]:
		_check(_units_line(a, fid) == _units_line(b, fid),
				"%s rebuilds to exactly the same line" % fid)
	a.queue_free()
	b.queue_free()


func _count(node: Node, type_name: String) -> int:
	var n := 0
	if node == null:
		return 0
	if node.is_class(type_name):
		n += 1
	for child in node.get_children():
		n += _count(child, type_name)
	return n


func _source_discipline() -> void:
	var text := FileAccess.get_file_as_string(PASS_PATH)
	var start := text.find("func _build_landing_plates")
	var stop := text.find("func _metal(")
	_check(start > 0 and stop > start, "the builder is one function")
	var body := ""
	for line in text.substr(start, stop - start).split("\n"):
		var stripped := String(line)
		var hash_at := stripped.find("#")
		if hash_at >= 0:
			stripped = stripped.substr(0, hash_at)
		body += stripped.to_lower() + "\n"
	for word in ["realitystate", "commit(", "workorders", "realitycases",
			"first_shift", "ritual", "job_stage", "leaf_state", "omnilight",
			"randf", "randi", "tween", "set_meta"]:
		_check(not body.contains(word), "and never touches `%s`" % word)
	_check(body.contains("_numbered_doors"),
			"but it does read the doors the pass already numbered, which is "
					+ "why the sides cannot drift from the building")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [unit dir ok] ", label)
	else:
		failures += 1
		printerr("  [UNIT DIR FAIL] ", label)


func _finish() -> void:
	print("UNIT DIRECTION TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
