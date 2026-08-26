extends Node
## K2-E — the landing plate in the real building, and the climb it claims.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/LandingPlateLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE VERTICAL TOPOLOGY IS PROVED BY WALKING IT, not by reading the mesh: the
## production player is driven with `move_and_slide` under production collision.
## That is the only movement in this suite. No teleport for a claim, no forced
## yaw, no camera animation, no assigned velocity that is not a walk.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"
const STATION := "F02_STATION_2A_LANDING"
## The choice point: where a body arriving from the entrance hall is stopped.
const LANDING := [0.00, -2.60]

var failures := 0
var checks := 0
var root: Node
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	player = root.get("player") as PlayerController
	var space := player.get_world_3d().direct_space_state
	var director: Node = root.get("first_shift_director")
	var orders: Node = root.get("work_orders")
	var guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	var plate: Node3D = root.find_child("LandingPlate_F01", true, false) as Node3D

	# --- the ambiguity, re-asserted: blocked ahead, and no way down ---------
	var ahead := _walk([0.0, -3.40], [0.0, 3.0], 400)
	_check(-ahead.z < -1.70 and -ahead.z > -2.10,
			"STRAIGHT AHEAD IS BLOCKED at y %.2f by the well guard" % -ahead.z)
	# WHAT I CANNOT PROVE, AND THEREFORE DO NOT ASSERT.
	#
	# An earlier version of this suite claimed "there is no way down from this
	# landing" on the strength of six walks that all ended at +0.00. Walking the
	# same six targets from a start 0.8 m further south, ONE of them — the long
	# diagonal to b(2.90, 3.10) — reaches -1.40. That is mid-well, not the
	# cellar floor at -2.80, so it reads as a body entering the open well on a
	# diagonal rather than descending a flight. I could not separate the two
	# cases robustly, so the claim is withdrawn: this suite asserts only that
	# the CLIMB is real, and the F01 plate says nothing about down.
	var down_probe := _walk_low([0.0, -3.40], [2.90, 3.10], 500)
	print("  [note] the diagonal to b(2.90, 3.10) reaches %+.2f — recorded, "
			% down_probe + "not asserted; see the README")

	# --- the cue is at the choice point --------------------------------------
	_check(plate != null, "THE LANDING PLATE IS IN THE PRODUCTION STAIR")
	var eye := GameBoot.b2g([LANDING[0], LANDING[1], 1.62])
	var to: Vector3 = plate.global_position - eye
	_check(to.length() < 1.6,
			"%.2f m from the choice point" % to.length())
	var q := PhysicsRayQueryParameters3D.create(eye, plate.global_position)
	q.exclude = [player.get_rid()]
	_check(space.intersect_ray(q).is_empty(), "with a clear line to it")
	var fwd := Vector3(0, 0, -1)  # arriving northbound
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	_check(rad_to_deg(fwd.angle_to(flat)) < 35.0,
			"and %.0f deg off the direction of travel — read without turning"
					% rad_to_deg(fwd.angle_to(flat)))

	# --- ITS CLAIM AGREES WITH THE CLIMB ------------------------------------
	# The plate says UP to floors 2-6. Walk it: west arm north, then east arm
	# south, and watch the height.
	player.global_position = GameBoot.b2g([0.0, -2.60, 0.30])
	player.velocity = Vector3.ZERO
	var legs := [[-2.50, -1.00], [-2.50, 2.60], [2.50, 2.60], [2.50, -1.20]]
	var heights: Array[float] = []
	var leg := 0
	var steps := 0
	while leg < legs.size() and steps < 1400:
		var goal := GameBoot.b2g([legs[leg][0], legs[leg][1],
				player.global_position.y])
		var d: Vector3 = goal - player.global_position
		d.y = 0.0
		if d.length() < 0.35:
			heights.append(player.global_position.y)
			leg += 1
			continue
		player.velocity = d.normalized() * 3.0
		player.velocity.y = -3.0
		player.move_and_slide()
		steps += 1
	_check(heights.size() >= 3, "the climb completes its legs (%d)"
			% heights.size())
	if heights.size() >= 3:
		_check(heights[1] > 1.4 and heights[1] < 1.8,
				"WEST ARM NORTH reaches the half-landing at z %.2f" % heights[1])
		_check(heights[2] > 1.4 and heights[2] < 1.8,
				"the turn crosses it at z %.2f" % heights[2])
	var top := player.global_position.y
	_check(top > 2.5,
			"AND THE EAST ARM SOUTH CLIMBS TO z %.2f, toward F02's floor at "
					% top + "3.20 — the plate's UP is the real UP")
	_check(top > heights[0],
			"every leg gained height: %.2f -> %.2f" % [heights[0], top])

	# --- no cue points anywhere false ---------------------------------------
	var legends := _legends(plate)
	var joined := " ".join(PackedStringArray(legends))
	_check(joined.contains("FLOOR 1 — STREET"),
			"F01's plate says street level is THIS floor: \"%s\""
					% joined.strip_edges())
	_check(not joined.contains("↓"),
			"and CLAIMS NOTHING ABOUT DOWN, which is the honest position: "
					+ "street level is this floor and up is 2-6, both true")
	for word in ["CELLAR", "BASEMENT", "ELEVATOR", "LIFT"]:
		_check(not joined.contains(word),
				"and never sends anyone to the %s" % word.to_lower())
	var fire := " ".join(PackedStringArray(_legends(
			root.find_child("FireDirection_F01", true, false))))
	_check(fire.contains("STREET LEVEL — THIS FLOOR")
			and not fire.contains("STREET LEVEL ↓"),
			"K2-D's reported F01 street-level lie is corrected")
	_check(fire.contains("FIRE EXIT — STAIRS  →"),
			"and K2-D's corridor arrow is undisturbed")
	# Upper floors: still true, and DOWN appears where a floor below exists.
	var f03 := " ".join(PackedStringArray(_legends(
			root.find_child("LandingPlate_F03", true, false))))
	_check(f03.contains("FLOOR 3") and f03.contains("↑") and f03.contains("↓"),
			"F03 offers both up and down: \"%s\"" % f03.strip_edges())
	var f06 := " ".join(PackedStringArray(_legends(
			root.find_child("LandingPlate_F06", true, false))))
	_check(not f06.contains("↑") and f06.contains("TOP FLOOR"),
			"and the top floor offers no up")

	# --- nothing else moved --------------------------------------------------
	var before := var_to_bytes(RealityState.data)
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
	var after := var_to_bytes(RealityState.data)
	for i in 20:
		var r := PhysicsRayQueryParameters3D.create(eye, plate.global_position)
		r.exclude = [player.get_rid()]
		space.intersect_ray(r)
	_check(var_to_bytes(RealityState.data) == after,
			"TWENTY LOOKS AT THE PLATE MUTATE NOTHING")
	_check(not RealityState.data.has("landing_plates")
			and not RealityState.data.has("stair_hint"),
			"K2-E wrote no save key of its own")

	# --- save/resume needs no tutorial fact ---------------------------------
	var saved := var_to_bytes(RealityState.data)
	(root.get("objective_tracker")).call("clear")
	director.call("present_resume")
	_check(str((root.get("objective_tracker"))._objective.text) == card,
			"a resume reconstructs the same intention")
	_check(var_to_bytes(RealityState.data) == saved, "and commits nothing")
	_check(root.find_child("LandingPlate_F01", true, false) != null,
			"and the plate is STILL THERE — it was never tutorial state")
	_finish()


