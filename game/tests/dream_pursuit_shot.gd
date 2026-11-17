extends Node
## Finite V2 diagnostic frames: the real DreamMazeRoot, the real service lamp,
## and the Tenant present only as Mina's borrowed shadow on module
## architecture. No frame may contain a beauty-pass body. These captures are
## not pursuit gameplay qualification or artistic acceptance.

const SEED_HEX := "f123456789abcdef"

var _root: DreamMazeRoot
var _caption: Label
var _output_dir := ""
var _failures: Array[String] = []
var _images: Array[Dictionary] = []
var _staging: Dictionary = {}
var _logger = preload("res://tests/guide_bell_error_capture.gd").new()
var _preview := false
var _prior_mouse: int
var _prior_mode: GameBoot.LaunchMode
var _prior_data: Dictionary
var _prior_text := ""


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	OS.add_logger(_logger)
	_prior_mouse = Input.mouse_mode
	_prior_mode = GameBoot.launch_mode
	_prior_data = RealityState.data
	_prior_text = JSON.stringify(_prior_data, "", true, true)
	_output_dir = OS.get_environment("SHOT_DIR")
	if _output_dir.is_empty() or not _output_dir.is_absolute_path():
		_failures.append("SHOT_DIR must name an absolute fresh directory")
		_output_dir = ""
	elif DirAccess.dir_exists_absolute(_output_dir) and (not DirAccess.get_files_at(_output_dir).is_empty() or not DirAccess.get_directories_at(_output_dir).is_empty()):
		_failures.append("SHOT_DIR is not empty; preserving existing evidence")
		_output_dir = ""
	elif DirAccess.make_dir_recursive_absolute(_output_dir) != OK:
		_failures.append("cannot create SHOT_DIR")
		_output_dir = ""
	if not _output_dir.is_empty():
		_preview = RealityState.begin_preview_campaign(self)
		if not _preview:
			_failures.append("cannot acquire nonpersistent preview campaign")
		elif await _build_world():
			if await _capture("01_lamp_on_borrowed_shadow", true, "V2 // LAMP ON // MINA'S BORROWED SHADOW ONLY"):
				await _capture("02_lamp_off_black_level", false, "V2 // LAMP OFF // PRODUCTION BLACK LEVEL")
	await _finish()


## THE SCENE NOW BRINGS ITS OWN LIGHT, so this harness stopped bringing any.
##
## Until 2026-08-17 this function built a WorldEnvironment and two OmniLight3Ds
## before photographing anything, because production had none of the three:
## `CampaignShell` frees the waking world that owns the waking environment, and
## `DreamMazeRoot` built no replacement. The controls were honestly named —
## `RecedingOrientationControl`, `NearestFloorBlackLevelControl` — but the
## consequence was that N6's proof frames demonstrated navigable darkness in a
## scene no player could enter, and the real one was pure black
## (`art/renders/dream_env_n7/before/`).
##
## `DreamMazeRoot` now owns a WorldEnvironment, a carried black level and the
## ruled receding practical. Keeping the controls here would double every one
## of them and leave these frames just as unlike production as before, in the
## other direction.
func _build_world() -> bool:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	_root = scene.instantiate() as DreamMazeRoot
	_root.autonomous = false
	_root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print", "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
	})
	add_child(_root)
	for frame in 3:
		await get_tree().physics_frame
	if not _root.maze_built or _root.player == null or _root.pursuer == null or _root.rooms == null:
		_failures.append("production V2 dream did not build")
		return false
	_root.player.set_physics_process(false)
	if _root.pursuer.silhouette_source != "mina_vale":
		_failures.append("Tenant did not borrow Mina's silhouette")
		return false
	var geometry := _root.pursuer.find_children("*", "GeometryInstance3D", true, false)
	if geometry.is_empty():
		_failures.append("borrowed silhouette has no geometry")
		return false
	for draw: GeometryInstance3D in geometry:
		if draw.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			_failures.append("Tenant has beauty-pass geometry: " + str(draw.get_path()))
			return false
	if not _stage_at_native_wall():
		_failures.append("no built V2 room has a clear supported wall staging interval")
		return false

	# No orientation controls. The scene owns its black level and its receding
	# practical now; see the note on _build_world.

	_root.player.camera.make_current()

	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	_caption = Label.new()
	_caption.position = Vector2(24, 22)
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color("d9c996"))
	canvas.add_child(_caption)
	return true


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(_root.to_global(a), _root.to_global(b), 1)
	query.exclude = [_root.player.get_rid(), _root.pursuer.get_rid()]
	return _root.get_world_3d().direct_space_state.intersect_ray(query)


