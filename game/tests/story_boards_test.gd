extends Node3D
## The residents' story boards in the running V2 world: eighteen, each in its own resident's main room, flat
## against a wall, clear of anything else, every line on the paper and as authored. With PROBE=1 it also
## reports, for each board that fails, which nearby offsets along its wall would be clear.
const Boards := preload("res://scripts/building/orison_v2_story_boards.gd")
const CANDIDATES := [0.55, -0.55, 0.75, -0.75, 0.40, -0.40, 0.95, -0.95, 1.2, -1.2]

var checks := 0
var failures: Array[String] = []
var _world: Node3D


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("STORY BOARDS: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 600)
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	for frame in 30:
		await get_tree().physics_frame
	var blockout: Node3D = _world.get("_blockout")
	var node: Node = blockout.get_node_or_null(Boards.HOLDER) if blockout != null else null
	check(node != null, "the running world pins the story boards")
	if node == null:
		_finish()
		return
	check(node.errors.is_empty(), "the mount reports no errors: %s" % [node.errors])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Boards.DATA))
	check(data.boards.size() == 18 and node.boards.size() == 18, "eighteen boards, one for each resident (%d)" % node.boards.size())
	var places := Boards.load_places()
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	for board: Dictionary in data.boards:
		var id := str(board.id)
		var pinned: Node3D = node.boards.get(id)
		if pinned == null:
			continue
		var clear := _clear(space, pinned.global_transform, board)
		check(clear.is_empty(), "%s hangs flat on a wall, clear of everything else: %s" % [id, clear])
		var lines: Array = board.lines
		var labels := pinned.find_children("Line*", "Label3D", false, false)
		check(labels.size() == lines.size(), "%s carries its authored lines" % id)
		for index in mini(labels.size(), lines.size()):
			var label := labels[index] as Label3D
			var span: float = label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
			check(label.text == str(lines[index]) and span <= float(board.size[0]) - 0.015, "%s line %d fits on the paper" % [id, index])
		if not clear.is_empty() and OS.get_environment("PROBE") == "1":
			var good: Array = []
			for x: float in CANDIDATES:
				for y: float in [-0.05, -0.2, 0.1]:
					var trial := board.duplicate(true)
					trial.offset = [x, y]
					var pose: Transform3D = blockout.global_transform * Boards.pose_for(trial, places)
					if _clear(space, pose, trial).is_empty():
						good.append([x, y])
			print("STORY BOARD PROBE ", id, " clear offsets ", good)
	var shots := OS.get_environment("SHOT_DIR")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		var camera := Camera3D.new()
		camera.fov = 40.0
		add_child(camera)
		camera.make_current()
		for id: String in node.boards:
			var pinned: Node3D = node.boards[id]
			var eye: Vector3 = pinned.global_transform * Vector3(0.0, 0.0, 0.55)
			camera.look_at_from_position(eye, pinned.global_position)
			for frame in 4: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shots.path_join(id + ".png"))
	_finish()


## Empty when the paper has wall right behind it and nothing in the box in front of it; else why not.
func _clear(space: PhysicsDirectSpaceState3D, pose: Transform3D, board: Dictionary) -> String:
	var w := float(board.size[0])
	var h := float(board.size[1])
	for corner: Vector2 in [Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(-0.45, 0.45), Vector2(0.45, 0.45), Vector2.ZERO]:
		var at := pose * Vector3(corner.x * w, corner.y * h, 0.02)
		var behind := pose * Vector3(corner.x * w, corner.y * h, -0.03)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(at, behind, 1)).is_empty():
			return "no wall behind"
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.02, h + 0.02, 0.04)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = 1
	query.transform = pose * Transform3D(Basis(), Vector3(0.0, 0.0, 0.025))
	var hits := space.intersect_shape(query, 4)
	if not hits.is_empty():
		return "blocked by %s" % [hits[0].collider.name if is_instance_valid(hits[0].collider) else "?"]
	return ""


func _finish() -> void:
	print("STORY BOARDS RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
