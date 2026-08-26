extends Node
## K2-F — which way the apartments lie, in the real building.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/UnitDirectionLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE PLAYER IS NEVER TELEPORTED FOR A CLAIM. Every position below is reached
## by driving the production body with `move_and_slide` under production
## collision, starting from the F01 landing K2-E left it on.

const CASE := "mina_caption_crisis"
const JOB := "vantry_chirp_2a"
const STATION := "F02_STATION_2A_LANDING"

var failures := 0
var checks := 0
var root: Node
var player: PlayerController
var space: PhysicsDirectSpaceState3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	player = root.get("player") as PlayerController
	space = player.get_world_3d().direct_space_state
	var director: Node = root.get("first_shift_director")
	var orders: Node = root.get("work_orders")
	var plate: Node3D = root.find_child("LandingPlate_F02", true, false) as Node3D
	var door_2a: Node3D = root.find_child("F02_DOOR_02", true, false) as Node3D
	var door_2c: Node3D = root.find_child("F02_DOOR_05", true, false) as Node3D
	var brass_2a: Node3D = root.find_child("BrassApartmentNumber_2A", true,
			false) as Node3D

	# --- CLIMB K2-E'S FLIGHT WITH THE BODY ----------------------------------
	var arrival := _walk([0.0, -3.40, 0.30],
			[[-2.50, -1.00], [-2.50, 2.60], [2.50, 2.60], [2.50, -1.20],
					[2.50, -2.26]], 1800)
	_check(arrival.y > 3.0 and arrival.y < 3.4,
			"the body climbs to F02 and stands at z %.2f" % arrival.y)
	_check(-arrival.z < -1.9 and -arrival.z > -2.7,
			"arriving at b(%.2f, %.2f)" % [arrival.x, -arrival.z])
	var eye := arrival + player.camera.position

	# --- THE AMBIGUITY, RE-ASSERTED -----------------------------------------
	for row in [["the 2A door", door_2a], ["2A's brass number", brass_2a],
			["the F02 directory",
					root.find_child("FloorDirectory_F02", true, false)]]:
		var n: Node3D = row[1] as Node3D
		if n == null:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, n.global_position)
		q.exclude = [player.get_rid()]
		_check(not space.intersect_ray(q).is_empty(),
				"FROM THE F02 ARRIVAL %s is not visible (%.2f m)"
						% [row[0], eye.distance_to(n.global_position)])

	# --- BUT THE LANDING PLATE IS -------------------------------------------
	_check(plate != null, "the F02 landing plate is in the production stair")
	var q2 := PhysicsRayQueryParameters3D.create(eye, plate.global_position)
	q2.exclude = [player.get_rid()]
	_check(space.intersect_ray(q2).is_empty(),
			"and it IS visible from the arrival, %.2f m away"
					% eye.distance_to(plate.global_position))

	# --- IT NAMES 2A, ON THE WEST SIDE --------------------------------------
	var line := _units_line(plate)
	_check(line != "", "it carries a units line: \"%s\"" % line.strip_edges())
	_check(line.contains("2A") and line.contains("2B") and line.contains("2C"),
			"naming every numbered unit on this floor")
	_check(_side_label(plate, "←").contains("2A"),
			"and 2A is on the LEFT-glyph label: \"%s\""
					% _side_label(plate, "←").strip_edges())
	_check(_side_label(plate, "→").contains("2C")
			and not _side_label(plate, "→").contains("2A"),
			"while 2C is on the right one: \"%s\""
					% _side_label(plate, "→").strip_edges())

	# --- THE ANTI-LIE PROOF, EVERY NUMBERED DOOR IN THE BUILDING ------------
	var pass_node: Node = root.find_child("WayfindingSignage", true, false)
	var doors: Dictionary = pass_node.get("_numbered_doors") if pass_node != null \
			else {}
	_check(doors.size() >= 12, "the pass numbered %d unit doors" % doors.size())
	var agreed := 0
	var wrong := 0
	for d in doors:
		if not is_instance_valid(d):
			continue
		var unit := str(doors[d])
		var fid := "LandingPlate_F%02d" % int(round(d.global_position.y / 3.2) + 1)
		var p2: Node3D = root.find_child(fid, true, false) as Node3D
		if p2 == null:
			continue
		# One label per side, so MEMBERSHIP is the whole test. The first version
		# joined both sides into one string and asked whether a "←" appeared
		# before the unit — which is true of every unit after the first arrow,
		# and duly reported seven east doors as pointing west.
		var in_west: bool = _side_label(p2, "←").contains(unit)
		var in_east: bool = _side_label(p2, "→").contains(unit)
		var on_west: bool = d.global_position.x < 0.0
		if in_west == in_east:
			wrong += 1
			printerr("  [UNIT DIR LIVE FAIL] %s is on %s label" % [unit,
					"both" if in_west else "neither"])
		elif on_west == in_west:
			agreed += 1
		else:
			wrong += 1
			printerr("  [UNIT DIR LIVE FAIL] %s at x %+.2f is on the %s label"
					% [unit, d.global_position.x,
							"west" if in_west else "east"])
	_check(wrong == 0 and agreed >= 12,
			"EVERY NUMBERED DOOR AGREES WITH ITS GLYPH (%d agreed, %d wrong)"
					% [agreed, wrong])

	# --- AND THE GLYPH EQUALS THE TRAVERSABLE ROUTE -------------------------
	var d2a_before := arrival.distance_to(door_2a.global_position)
	var d2c_before := arrival.distance_to(door_2c.global_position)
	var west_end := _walk([2.50, -2.26, 3.40],
			[[0.0, -2.30], [-2.60, -2.20], [-4.40, -2.15]], 1200)
	var d2a_after := west_end.distance_to(door_2a.global_position)
	var d2c_after := west_end.distance_to(door_2c.global_position)
	_check(west_end.x < 0.0,
			"WALKING THE WAY THE LEFT GLYPH POINTS carries the body west to "
					+ "b(%.2f, %.2f)" % [west_end.x, -west_end.z])
	_check(d2a_after < d2a_before - 4.0,
			"and closes on the 2A door from %.2f m to %.2f m"
					% [d2a_before, d2a_after])
	_check(d2c_after > d2c_before,
			"while moving AWAY from 2C, %.2f m to %.2f m — the glyph is not "
					% [d2c_before, d2c_after] + "merely true, it is the route")
	_check(absf(west_end.y - 3.20) < 0.4,
			"and stays on F02 (z %.2f), not fallen through" % west_end.y)

	# --- OBSERVATION IS OPTIONAL AND MUTATES NOTHING ------------------------
	var before := var_to_bytes(RealityState.data)
	for i in 25:
		var r := PhysicsRayQueryParameters3D.create(eye, plate.global_position)
		r.exclude = [player.get_rid()]
		space.intersect_ray(r)
	_check(var_to_bytes(RealityState.data) == before,
			"TWENTY-FIVE LOOKS AT THE PLATE MUTATE NOTHING")
	_check(bool(director.call("begin_first_shift")), "the arrival commits")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	detector.call("interact_control", "detector", player)
	register.call("take_slip")
	var card := str((root.get("objective_tracker"))._objective.text)
	_check(card.begins_with("Unit 2A, one floor up."),
			"K2-C's card is untouched")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"one work order")
	_check(str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"one case, active")
	_check(not bool(director.call("tour_key_carried"))
			and not bool(director.call("has_station_mark", STATION)),
			"tour key and STATION 2 still free and unmade")
	_check(str(door_2a.get("leaf_state")) != "" and door_2a.get("open") == false,
			"and the 2A door is exactly as the building left it")

	# --- SAVE / RESUME / REBUILD --------------------------------------------
	var saved := var_to_bytes(RealityState.data)
	(root.get("objective_tracker")).call("clear")
	director.call("present_resume")
	_check(str((root.get("objective_tracker"))._objective.text) == card,
			"a resume reconstructs the same intention")
	_check(var_to_bytes(RealityState.data) == saved, "and commits nothing")
	_check(_units_line(plate) == line,
			"and the units line is the SAME STATIC TRUTH, from no stored key")
	_check(not RealityState.data.has("unit_direction")
			and not RealityState.data.has("landing_plates"),
			"K2-F wrote no save key of its own")
	_finish()


