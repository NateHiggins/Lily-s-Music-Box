extends Node
## K2-D — the paired stair plate in the real building, and the route it claims.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/StairDirectionLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## NOBODY IS TELEPORTED FOR A CLAIM. The player is left where
## `begin_first_shift` puts them; the route is proved by walking a CharacterBody
## through it with the production collision, not by moving the camera.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"
const STATION := "F02_STATION_2A_LANDING"
## The pose the paper comes off the spindle at.
const POSE := [4.84, -2.27, 1.62]

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
	var tracker: Node = root.get("objective_tracker")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	var guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	var pair: Node3D = root.find_child("StairDirectionPair_F01", true,
			false) as Node3D
	var fire: Node3D = root.find_child("FireDirection_F01", true, false) as Node3D
	var pose := GameBoot.b2g(POSE)

	# --- THE AUDIT, RE-ASSERTED ---------------------------------------------
	# The east corridor's west wall, at body height, on every residential floor.
	for row in [["F01", 0.0], ["F02", 3.2], ["F03", 6.4], ["F04", 9.6],
			["F05", 12.8], ["F06", 16.0]]:
		var base: float = row[1]
		var north := 0
		var south := 0
		var by := 4.4
		while by >= -9.6:
			var q := PhysicsRayQueryParameters3D.create(
					GameBoot.b2g([4.60, by, base + 1.00]),
					GameBoot.b2g([2.60, by, base + 1.00]))
			q.exclude = [player.get_rid()]
			if space.intersect_ray(q).is_empty():
				if by > 2.92:
					north += 1
				else:
					south += 1
			by -= 0.4
		_check(south > 0 and north == 0,
				"%s: the corridor opens west ONLY south of the plate "
						% row[0] + "(%d south, %d north)" % [south, north])

	# --- the cue is where a fresh player will meet it ------------------------
	_check(pair != null, "THE PAIRED PLATE IS IN THE PRODUCTION CORRIDOR")
	var to: Vector3 = pair.global_position - pose
	_check(to.length() < 1.6,
			"and it is %.2f m from the acceptance pose" % to.length())
	var q := PhysicsRayQueryParameters3D.create(pose, pair.global_position)
	q.exclude = [player.get_rid()]
	_check(space.intersect_ray(q).is_empty(),
			"with a clear line from the desk")
	# The desk faces east; the plate is behind. A single turn puts it dead
	# ahead — no walking at all.
	var facing_desk := Vector3(1, 0, 0)
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var behind := rad_to_deg(facing_desk.angle_to(flat))
	_check(behind > 150.0,
			"it is %.0f deg behind the desk — ONE TURN, ZERO BLIND WALKING"
					% behind)
	_check(pair.transform.basis.z.x > 0.99,
			"and it faces east, so that turn reads it head-on")

	# --- ITS DIRECTION AGREES WITH THE ONLY TRAVERSABLE ROUTE ---------------
	# A reader of the pair faces WEST; "←" is their left, which is SOUTH.
	# Walk a body south down the corridor and prove the opening is there.
	var opened_at := 0.0
	var y := -2.27
	while y >= -9.6:
		var w := PhysicsRayQueryParameters3D.create(
				GameBoot.b2g([4.60, y, 1.00]), GameBoot.b2g([2.60, y, 1.00]))
		w.exclude = [player.get_rid()]
		if space.intersect_ray(w).is_empty():
			opened_at = y
			break
		y -= 0.2
	_check(opened_at < -6.0 and opened_at > -9.6,
			"WALKING SOUTH AS THE PLATE SAYS, the corridor opens west at "
					+ "y %.2f" % opened_at)
	# And that it is NOT the elevator, the basement, the street or a dead end.
	var lift: Node3D = root.find_child("LobbyServiceDumbwaiter", true,
			false) as Node3D
	if lift != null:
		var lift_b := -lift.global_position.z
		_check(absf(lift_b - opened_at) > 1.5,
				"which is %.2f m from the service lift — not the lift"
						% absf(lift_b - opened_at))
	var floor_here := PhysicsRayQueryParameters3D.create(
			GameBoot.b2g([2.00, opened_at, 2.0]),
			GameBoot.b2g([2.00, opened_at, -0.6]))
	var fh := space.intersect_ray(floor_here)
	_check(not fh.is_empty() and absf(fh.position.y) < 0.35,
			"and there is ground-floor decking through it, not a shaft "
					+ "(z %.2f)" % (fh.position.y if not fh.is_empty() else -9.0))

	# --- a BODY can actually make the trip ----------------------------------
	# Step the production player along the route with real collision. This is
	# the only place the player is moved, and it is moved by `move_and_slide`,
	# not by assignment.
	var start := GameBoot.b2g([4.60, -2.27, 0.10])
	player.global_position = start
	player.velocity = Vector3.ZERO
	var steps := 0
	var reached_opening := false
	while steps < 240:
		var target := GameBoot.b2g([4.60, -8.20, 0.10]) if not reached_opening \
				else GameBoot.b2g([1.20, -8.20, 0.10])
		var delta: Vector3 = target - player.global_position
		delta.y = 0.0
		if delta.length() < 0.25:
			if not reached_opening:
				reached_opening = true
			else:
				break
		player.velocity = delta.normalized() * 3.0
		player.velocity.y = -2.0
		player.move_and_slide()
		steps += 1
	var here := player.global_position
	_check(reached_opening,
			"A BODY WALKS SOUTH DOWN THE CORRIDOR under production collision")
	_check(here.x < 2.6,
			"and turns west through the opening to b(%.2f, %.2f)"
					% [here.x, -here.z])
	_check(absf(here.y) < 0.6,
			"still on the ground floor (z %.2f), not fallen through" % here.y)

	# --- the fire plate now agrees with its pair -----------------------------
	var fire_legends: Array[String] = []
	_sweep(fire, fire_legends)
	var fire_text := " ".join(PackedStringArray(fire_legends))
	_check(fire_text.contains("FIRE EXIT — STAIRS  →"),
			"THE OLD PLATE'S ARROW IS CORRECTED: it points south now")
	_check(not fire_text.contains("←  FIRE EXIT"),
			"and no longer points away from the only opening")

	# --- nothing else moved --------------------------------------------------
	var before := var_to_bytes(RealityState.data)
	_check(bool(director.call("begin_first_shift")), "the arrival commits")
	_check(bool(detector.call("interact_control", "detector", player)),
			"the player clocks in")
	_check(bool(register.call("take_slip")), "and takes the report")
	var card := str(tracker._objective.text)
	_check(card.begins_with("Unit 2A, one floor up."),
			"K2-C's card is untouched: \"%s\"" % card.substr(0, 26))
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"one work order")
	_check(str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"one case, active")
	_check(not bool(director.call("tour_key_carried"))
			and not bool(director.call("has_station_mark", STATION)),
			"and the optional key and station are still free and unmade")
	# A sign is not an interaction: looking at it a hundred times changes
	# nothing, because there is nothing to change.
	var after_look := var_to_bytes(RealityState.data)
	for i in 20:
		var r := PhysicsRayQueryParameters3D.create(pose, pair.global_position)
		r.exclude = [player.get_rid()]
		space.intersect_ray(r)
	_check(var_to_bytes(RealityState.data) == after_look,
			"TWENTY OBSERVATIONS OF THE PLATE MUTATE NOTHING")
	_check(not RealityState.data.has("stair_hint")
			and not RealityState.data.has("stair_pairs"),
			"K2-D wrote no save key of its own")

	# --- save/resume: the sign is fabric, not tutorial state ----------------
	var saved := var_to_bytes(RealityState.data)
	tracker.call("clear")
	director.call("present_resume")
	_check(str(tracker._objective.text) == card,
			"a resume reconstructs the same intention")
	_check(var_to_bytes(RealityState.data) == saved, "and commits nothing")
	_check(root.find_child("StairDirectionPair_F01", true, false) != null,
			"and the plate is STILL THERE, because it was never tutorial state")
	_finish()


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
		print("  [stair live ok] ", label)
	else:
		failures += 1
		printerr("  [STAIR LIVE FAIL] ", label)


func _finish() -> void:
	print("STAIR DIRECTION LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
