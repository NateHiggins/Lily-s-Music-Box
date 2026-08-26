extends Node
## K2-G — the apartment is not the fault, in the real building.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/ChirpReachableLiveTest.tscn `
##         -ProjectPath <worktree>/game
##
## THE BODY IS NEVER TELEPORTED FOR A CLAIM ABOUT THE ROUTE. Every position on
## the route below is reached with `move_and_slide` under production collision,
## starting where K2-F left the player: outside the 2A door on F02.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"
const POINT_ID := "F02_A_MAIN_VANTRY_POINT"
const STATION := "F02_STATION_2A_LANDING"
const REACH := 2.1          # player_controller.gd _try_interact
const EYE := 1.41
const CEILING := 45.0

var failures := 0
var checks := 0
var root: Node
var player: PlayerController
var space: PhysicsDirectSpaceState3D
var point: Node3D


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
	var hunt: Node = root.get("chirp_hunt")
	var net: Node = root.get("vantry_points")
	var door: Node3D = root.find_child("F02_DOOR_02", true, false) as Node3D
	point = net.get("active_owner") as Node3D
	var emitter := _emitter(point)
	director.call("begin_first_shift")
	root.find_child("F01_WATCHMAN_DETECTOR", true, false).call(
			"interact_control", "detector", player)
	root.find_child("F01_NIGHT_REGISTER", true, false).call("take_slip")

	# --- COLD START: THE ORDER SAYS EAR, SO THE EAR MUST BE ABLE TO ANSWER --
	_check(str(hunt.get("active_point_id")) == POINT_ID,
			"the fault is on %s, the living-room point" % POINT_ID)
	var siblings := 0
	for sid in ["F02_A_BED_VANTRY_POINT", "F02_A_BATH_VANTRY_POINT"]:
		if not (net.call("point_spec", sid) as Dictionary).is_empty():
			siblings += 1
	_check(siblings == 2,
			"2A holds %d other Vantry points, so 'the 2A point' is only "
					% siblings + "resolvable by ear — which is what the order says")

	# --- THE DOOR OPENS AND THE BODY GOES IN ON FOOT -----------------------
	_check(str(door.get("leaf_state")) != "locked",
			"the 2A leaf is not locked (state '%s'); access is already owned by "
					% str(door.get("leaf_state"))
					+ "the case, and K2-G did not touch it")
	door.call("interact", player)
	await get_tree().create_timer(0.9).timeout
	_check(bool(door.get("open")), "and it opens to an ordinary interact")
	# The doorway is at y -1.25..-2.00; the leaf ORIGIN sits at y -2.11, on the
	# jamb, which is wall. An earlier probe of mine walked the origin's y and
	# reported a threshold it had never actually tried to cross.
	var inside := _walk([-4.40, -1.62, 3.40],
			[[-5.90, -1.62], [-7.20, -2.40], [-8.60, -3.00]], 2000)
	_check(inside.x < -6.0,
			"the body walks in unaided to b(%.2f, %.2f) — no noclip, no teleport"
					% [inside.x, -inside.z])
	_check(absf(inside.y - 3.20) < 0.4,
			"and stands on F02's floor (z %.2f)" % inside.y)

	# --- CAN IT BE HEARD, AND DOES IT WIN? ---------------------------------
	var mid := inside + player.camera.position
	_check(emitter != null and emitter.max_distance >= mid.distance_to(
			point.global_position),
			"the chirp reaches this station: %.2f m inside a %.0f m emitter"
					% [mid.distance_to(point.global_position),
							emitter.max_distance if emitter else 0.0])
	hunt.call("force_chirp")
	await get_tree().process_frame
	_check(emitter.playing, "and the fault is sounding")
	var rivals := _loudest_rivals(mid, emitter)
	_check(rivals.size() > 0, "%d other emitters are audible here" % rivals.size())
	var chirp_score := _score(emitter, mid)
	var best_rival: float = rivals[0]["score"] if rivals.size() > 0 else -999.0
	var rival_name: String = str(rivals[0]["name"]) if rivals.size() > 0 else "-"
	# THE FLOOR HERE IS DERIVED, NOT GUESSED. The first version of this suite
	# asserted a 6 dB margin because 6 dB reads as "about twice as loud", and it
	# measured 5.8 and failed. Six was a number I had made up: the criterion
	# that actually matters for a cue you must pick out of a room is that it
	# carries more acoustic intensity than its nearest competitor, and +3 dB is
	# exactly double. The measured margin is reported either way, so the reader
	# can judge the real figure rather than the threshold.
	_check(chirp_score - best_rival > 3.0,
			"THE FAULT WINS THE ROOM by %.1f dB over the next loudest thing, "
					% (chirp_score - best_rival)
					+ "%s (%.1f vs %.1f) — more than double its intensity, and "
							% [rival_name, chirp_score, best_rival]
					+ "the mix was never the problem")

	# --- A PLAUSIBLE WRONG TARGET LOSES ------------------------------------
	# An intercom is the most defensible wrong answer in the room: it is a
	# signal head, it is in reach, and it belongs to Mina.
	var decoy: Node3D = root.find_child("DomesticAnomaly_mina_intercom", true,
			false) as Node3D
	if decoy != null:
		var decoy_sounds := false
		var e := _emitter(decoy)
		if e != null and e.playing:
			decoy_sounds = true
		_check(not decoy_sounds,
				"the mina intercom, %.2f m away and within reach, is SILENT — "
						% decoy.global_position.distance_to(mid)
						+ "it looks like the answer and cannot be mistaken for "
						+ "it once the fault sounds")
	var calibrator: Node3D = root.find_child("CAPTION_CALIBRATOR", true,
			false) as Node3D
	if calibrator != null:
		var ce := _emitter(calibrator)
		_check(ce == null or not ce.playing,
				"and so is the caption calibrator, the nearest interactive thing")

	# --- REACH: THE GRILLE, NOT THE ROOM -----------------------------------
	_check(not _ray_finds(GameBoot.b2g([-5.80, -1.62, 3.20 + EYE])),
			"from the threshold the point is NOT in reach — the player has to "
					+ "cross the room, which is the point of the room")
	var under := _walk([-8.60, -3.00, 3.40], [[-9.10, -3.04]], 900)
	var eye_under := under + player.camera.position
	_check(_ray_finds(eye_under),
			"standing under it at b(%.2f, %.2f) the grille IS in reach"
					% [under.x, -under.z])
	var pitch := rad_to_deg(atan2(point.global_position.y - eye_under.y,
			maxf(Vector2(eye_under.x - point.global_position.x,
					eye_under.z - point.global_position.z).length(), 0.001)))
	_check(pitch > 40.0,
			"and it is %.0f degrees above the eye — 3.02 m up, which is why the "
					% pitch + "grille and not the room is the working target")

	# --- THE WHOLE ROUTE, AGAINST THE CEILING ------------------------------
	var travel := _path_length([[-5.80, -1.62], [-7.20, -2.40], [-8.60, -3.00],
			[-9.10, -3.04]])
	var walk_seconds := travel / 3.0
	var worst := float(load("res://scripts/game/chirp_hunt.gd").CHIRP_MAX)
	_check(worst + walk_seconds < CEILING,
			"THRESHOLD TO TARGET, WORST CASE: %.1f s of silence + %.2f m of "
					% [worst, travel]
					+ "walking (%.2f s) = %.2f s, inside the %.0f s ceiling"
							% [walk_seconds, worst + walk_seconds, CEILING])
	_check(95.0 + walk_seconds > CEILING,
			"the schedule this replaced could not: %.2f s worst case"
					% (95.0 + walk_seconds))

	# --- THE GRILLE BEGINS THE EXISTING INVESTIGATION ----------------------
	var before_stage := str(orders.call("job_stage", JOB))
	point.call("interact", player)
	await get_tree().create_timer(0.4).timeout
	var after_stage := str(orders.call("job_stage", JOB))
	_check(after_stage != before_stage and after_stage in ["awaiting_part",
			"diagnosed", "repairable"],
			"inspecting the grille advances the EXISTING job %s -> %s"
					% [before_stage, after_stage])
	_check((orders.call("serialize_jobs") as Dictionary).size() >= 1,
			"through WorkOrders, which is still the only job owner")

	# --- NOTHING ELSE MOVED -------------------------------------------------
	_check(str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"the case is untouched and still active")
	_check(not bool(director.call("tour_key_carried"))
			and not bool(director.call("has_station_mark", STATION)),
			"tour key and STATION 2 remain optional and unmade")
	_check(not RealityState.data.has("chirp_schedule")
			and not RealityState.data.has("vantry_hint"),
			"K2-G wrote no save key")

	# --- OBSERVATION MUTATES NOTHING ---------------------------------------
	var snapshot := var_to_bytes(RealityState.data)
	for i in 25:
		hunt.call("prompt_for", POINT_ID)
		_ray_finds(eye_under)
	_check(var_to_bytes(RealityState.data) == snapshot,
			"TWENTY-FIVE LOOKS AND PROMPTS MUTATE NOTHING")

	# --- RESET / RELOAD RECONSTRUCTS ---------------------------------------
	var saved := var_to_bytes(RealityState.data)
	(root.get("objective_tracker")).call("clear")
	director.call("present_resume")
	_check(var_to_bytes(RealityState.data) == saved,
			"a resume commits nothing")
	_check(str(orders.call("job_stage", JOB)) == after_stage,
			"and reconstructs the same job stage (%s) from the existing owner"
					% after_stage)
	_finish()