func _walk(from: Array, legs: Array, cap: int) -> Vector3:
	player.global_position = GameBoot.b2g(from)
	player.velocity = Vector3.ZERO
	var leg := 0
	var steps := 0
	while leg < legs.size() and steps < cap:
		var goal := GameBoot.b2g([legs[leg][0], legs[leg][1],
				player.global_position.y])
		var d: Vector3 = goal - player.global_position
		d.y = 0.0
		if d.length() < 0.32:
			leg += 1
			continue
		player.velocity = d.normalized() * 3.0
		player.velocity.y = -3.0
		player.move_and_slide()
		steps += 1
	return player.global_position


## The plate carries one label per side. `side` is "←" or "→".
func _side_label(plate: Node3D, side: String) -> String:
	var out: Array[String] = []
	_sweep(plate, out)
	for l in out:
		if l.contains(side):
			return l
	return ""


func _units_line(plate: Node3D) -> String:
	var w := _side_label(plate, "←")
	var e := _side_label(plate, "→")
	return (w + "   " + e).strip_edges()


func _sweep(node: Node, out: Array[String]) -> void:
	if node == null:
		return
	if node is Label3D:
		out.append(str((node as Label3D).text))
	for child in node.get_children():
		_sweep(child, out)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [unit dir live ok] ", label)
	else:
		failures += 1
		printerr("  [UNIT DIR LIVE FAIL] ", label)


func _finish() -> void:
	print("UNIT DIRECTION LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
