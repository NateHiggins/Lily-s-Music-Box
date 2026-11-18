extends "res://tests/orison_v2_vertical_route_test.gd"
## The edge of the walkable city (ruling barrier_distance, 2026-11-07): in the
## production V2 world, the player walks outward with normal input, the mist
## gathers from 150 m, she passes out at 200 m before touching the physical
## wall, and wakes standing at the 4B bedside able to walk. A second leg holds
## her in another owner's lock at the edge: the mist must not take her until
## that owner releases her. Writes a schema-2 runtime_contract.
const Mist := preload("res://scripts/building/orison_v2_city_edge_mist.gd")
const Boundaries := preload("res://scripts/building/orison_v2_street_boundaries.gd")
const STANDING_MASK := 1
const START_RADIUS_M := 185.0
const SEARCH_ANGLES: Array[float] = [0.0, 0.35, -0.35, 0.7, -0.7, PI, PI - 0.35, PI + 0.35, PI / 2, -PI / 2]

var checks: Array[Dictionary] = []
var boundary: Node3D
var mist: OrisonV2CityEdgeMist
var leg_samples: Array[Dictionary] = []
var started_ms := 0
var shots_taken: Dictionary = {}


func _init() -> void:
	route_label = "V2 CITY EDGE MIST"


func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"label": label, "ok": ok, "detail": str(detail) if detail != null else ""})
	if not ok:
		failures.append(label + ("" if detail == null else ": " + str(detail)))
		push_error(route_label + ": " + label + " " + str(detail))