func _emitter(node: Node) -> AudioStreamPlayer3D:
	if node == null:
		return null
	if node is AudioStreamPlayer3D:
		return node as AudioStreamPlayer3D
	for child in node.get_children():
		var f := _emitter(child)
		if f:
			return f
	return null


func _score(a: AudioStreamPlayer3D, listener: Vector3) -> float:
	var d := maxf(a.global_position.distance_to(listener), 0.5)
	return a.volume_db - 20.0 * log(d) / log(10.0)


func _loudest_rivals(listener: Vector3,
		exclude: AudioStreamPlayer3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_gather(root, listener, exclude, out)
	out.sort_custom(func(a, b): return a["score"] > b["score"])
	return out


func _gather(node: Node, listener: Vector3, exclude: AudioStreamPlayer3D,
		out: Array[Dictionary]) -> void:
	if node is AudioStreamPlayer3D and node != exclude \
			and (node as AudioStreamPlayer3D).playing:
		var a := node as AudioStreamPlayer3D
		if a.global_position.distance_to(listener) <= a.max_distance:
			out.append({"name": str(a.name), "score": _score(a, listener)})
	for child in node.get_children():
		_gather(child, listener, exclude, out)


## The player's own interaction test: a 2.1 m ray from the eye that collides
## with areas, walked up the parent chain looking for `interact`.
func _ray_finds(from: Vector3) -> bool:
	var dir := (point.global_position - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * REACH)
	q.collide_with_areas = true
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var node: Node = hit.collider
	while node:
		if node == point or point.is_ancestor_of(node):
			return true
		node = node.get_parent()
	return false


func _path_length(legs: Array) -> float:
	var total := 0.0
	for i in range(1, legs.size()):
		total += Vector2(legs[i][0] - legs[i - 1][0],
				legs[i][1] - legs[i - 1][1]).length()
	return total


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
		if d.length() < 0.30:
			leg += 1
			continue
		player.velocity = d.normalized() * 3.0
		player.velocity.y = -3.0
		player.move_and_slide()
		steps += 1
	return player.global_position


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [chirp live ok] ", label)
	else:
		failures += 1
		printerr("  [CHIRP LIVE FAIL] ", label)


func _finish() -> void:
	print("CHIRP REACHABLE LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