## Walk and report where the body ended.
func _walk(from: Array, to: Array, cap: int) -> Vector3:
	player.global_position = GameBoot.b2g([from[0], from[1], 0.30])
	player.velocity = Vector3.ZERO
	var steps := 0
	while steps < cap:
		var goal := GameBoot.b2g([to[0], to[1], player.global_position.y])
		var d: Vector3 = goal - player.global_position
		d.y = 0.0
		if d.length() < 0.20:
			break
		player.velocity = d.normalized() * 3.0
		player.velocity.y = -3.0
		player.move_and_slide()
		steps += 1
	return player.global_position


## Walk and report the LOWEST height touched on the way.
func _walk_low(from: Array, to: Array, cap: int) -> float:
	player.global_position = GameBoot.b2g([from[0], from[1], 0.30])
	player.velocity = Vector3.ZERO
	var lo := 99.0
	var steps := 0
	while steps < cap:
		var goal := GameBoot.b2g([to[0], to[1], player.global_position.y])
		var d: Vector3 = goal - player.global_position
		d.y = 0.0
		if d.length() < 0.25:
			break
		player.velocity = d.normalized() * 3.0
		player.velocity.y = -3.0
		player.move_and_slide()
		lo = minf(lo, player.global_position.y)
		steps += 1
	return lo


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


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [landing live ok] ", label)
	else:
		failures += 1
		printerr("  [LANDING LIVE FAIL] ", label)


func _finish() -> void:
	print("LANDING PLATE LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