func _route() -> void:
	started_ms = Time.get_ticks_msec()
	boundary = world.get_node_or_null("StreetBoundaries") as Node3D
	check(boundary != null, "production world composes StreetBoundaries")
	if boundary == null:
		_write_receipt()
		return
	mist = boundary.get_node_or_null("CityEdgeMist") as OrisonV2CityEdgeMist
	check(mist != null, "the city edge mist is mounted in the threshold frame")
	var limit := boundary.get_node_or_null("TemporaryExteriorLimit") as StaticBody3D
	check(limit != null, "the physical backstop wall remains")
	if mist == null or limit == null:
		_write_receipt()
		return
	# Ruling numbers, and the wall strictly beyond the pass-out ring.
	check(is_equal_approx(Mist.MIST_START_M, 150.0) and is_equal_approx(Mist.PASS_OUT_M, 200.0),
			"mist gathers from 150 m and takes her at 200 m", [Mist.MIST_START_M, Mist.PASS_OUT_M])
	var wall_m := float(limit.get_meta("radius_m"))
	check(wall_m > Mist.PASS_OUT_M and wall_m <= Mist.PASS_OUT_M + 10.0,
			"the physical wall stands just beyond the pass-out ring", wall_m)
	check(is_zero_approx(Mist.mist_at(149.0)) and Mist.mist_at(175.0) > 0.2 and Mist.mist_at(175.0) < 0.8
			and is_equal_approx(Mist.mist_at(200.0), 1.0), "mist density rises across the stretch",
			[Mist.mist_at(149.0), Mist.mist_at(175.0), Mist.mist_at(200.0)])
	var bedside: Dictionary = world.core_loop.resolve_return_anchor() if world.core_loop != null else {}
	check(not bedside.is_empty(), "the production 4B bedside resolves")
	if bedside.is_empty():
		_write_receipt()
		return
	var lane := _find_open_lane()
	check(not lane.is_empty(), "an open, floored radial lane exists from 185 m past the edge", lane)
	if lane.is_empty():
		_write_receipt()
		return
	var loop_before: Dictionary = world.core_loop.loop_state()
	var minute_before: Variant = world.campaign_clock.get("campaign_minute") if world.campaign_clock != null else null

	# Leg 1: normal walking outward until the mist takes her.
	await _place(lane.start)
	var outward: Vector3 = lane.direction
	var took_at := -1.0
	var max_radius := 0.0
	var prior_mist := -1.0
	var mist_never_fell := true
	var touched_wall := false
	var saw_partial := false
	var ticks := 0
	while ticks < 60 * 40 and mist.phase() == "clear":
		player.rotation.y = atan2(-outward.x, -outward.z)
		player.camera.rotation = Vector3.ZERO
		Input.action_press("move_forward", 1.0)
		await get_tree().physics_frame
		ticks += 1
		var r := mist.radius_of(player.global_position)
		max_radius = maxf(max_radius, r)
		if mist.mist() + 0.0001 < prior_mist and r > Mist.MIST_START_M:
			mist_never_fell = false
		prior_mist = mist.mist()
		if mist.mist() > 0.05 and mist.mist() < 0.95:
			saw_partial = true
		for index in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_collider() == limit:
				touched_wall = true
		if ticks % 15 == 0:
			leg_samples.append({"leg": "walk_out", "radius_m": snappedf(r, 0.01), "mist": snappedf(mist.mist(), 0.001), "phase": mist.phase()})
		if mist.phase() != "clear":
			took_at = r
		for shot: Array in [[0.45, "mist_half"], [0.9, "mist_thick"]]:
			if mist.mist() >= float(shot[0]) and not shots_taken.has(shot[1]):
				shots_taken[shot[1]] = true
				await _shot_named(str(shot[1]))
	Input.action_release("move_forward")
	check(took_at >= Mist.PASS_OUT_M and took_at < Mist.PASS_OUT_M + 1.0,
			"walking with normal input, she passes out at the 200 m ring", took_at)
	check(saw_partial and mist_never_fell, "the mist thickened steadily on the way out")
	check(not touched_wall and max_radius < wall_m, "she never reached the physical wall", [max_radius, wall_m])
	check(player.call_locked, "passing out holds her movement and look")
	# Fade, wake, hold, fade in: let the production clock run it.
	var wake_ticks := 0
	var black_seen := false
	while mist.phase() != "clear" and wake_ticks < 60 * 15:
		await get_tree().physics_frame
		wake_ticks += 1
		if mist.blackout() > 0.99:
			black_seen = true
	check(black_seen, "the screen went fully black while she was moved")
	check(mist.phase() == "clear" and mist.last_wake_ok(), "she woke and the presentation cleared", mist.phase())
	var at_bed: float = Vector2(player.global_position.x - bedside.position.x, player.global_position.z - bedside.position.z).length()
	check(at_bed < 0.25 and absf(player.global_position.y - bedside.position.y) < 0.6,
			"she wakes standing at the 4B bedside", [player.global_position, bedside.position])
	check(not player.call_locked, "waking releases her movement")
	check(is_zero_approx(mist.mist()) and is_zero_approx(mist.blackout()), "no mist or blackout remains in 4B")
	var loop_after: Dictionary = world.core_loop.loop_state()
	check(loop_after == loop_before, "passing out advanced no campaign loop boundary", [loop_before, loop_after])
	if minute_before != null:
		check(world.campaign_clock.get("campaign_minute") == minute_before, "passing out wrote no clock time")
	# She can walk after waking: normal input moves her inside 4B.
	var before_step := player.global_position
	for i in 20:
		Input.action_press("move_back", 1.0)
		await get_tree().physics_frame
	Input.action_release("move_back")
	await get_tree().physics_frame
	check(player.global_position.distance_to(before_step) > 0.05, "normal input moves her after waking")

	# Leg 2: another owner holds her at the edge; the mist waits for them.
	# The hold comes first: placement runs physics frames, and an unheld
	# player standing past the ring is (correctly) taken during them.
	var holder := Node.new()
	add_child(holder)
	player.begin_seated_interaction(holder)
	await _place(lane.edge)
	for i in 30:
		await get_tree().physics_frame
	check(mist.phase() == "clear" and mist.mist() > 0.99, "a held player stays in full mist and is not taken", [mist.phase(), mist.mist()])
	player.end_seated_interaction(holder)
	holder.free()
	var released_ticks := 0
	while mist.phase() == "clear" and released_ticks < 30:
		await get_tree().physics_frame
		released_ticks += 1
	check(mist.phase() == "fading", "once released at the edge, the mist takes her", mist.phase())
	while mist.phase() != "clear" and released_ticks < 60 * 15:
		await get_tree().physics_frame
		released_ticks += 1
	at_bed = Vector2(player.global_position.x - bedside.position.x, player.global_position.z - bedside.position.z).length()
	check(at_bed < 0.25 and not player.call_locked, "the second pass-out also wakes her free at the bedside", at_bed)
	await _shot_bed()
	_write_receipt()