func _stage_at_native_wall() -> bool:
	# Derive staging from current built rooms and confirm their native walls,
	# floor support and clear lamp path. No V1 ids or invented geometry.
	for key: String in _root.rooms._live:
		var room: Dictionary = _root.rooms._live[key]
		var node := _root.rooms._nodes.get(key) as Node3D
		if node == null:
			continue
		var rect: Array = room.rect
		for side in 4:
			for fraction: float in [0.5, 0.25, 0.75]:
				var boundary := Vector3.ZERO
				var inward := Vector3.ZERO
				if side < 2:
					boundary = Vector3(float(rect[0]) if side == 0 else float(rect[2]), 1.4, lerpf(rect[1], rect[3], fraction))
					inward = Vector3.RIGHT if side == 0 else Vector3.LEFT
				else:
					boundary = Vector3(lerpf(rect[0], rect[2], fraction), 1.4, float(rect[1]) if side == 2 else float(rect[3]))
					inward = Vector3.BACK if side == 2 else Vector3.FORWARD
				var player_at := boundary + inward * 2.6
				if player_at.x <= float(rect[0]) + 0.3 or player_at.x >= float(rect[2]) - 0.3 or player_at.z <= float(rect[1]) + 0.3 or player_at.z >= float(rect[3]) - 0.3:
					continue
				var hit := _ray(player_at, boundary - inward * 0.5)
				if hit.is_empty() or not node.is_ancestor_of(hit.collider) or not str(hit.collider.name).begins_with("Wall"):
					continue
				var normal: Vector3 = hit.normal
				if normal.dot(_root.global_basis * inward) < 0.99:
					continue
				var wall: Vector3 = _root.to_local(hit.position)
				player_at = wall + inward * 2.6
				var tenant_at := wall + inward * 1.2
				var supported := true
				for at: Vector3 in [player_at, tenant_at]:
					var floor_hit := _ray(at, at - Vector3.UP * 1.6)
					if floor_hit.is_empty() or absf(_root.to_local(floor_hit.position).y) > 0.02:
						supported = false
				if not supported:
					continue
				player_at.y = 0.0
				tenant_at.y = 0.0
				_root.player.position = player_at
				_root.player.rotation = Vector3(0.0, atan2(inward.x, inward.z), 0.0)
				_root.pursuer.reset_run(tenant_at)
				_staging = {"room_key": key, "source": room.source, "rect": rect,
					"wall": str(hit.collider.get_path()), "wall_hit": [wall.x, wall.y, wall.z],
					"player": [player_at.x, player_at.y, player_at.z], "tenant": [tenant_at.x, tenant_at.y, tenant_at.z],
					"silhouette_source": _root.pursuer.silhouette_source}
				return true
	return false


func _capture(file_name: String, lamp_on: bool, caption: String) -> bool:
	_root.player.set_lamp_enabled(lamp_on)
	_caption.text = caption
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _output_dir.path_join(file_name + ".png")
	if image == null or image.is_empty():
		_failures.append("viewport has no rendered image")
		return false
	var error := image.save_png(path)
	if error != OK:
		_failures.append("could not write frame " + path)
		return false
	_images.append({"file": file_name + ".png", "sha256": FileAccess.get_sha256(path),
		"width": image.get_width(), "height": image.get_height(), "lamp_on": lamp_on})
	print("[DREAM PURSUIT N6 SHOT] saved %s" % path)
	return true


func _finish() -> void:
	if is_instance_valid(_root):
		_root.free()
	if _preview:
		if not RealityState.end_preview_campaign(self) or not is_same(RealityState.data, _prior_data) or JSON.stringify(_prior_data, "", true, true) != _prior_text:
			_failures.append("prior campaign object/content was not restored")
	GameBoot.launch_mode = _prior_mode
	Input.mouse_mode = _prior_mouse
	for frame in 3:
		await get_tree().process_frame
	var errors: Array = _logger.errors.duplicate()
	if not errors.is_empty():
		_failures.append("engine errors during capture or teardown")
	OS.remove_logger(_logger)
	var ok := _failures.is_empty() and _images.size() == 2
	if not _output_dir.is_empty():
		var file := FileAccess.open(_output_dir.path_join("diagnostic.json"), FileAccess.WRITE)
		if file == null:
			_failures.append("could not write diagnostic.json")
			ok = false
		else:
			file.store_string(JSON.stringify({"evidence_class": "INERT", "status": "PASS" if ok else "FAIL",
				"seed_hex": SEED_HEX, "staging": _staging, "images": _images, "failures": _failures,
				"engine_errors": errors, "human_played": false, "artistically_accepted": false,
				"scope": "Finite V2 production lamp/shadow capture; not pursuit gameplay qualification."}, "\t"))
	print("[DREAM PURSUIT SHOT] RESULT: ", "PASS" if ok else "FAIL", " ", _failures)
	get_tree().quit(0 if ok else 1)
