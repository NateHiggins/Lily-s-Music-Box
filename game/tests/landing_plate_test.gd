extends Node
## K2-E — the landing plate, on a bench.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/LandingPlateTest.tscn `
##         -ProjectPath <checkout>/game
##
## WHAT THE AUDIT MEASURED, BY WALKING RATHER THAN BY READING THE MESH.
##
## From the F01 landing at b(0.00, -2.60) a body under production collision is
## BLOCKED STRAIGHT AHEAD at y -1.88 by the well guard. Going west then north
## climbs 0.15 → 1.60 to the half-landing; crossing east and walking south then
## climbs 1.60 → 2.90 toward F02's floor at 3.20. WEST ARM UP, TURN, EAST ARM
## UP.
##
## DOWN IS UNCLAIMED ON FLOOR ONE, on purpose. Six walks all ended at +0.00,
## but repeating them from further south sends one diagonal into the open well
## and down to -1.40 — mid-well, not the cellar at -2.80. Rather than assert a
## negative I could not separate from a fall, floor one's plate says only what
## is certain.
##
## The glyphs are ↑ and ↓, which have no handedness. K2-D lost a pass to a
## left/right arrow whose meaning depended on which way the reader stood; a
## vertical arrow cannot be inverted by standing somewhere else.

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
	_one_per_floor()
	_every_plate_tells_the_truth()
	_f01_says_street_honestly()
	_it_is_building_fabric()
	_source_discipline()
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


func _one_per_floor() -> void:
	var pass_node := _built()
	var n := 0
	for p in pass_node.find_children("LandingPlate_*", "", true, false):
		n += 1
	_check(n == 6, "one landing plate per residential floor (%d)" % n)
	var f01: Node3D = pass_node.find_child("LandingPlate_F01", true,
			false) as Node3D
	_check(f01 != null, "and F01 has one")
	if f01 != null:
		var b := Vector3(f01.position.x, -f01.position.z, f01.position.y)
		_check(absf(b.y + 1.95) < 0.01,
				"hung at y %.2f, just south of the guard the walk stopped "
						% b.y + "against at y -1.88")
		_check(b.z > 0.85 and b.z < 1.05,
				"at z %.2f, inside the guard's solid band of 0.4 to 1.0" % b.z)
		_check(absf(f01.rotation.y) < 0.001,
				"facing SOUTH, at the player arriving from the entrance hall")
	pass_node.queue_free()


func _every_plate_tells_the_truth() -> void:
	var pass_node := _built()
	for row in [[1, "↑  2 — 6", false], [2, "↑  3 — 6", true],
			[3, "↑  4 — 6", true], [5, "↑  6 — 6", true]]:
		var fid := "LandingPlate_F%02d" % int(row[0])
		var node: Node = pass_node.find_child(fid, true, false)
		_check(node != null, "%s exists" % fid)
		if node == null:
			continue
		var lines := _legends(node)
		var joined := " ".join(PackedStringArray(lines))
		_check(joined.contains(str(row[1])),
				"floor %d offers UP to the floors above it: \"%s\""
						% [int(row[0]), str(row[1])])
		# DOWN appears only where a floor below exists.
		var has_down := joined.contains("↓")
		_check(has_down == bool(row[2]),
				"floor %d %s a DOWN line, which is %s"
						% [int(row[0]), "carries" if has_down else "carries no",
								"correct" if has_down == bool(row[2])
										else "WRONG"])
		_check(joined.contains("FLOOR %d" % int(row[0])),
				"and it names the floor it is standing on")
	# The top floor cannot offer UP.
	var top: Node = pass_node.find_child("LandingPlate_F06", true, false)
	var top_text := " ".join(PackedStringArray(_legends(top)))
	_check(not top_text.contains("↑"),
			"THE TOP FLOOR OFFERS NO UP: \"%s\"" % top_text.strip_edges())
	_check(top_text.contains("TOP FLOOR"), "and says so")
	_check(top_text.contains("↓"), "but still offers DOWN")
	pass_node.queue_free()