## A radial lane in the threshold frame with standing floor at 185 m and at the
## edge, and no collider between 185 m and the wall except the wall itself.
func _find_open_lane() -> Dictionary:
	var space := world.get_world_3d().direct_space_state
	var limit := boundary.get_node("TemporaryExteriorLimit")
	for angle: float in SEARCH_ANGLES:
		var direction_local := Vector3(cos(angle), 0.0, sin(angle))
		var start := _floor_at(boundary.to_global(direction_local * START_RADIUS_M))
		var edge := _floor_at(boundary.to_global(direction_local * (Mist.PASS_OUT_M + 0.6)))
		if start.is_empty() or edge.is_empty():
			continue
		var clear := true
		for height: float in [0.4, 1.2]:
			var from: Vector3 = start.position + Vector3.UP * height
			var to: Vector3 = boundary.to_global(direction_local * (float(limit.get_meta("radius_m")) - 0.3)) + Vector3.UP * (start.position.y - boundary.global_position.y + height)
			var query := PhysicsRayQueryParameters3D.create(from, to, STANDING_MASK, [player.get_rid()])
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				clear = false
		if not clear:
			continue
		var direction_world: Vector3 = (boundary.global_transform.basis * direction_local)
		direction_world.y = 0.0
		return {"angle": angle, "start": start.position, "edge": edge.position, "direction": direction_world.normalized()}
	return {}


func _floor_at(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 40.0, point - Vector3.UP * 60.0, STANDING_MASK, [player.get_rid()])
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.85:
		return {}
	return hit


func _place(position: Vector3) -> void:
	player.global_position = position + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	for i in 4:
		await get_tree().physics_frame


func _shot_named(identity: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))


func _shot_bed() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("woke_in_4b.png"))


func _hash(path: String) -> String:
	var text := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	return text.sha256_text()


func _write_receipt() -> void:
	var out := OS.get_environment("RECEIPT_DIR")
	if out.is_empty():
		out = OS.get_environment("SHOT_DIR")
	if out.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(out)
	var root := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	var head: Array = []
	OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head)
	var source: String = get_script().resource_path
	var status := "PASS" if failures.is_empty() else "FAIL"
	var receipt := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "City edge mist and bed return in the production V2 world: one explicit standing placement at 185 m on a floored radial lane, normal forward input to the 200 m pass-out, the production clock through fade, bedside return and fade-in, walking after waking, and a second edge placement held by another owner's lock. No continuous route from the Orison door, save reconstruction, frame timing or artistic claim.",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started_ms) / 1000.0},
		"source": {"test_path": "game/" + source.trim_prefix("res://"), "test_sha256": _hash(source),
			"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256": {
				"game/scripts/building/orison_v2_city_edge_mist.gd": _hash("res://scripts/building/orison_v2_city_edge_mist.gd"),
				"game/scripts/building/orison_v2_street_boundaries.gd": _hash("res://scripts/building/orison_v2_street_boundaries.gd"),
				"game/shaders/city_edge_mist.gdshader": _hash("res://shaders/city_edge_mist.gdshader")},
			"test_dependencies": {"game/tests/orison_v2_vertical_route_test.gd": _hash("res://tests/orison_v2_vertical_route_test.gd")}},
		"contracts": {"production_composition": {"executed": true, "status": status, "identities": ["StreetBoundaries", "CityEdgeMist", "TemporaryExteriorLimit"]},
			"normal_input_pass_out": {"executed": true, "status": status},
			"bedside_return": {"executed": true, "status": status, "anchor": "F04_B_BED"},
			"held_player_respected": {"executed": true, "status": status}},
		"samples": leg_samples, "checks": checks, "failures": failures}
	FileAccess.open(out.path_join("runtime_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
	print("%s: %s; %d checks; %d failures" % [route_label, status, checks.size(), failures.size()])
