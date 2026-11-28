extends "res://tests/v2_performance_matrix.gd"
## Evidence class: INERT capture (Lily 2026-11-28, Adela's aura). In the
## comic world, the player's eye walks toward Adela's Harukiya body at a
## walking pace, stops at conversation distance with her centred, holds, and
## walks away again. Shots every half second show the aura forming and the
## bleed. If her body is not on stage at the test's frozen time, the capture
## shows it for the pictures and says so in the record (a staging aid for the
## shots, not game behaviour); nothing here moves or poses her.
##
##   SHOT_DIR   where adela_aura.json and the PNGs are written

const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")
const Presentation := preload("res://scripts/visuals/cel_style_presentation.gd")
const FAR_START_M := 10.0
const TALK_M := 1.6
const WALK_MPS := 1.4
const HOLD_S := 3.0
const SHOT_EVERY_S := 0.5

var _done := false
var _record := {}


func _measure(station: Dictionary) -> Dictionary:
	if _done:
		return {"name": str(station.name), "valid": true, "skipped": true}
	_done = true
	OS.set_environment("ORISON_WORLD_LOOK", "comic")
	var body: Node3D = null
	for node: Node in get_tree().root.find_children("*adela_voss*", "Node3D", true, false):
		if node is CastModel:
			body = node as Node3D
			break
	if body == null:
		failures.append("Adela's cast body was not found")
		return {"name": str(station.name), "valid": false}
	var staged: bool = not body.is_visible_in_tree()
	if staged:
		body.call("set_active", true)
	_record = {"staged_for_preview": staged, "body": str(body.get_path())}
	var focus := body.global_position + Vector3.UP * 1.35
	# The clearest straight run of floor away from her, at chest height.
	var origin := body.global_position + Vector3.UP * 1.2
	var space := player.get_world_3d().direct_space_state
	var best := Vector3.FORWARD
	var best_reach := 0.0
	for i in 24:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 24.0)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 14.0)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		var reach := 14.0 if hit.is_empty() else origin.distance_to(hit.position)
		if reach > best_reach:
			best_reach = reach
			best = direction
	_record["clear_reach_m"] = snappedf(best_reach, 0.01)
	var far := minf(FAR_START_M, best_reach - 0.6)
	var walk_s := (far - TALK_M) / WALK_MPS
	# Out, in, hold, out again: [seconds, from metres, to metres].
	# Then the bleed itself: from out of range straight to conversation
	# distance, shot every quarter second while the aura melts in.
	var legs := [["approach", walk_s, far, TALK_M], ["hold", HOLD_S, TALK_M, TALK_M], ["leave", walk_s, TALK_M, far],
		["away", 2.0, far, far], ["arrive", 2.5, TALK_M, TALK_M]]
	# Let the venue stream in and the look settle before the first shot.
	_stand(body, best, far, focus)
	for i in 180:
		await get_tree().process_frame
		_stand(body, best, far, focus)
	var presentation := _presentation()
	var frames: Array = []
	var shot := 0
	for leg: Array in legs:
		var elapsed := 0.0
		var next_shot := 0.0
		while elapsed <= float(leg[1]) + 0.0001:
			var distance := lerpf(float(leg[2]), float(leg[3]), clampf(elapsed / maxf(float(leg[1]), 0.001), 0.0, 1.0))
			_stand(body, best, distance, focus)
			await get_tree().process_frame
			var delta := get_process_delta_time()
			if elapsed >= next_shot:
				await RenderingServer.frame_post_draw
				var label := "aura_%02d_%s_%04.1fm_%03ds" % [shot, leg[0], distance, int(elapsed * 100.0)]
				_save(label)
				var presence: Node = presentation.presence if presentation != null else null
				var aura: Dictionary = presence.aura() if presence != null else {}
				frames.append({"shot": label, "leg": leg[0], "seconds": snappedf(elapsed, 0.01),
					"distance_m": snappedf(distance, 0.01),
					"presence": snappedf(float(presence.presence), 0.001) if presence != null else -1.0,
					"target": snappedf(float(presence.target_presence), 0.001) if presence != null else -1.0,
					"aura_radius": snappedf(float(aura.get("radius", 0.0)), 0.001),
					"aura_feather": snappedf(float(aura.get("feather", 0.0)), 0.001),
					"aura_center": [snappedf(aura.get("center", Vector2.ZERO).x, 0.001), snappedf(aura.get("center", Vector2.ZERO).y, 0.001)],
					"frame_ms": snappedf(delta * 1000.0, 0.01)})
				print("[AURA] %s presence %.3f target %.3f radius %.3f" % [label, frames[-1].presence, frames[-1].target, frames[-1].aura_radius])
				shot += 1
				next_shot += 0.25 if leg[0] == "arrive" else SHOT_EVERY_S
			elapsed += delta
	_record["frames"] = frames
	_record["look"] = presentation.look() if presentation != null else "missing"
	if presentation == null or presentation.look() != "comic":
		failures.append("the comic look was not drawn")
	var peak := 0.0
	for row: Dictionary in frames:
		peak = maxf(peak, float(row.presence))
	if peak < 0.95:
		failures.append("presence never reached full at conversation distance (peak %.3f)" % peak)
	if staged:
		body.call("set_active", false)
	return {"name": str(station.name), "valid": true}


func _stand(body: Node3D, away: Vector3, distance: float, focus: Vector3) -> void:
	var at := body.global_position + away * distance
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.look_at_from_position(at, Vector3(body.global_position.x, at.y, body.global_position.z), Vector3.UP)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	var eye := player.camera.global_position
	var flat := Vector2(focus.x - eye.x, focus.z - eye.z).length()
	player.camera.rotation.x = atan2(focus.y - eye.y, maxf(flat, 0.01))


func _presentation() -> Presentation:
	for node: Node in player.find_children("*", "Node", true, false):
		if node.get_script() == Presentation:
			return node as Presentation
	return null


func _save(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var image := get_viewport().get_texture().get_image()
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	image.save_png(directory.path_join(label + ".png"))


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	_record.merge({"schema": "orison.v2-adela-aura-walk.v1", "evidence_class": "INERT", "failures": failures})
	var file := FileAccess.open(directory.path_join("adela_aura.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_record, "\t"))
	file.close()