func _f01_says_street_honestly() -> void:
	var pass_node := _built()
	var landing := " ".join(PackedStringArray(_legends(
			pass_node.find_child("LandingPlate_F01", true, false))))
	_check(landing.contains("FLOOR 1 — STREET"),
			"the F01 landing plate says street level IS this floor: \"%s\""
					% landing.strip_edges())
	_check(not landing.contains("↓"),
			"AND CLAIMS NOTHING ABOUT DOWN — the honest position, since the "
					+ "cellar's reachability could not be separated from a fall")
	# K2-D reported the fire plate's street line as a lie on F01. Corrected.
	var fire := " ".join(PackedStringArray(_legends(
			pass_node.find_child("FireDirection_F01", true, false))))
	_check(fire.contains("STREET LEVEL — THIS FLOOR"),
			"and the F01 fire plate no longer sends a man downstairs to the "
					+ "street from the street")
	_check(not fire.contains("STREET LEVEL ↓"), "the false line is gone")
	# It is still true upstairs, and left alone there.
	var fire2 := " ".join(PackedStringArray(_legends(
			pass_node.find_child("FireDirection_F02", true, false))))
	_check(fire2.contains("STREET LEVEL ↓"),
			"while F02's, which IS true, is untouched")
	# K2-D's corridor-direction contract is not disturbed.
	_check(fire.contains("FIRE EXIT — STAIRS  →"),
			"and K2-D's corrected corridor arrow still reads south")
	var pair := " ".join(PackedStringArray(_legends(
			pass_node.find_child("StairDirectionPair_F01", true, false))))
	_check(pair.contains("←  STAIRS"), "as does its pair across the corridor")
	pass_node.queue_free()


func _it_is_building_fabric() -> void:
	var pass_node := _built()
	var f01: Node3D = pass_node.find_child("LandingPlate_F01", true,
			false) as Node3D
	_check(_count(f01, "Area3D") == 0, "no interaction area")
	_check(_count(f01, "CollisionObject3D") == 0, "no collision body")
	_check(_count(f01, "Light3D") == 0, "NO MAGICAL LIGHT")
	_check(_count(f01, "AudioStreamPlayer3D") == 0, "no sound")
	_check(f01.get_script() == null, "and no script")
	_check(not RealityState.data.has("landing_plates")
			and not RealityState.data.has("stair_hint"),
			"K2-E wrote no save key of its own")
	var again := _built()
	var f2: Node3D = again.find_child("LandingPlate_F01", true, false) as Node3D
	_check(f2 != null and f2.position.is_equal_approx(f01.position),
			"and a second build puts it in exactly the same place")
	_check(" ".join(PackedStringArray(_legends(f2)))
			== " ".join(PackedStringArray(_legends(f01))),
			"with exactly the same words")
	pass_node.queue_free()
	again.queue_free()


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
	_check(start > 0 and stop > start, "the landing plate is its own function")
	# CODE ONLY. A comment that says "the player arriving from the entrance
	# hall" is prose about who reads the sign, not a dependency on a player.
	var body := ""
	for line in text.substr(start, stop - start).split("
"):
		var stripped := String(line)
		var hash_at := stripped.find("#")
		if hash_at >= 0:
			stripped = stripped.substr(0, hash_at)
		body += stripped.to_lower() + "
"
	for word in ["realitystate", "commit(", "workorders", "realitycases",
			"first_shift", "ritual", "job_stage", "doorprop", "leaf_state",
			"omnilight", "spotlight", "randf", "randi", "player", "tween"]:
		_check(not body.contains(word), "and never touches `%s`" % word)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [landing ok] ", label)
	else:
		failures += 1
		printerr("  [LANDING FAIL] ", label)


func _finish() -> void:
	print("LANDING PLATE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
