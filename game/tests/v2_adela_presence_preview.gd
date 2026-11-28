extends "res://tests/v2_performance_matrix.gd"
## Preview only (INERT). Walks the player's eye toward Adela's Harukiya body
## and away again, capturing the comic world sharpening into the real one
## around her and bleeding back. Lamp-only shadows throughout. If her body is
## not on stage at the frozen test time, the preview shows it for the shots and
## says so in the record (a staging aid for the pictures, not game behaviour).
##
##   SHOT_DIR   where adela_presence.json and the PNGs are written

const Look := preload("res://scripts/rendering/adela_presence_look.gd")
const DISTANCES := [12.0, 8.0, 5.0, 3.0, 5.0, 8.0, 12.0]
const CastModel := preload("res://scripts/characters/cast_model_presentation.gd")

var _done := false
var _record := {}


func _measure(station: Dictionary) -> Dictionary:
	if _done:
		return {"name": str(station.name), "valid": true, "skipped": true}
	_done = true
	var look := Look.new()
	add_child(look)
	look.attach(player.camera, [player.get_rid()])
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
	_silence_shadows()
	# The clearest straight run of floor away from her, at chest height.
	var origin := body.global_position + Vector3.UP * 1.2
	var space := player.get_world_3d().direct_space_state
	var best := Vector3.FORWARD
	var best_reach := 0.0
	for i in 16:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 14.0)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		var reach := 14.0 if hit.is_empty() else origin.distance_to(hit.position)
		if reach > best_reach:
			best_reach = reach
			best = direction
	_record["clear_reach_m"] = snappedf(best_reach, 0.01)
	var frames: Array = []
	for step in DISTANCES.size():
		var distance: float = minf(DISTANCES[step], best_reach - 0.6)
		var at := body.global_position + best * distance
		player.velocity = Vector3.ZERO
		player.global_position = at
		player.look_at_from_position(at, Vector3(body.global_position.x, at.y, body.global_position.z), Vector3.UP)
		player.rotation.x = 0.0
		player.rotation.z = 0.0
		player.camera.rotation.x = -0.08
		# Hold long enough for the bleed to finish, then take the shot.
		for i in 120:
			await get_tree().process_frame
			player.global_position = at
			player.velocity = Vector3.ZERO
		await RenderingServer.frame_post_draw
		var label := "presence_%d_%02dm" % [step, int(distance)]
		var directory := OS.get_environment("SHOT_DIR")
		DirAccess.make_dir_recursive_absolute(directory)
		var image := get_viewport().get_texture().get_image()
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		image.save_png(directory.path_join(label + ".png"))
		frames.append({"shot": label, "distance_m": snappedf(distance, 0.01), "presence": snappedf(look.presence, 0.001),
			"target": snappedf(look.target_presence, 0.001)})
		print("[ADELA] %s presence %.3f (target %.3f)" % [label, look.presence, look.target_presence])
	_record["frames"] = frames
	if staged:
		body.call("set_active", false)
	return {"name": str(station.name), "valid": true}


var _silenced: Array[Light3D] = []


func _silence_shadows() -> void:
	process_priority = 1 << 30
	for node: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light != player.flashlight and not player.is_ancestor_of(light):
			_silenced.append(light)


func _process(delta: float) -> void:
	super._process(delta)
	for light: Light3D in _silenced:
		if is_instance_valid(light) and light.shadow_enabled:
			light.shadow_enabled = false


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	_record.merge({"schema": "orison.v2-adela-presence-preview.v1", "evidence_class": "INERT", "failures": failures})
	var file := FileAccess.open(directory.path_join("adela_presence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_record, "\t"))
	file.close()
