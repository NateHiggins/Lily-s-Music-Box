extends Node3D
## The dream as floor-is-lava parkour (order wd7c01339b8b0; Lily's rulings dream_parkour_*_20261117). In Mina's
## real dream: every live room has a course; every open doorway's sill reaches the room's table through perches the
## dream body can clear; the body wakes into the dream on a perch; standing on a perch is safe; standing on the floor
## pales it and wakes you after half a second with the director's `fall`; the Tenant cannot take a body above its
## reach; the dream body hauls itself up a ledge; and there is no time limit. With SHOT_DIR, frames from the perches.
const SEED_HEX := "f123456789abcdef"
const Parkour := preload("res://scripts/dream/dream_parkour.gd")

var checks := 0
var failures: Array[String] = []
var receipt := preload("res://tests/dream_contract_receipt.gd").new()
var root: DreamMazeRoot


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("DREAM PARKOUR: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func _overlaps(a: Array, b: Array, pad: float) -> bool:
	return a[0] < b[2] + pad and a[2] > b[0] - pad and a[1] < b[3] + pad and a[3] > b[1] - pad


## True when a body could stand at (x, z) on a room floor: a ray down meets a Floor, and nothing solid is in the way.
func _floor_at(x: float, z: float) -> bool:
	var space := root.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 2.5, z), Vector3(x, -0.5, z), 1, [root.player.get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or not str((hit.collider as Node).name).begins_with("Floor"):
		return false
	var body := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.5
	body.shape = capsule
	body.collision_mask = 1
	body.exclude = [root.player.get_rid()]
	body.transform = Transform3D(Basis(), Vector3(x, 0.8, z))
	return space.intersect_shape(body, 1).is_empty()


## Can a body standing on nodes[from] reach nodes[to]? A move is a hop of at most the course's gap that climbs at
## most its step (a drop may be any height); the walk runs the way a player does, from the doorway inward.
func _reaches(nodes: Array, from: int, to: int, limits: Vector2) -> bool:
	var seen := {from: true}
	var frontier: Array[int] = [from]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		if at == to:
			return true
		for j in nodes.size():
			if seen.has(j):
				continue
			var close := Parkour.gap(nodes[at].rect, nodes[j].rect) <= limits.x + 0.01
			var rise := float(nodes[j].top) - float(nodes[at].top)
			if close and rise <= limits.y + 0.001:
				seen[j] = true
				frontier.append(j)
	return false


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func run() -> void:
	receipt.begin("res://tests/dream_parkour_test.gd", "res://tests/DreamParkourTest.tscn")
	RealityState.persistence_enabled = false
	# A release print lends the subject's actual day, which needs a campaign date (Saturday 10 Nov 1928, 22:00).
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 1320)
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis", "profile_id": "mina_release_print", "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": ""})
	add_child(root)
	await _physics(4)
	var parkour: Node3D = root.parkour
	check(parkour != null, "the dream has its floor-is-lava course")
	if parkour == null:
		_finish()
		return
	var live: Dictionary = root.rooms._live
	var perches: Array = parkour.perches()
	var rooms_with_course := {}
	for p: Dictionary in perches:
		if not str(p.room).is_empty():
			rooms_with_course[str(p.room)] = true
	check(rooms_with_course.size() == live.size(), "every live room has a course (%d of %d)" % [rooms_with_course.size(), live.size()])

	# Fairness: in every live room each open door's sill reaches the table by moves the dream body can make.
	for key: String in live:
		var room: Dictionary = live[key]
		var nodes: Array = []
		var table := -1
		for p: Dictionary in perches:
			if str(p.room) == key:
				if str(p.role) == "middle":
					table = nodes.size()
				nodes.append(p)
		var sills: Array[int] = []
		for door: Dictionary in room.doors:
			if bool(door.sealed) or str(door.leads_to).is_empty():
				continue
			for p: Dictionary in perches:
				if str(p.kind) == "sill" and _overlaps(p.rect, door.aperture, 0.01):
					sills.append(nodes.size())
					nodes.append(p)
					break
		check(table >= 0, "%s has a table, desk or bed at its middle" % key)
		var limits: Vector2 = parkour.course_limits(key)
		if table < 0:
			continue
		for s in sills:
			check(_reaches(nodes, s, table, limits), "%s: a doorway reaches the table over perches, climbing inward" % key)

	var real := perches.filter(func(p: Dictionary) -> bool: return str(p.role) != "sill")
	check(real.all(func(p: Dictionary) -> bool: return (p.body as Node).has_meta("piece")), "every perch is a real piece of the building's furniture")
	var hops: Array = []
	for key: String in live:
		hops.append(snappedf(parkour.course_limits(key).x, 0.01))
	print("DREAM PARKOUR hops ", hops, " moving ", real.filter(func(p: Dictionary) -> bool: return not str(p.motion).is_empty()).size(), " of ", real.size())
	# The path overhead: the lineage redrawn as high, transparent tentacles, one to every open doorway.
	for key: String in live:
		var path: Dictionary = parkour._paths.get(key, {})
		var open_doors := (live[key].doors as Array).filter(func(d: Dictionary) -> bool: return not bool(d.sealed)).size()
		check(not path.is_empty() and (path.chains as Array).size() == open_doors, "%s: a tentacle overhead to every open doorway" % key)
		var low := 99.0
		for chain: PackedVector3Array in path.get("chains", []):
			for point: Vector3 in chain:
				low = minf(low, point.y)
		check(low >= 2.0, "%s: the tentacles run high, at the door heads and above (%.2f m)" % [key, low])
	var standing := get_tree().get_nodes_in_group("dream_lineage_bodies").filter(func(b: Node) -> bool: return (b as Node3D).is_visible_in_tree())
	check(standing.is_empty(), "the old gold lineage knots stand down where a course runs (%d still showing)" % standing.size())
	check(root.player.position.y > 0.3, "the body wakes into the dream on a perch, not the floor (y %.2f)" % root.player.position.y)
	check(not root.run_ceiling_folds, "there is no time limit")
	# Hazards by height (ruling dream_parkour_pressure_20261117): a hazard touches only a body overlapping its band.
	var belt := DreamHazard.new()
	belt.configure({"id": "laundry_mangle_belt", "kind": "triggered", "position": [0.0, 0.0], "clearance_radius_m": 0.45,
		"tell_radius_m": 5.5, "minimum_warning_s": 0.9, "band_m": [0.6, 1.2]}, {"outcome": "contact"})
	check(belt.reaches(0.0) and not belt.reaches(1.3), "the mangle belt reaches a body on the floor, not one on a perch above it")
	var runner := DreamHazard.new()
	runner.configure({"id": "hollow_runner", "kind": "conditional", "position": [0.0, 0.0], "clearance_radius_m": 0.35,
		"tell_radius_m": 4.6, "minimum_warning_s": 0.75, "band_m": [0.0, 0.25]}, {"outcome": "contact"})
	runner.evaluate(Vector3(0.0, 0.45, 0.0), false, 0.0, 0.0)
	check(runner.evaluate(Vector3(0.0, 0.45, 0.0), false, 0.0, 2.0) == "", "the floor runner keeps its warning and cannot touch a body on a chair")
	check(runner.evaluate(Vector3(0.0, 0.0, 0.0), false, 0.0, 2.1) == "contact", "on the floor, after its warning, it does")
	var sweep := DreamHazard.new()
	sweep.configure({"id": "boiler_relief_sweep", "kind": "rhythmic", "position": [0.0, 0.0], "clearance_radius_m": 0.45,
		"tell_radius_m": 6.0, "minimum_warning_s": 1.0, "band_m": [0.7, 1.7], "rhythm_s": [5.0, 1.2]}, {"outcome": "contact"})
	check(sweep.live_at(4.0) and not sweep.live_at(2.0), "the relief sweep is live only in its window of each beat")
	check(is_equal_approx(Parkour.steam_amount(4.0, Vector2(5.0, 1.2)), 1.0) and Parkour.steam_amount(2.0, Vector2(5.0, 1.2)) == 0.0
			and Parkour.steam_amount(3.3, Vector2(5.0, 1.2)) > 0.0, "its steam builds through the tell before each live window")
	check(Parkour.BEAT_TELL_S >= 1.0, "the steam's tell is no shorter than the sweep's warning")
	check(is_equal_approx(root.player.jump_velocity, root.DREAM_JUMP_MPS) and root.player.mantle_enabled, "the dream body jumps higher and can mantle")

	# Standing on a perch for a second is safe.
	root.player.set_physics_process(true)
	for i in 60:
		root._parkour_step(1.0 / 60.0)
		await get_tree().physics_frame
	check(not parkour.woken and parkour.lava_s == 0.0, "a perch is safe: %.2f s on the floor clock" % parkour.lava_s)
	check(not root.pursuer._within_reach(), "the Tenant cannot take a body standing on a perch")
	# Inside the Cell, second round: the trail where the body has stood, and fibres round every open door frame.
	check(root.body_trail != null and root.body_trail.marks() > 0, "the cell's trail lies where the body stood (%d marks)" % (root.body_trail.marks() if root.body_trail != null else 0))
	var skins: Node = root.membranes
	check(skins != null and skins.count() > 0, "the cell's skin spans the open doorways (%d)" % (skins.count() if skins != null else 0))
	if skins != null:
		check(skins.fibre_count() >= 40 * skins.count(), "fibres grow round every door frame (%d on %d frames)" % [skins.fibre_count(), skins.count()])
		var wild := 0
		for door: Dictionary in root.plan.get("doors", []):
			var height := float(door.get("height", 2.13))
			for f: Dictionary in skins.fibre_roots(door):
				var at: Vector3 = f.at
				if at.y < 0.1 or at.y > height + 0.1:
					wild += 1
		check(wild == 0, "every fibre is rooted on its frame, between the sill and the head (%d astray)" % wild)

	# The mantle: from the floor, push into the table and haul up onto it.
	var here: Dictionary = live[root._here_key]
	var r: Array = here.rect
	var table_rect: Array = []
	for p: Dictionary in perches:
		if str(p.room) == root._here_key and str(p.role) == "middle":
			table_rect = p.rect
	var mid := Vector3((table_rect[0] + table_rect[2]) * 0.5, 0.0, (table_rect[1] + table_rect[3]) * 0.5)
	var front := Vector3.INF
	var push := Vector3.ZERO
	for side: Array in [[Vector3(mid.x, 0.02, float(table_rect[1]) - 0.5), Vector3(0, 0, 1)], [Vector3(mid.x, 0.02, float(table_rect[3]) + 0.5), Vector3(0, 0, -1)],
			[Vector3(float(table_rect[0]) - 0.5, 0.02, mid.z), Vector3(1, 0, 0)], [Vector3(float(table_rect[2]) + 0.5, 0.02, mid.z), Vector3(-1, 0, 0)]]:
		if _floor_at(side[0].x, side[0].z):
			front = side[0]
			push = side[1]
			break
	check(front.is_finite(), "there is floor beside the table to mantle from")
	root.player.global_position = front if front.is_finite() else root.player.global_position
	root.player.velocity = Vector3.ZERO
	root.player.autopilot = push
	var topped := false
	for i in 120:
		await get_tree().physics_frame
		if root.player.global_position.y > 0.7:
			topped = true
			break
	root.player.autopilot = Vector3.ZERO
	# Let the haul finish before the body is moved anywhere else.
	for i in 30:
		await get_tree().physics_frame
	check(topped, "pushing into the table, the dream body hauls itself up onto it (y %.2f)" % root.player.global_position.y)

	# The floor: half a second paling, then the hypnic jerk.
	var open := Vector3.INF
	for gx in 12:
		for gz in 12:
			var x := lerpf(float(r[0]) + 0.5, float(r[2]) - 0.5, gx / 11.0)
			var z := lerpf(float(r[1]) + 0.5, float(r[3]) - 0.5, gz / 11.0)
			if _floor_at(x, z) and not open.is_finite():
				open = Vector3(x, 0.05, z)
	check(open.is_finite(), "the room has open floor to test")
	root.player.global_position = open
	root.player.velocity = Vector3.ZERO
	await _physics(3)
	var under := []
	for i in root.player.get_slide_collision_count():
		under.append(str((root.player.get_slide_collision(i).get_collider() as Node).name))
	check(root.pursuer._within_reach(), "on the floor the Tenant can reach the body (y %.2f, on %s)" % [root.player.global_position.y, under])
	var woke_at := -1.0
	var elapsed := 0.0
	for i in 90:
		elapsed += 1.0 / 60.0
		if root._parkour_step(1.0 / 60.0) and woke_at < 0.0:
			woke_at = elapsed
		await get_tree().physics_frame
	check(parkour.woken and root.last_outcome_requested == "fall", "the floor wakes the body with the director's fall")
	check(woke_at >= Parkour.GRACE_S - 0.05 and woke_at <= Parkour.GRACE_S + 0.12, "after about half a second of paling (%.2f s)" % woke_at)

	# By the live capsule: through the hazard field, a crouched body clears the signal trunk's head-height band and a
	# standing one meets it, its warning first (Codex's PR 341 review).
	var trunk := DreamHazard.new()
	trunk.configure({"id": "vantry_signal_trunk", "kind": "conditional", "position": [root.player.global_position.x, root.player.global_position.z],
		"clearance_radius_m": 0.35, "tell_radius_m": 5.5, "minimum_warning_s": 0.9, "band_m": [1.4, 2.2]}, {"outcome": "contact"})
	var kept: Array = root.hazards.hazards.duplicate()
	root.hazards.hazards.assign([trunk])
	root.player.set_physics_process(false)
	root.player.call("_set_crouched", true)
	check(root.player.body_height() < 1.4, "crouched, the capsule is under the trunk's band (%.2f m)" % root.player.body_height())
	var crouched_hit := ""
	for i in 90:
		crouched_hit = root.hazards.advance_fixed(1.0 / 60.0)
		if not crouched_hit.is_empty():
			break
	check(crouched_hit.is_empty(), "a crouched body passes under the trunk")
	root.player.call("_set_crouched", false)
	var standing_hit := ""
	for i in 90:
		standing_hit = root.hazards.advance_fixed(1.0 / 60.0)
		if not standing_hit.is_empty():
			break
	check(standing_hit == "contact", "standing, the same body meets it")
	root.hazards.hazards.assign(kept)
	var shots := OS.get_environment("SHOT_DIR")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		root.player.set_physics_process(false)
		root.player.camera.make_current()
		var spawn: Vector3 = parkour.spawn_on(root._here_key)
		var n := 0
		for yaw: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			root.player.global_position = spawn
			root.player.rotation.y = yaw
			for f in 12:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shots.path_join("perch_%d.png" % n))
			n += 1
	_finish()


func _finish() -> void:
	for problem: String in receipt.finish("dream_parkour", "res://tests/dream_parkour_test.gd", "res://tests/DreamParkourTest.tscn", "Mina's dream as floor-is-lava parkour: courses per live room, doorway-to-middle reach, perch spawn, perch safety, Tenant reach, mantle, floor wake with fall after the grace, path tentacles, Inside the Cell trail and fibres. Isolated dream root; no play, art or performance acceptance.", checks, failures):
		failures.append(problem)
		print("DREAM PARKOUR: [FAIL] ", problem)
	print("DREAM PARKOUR RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
