extends Node
## Facial capability audit (order w8c788aec4db6): every rebuilt body, framed
## close at the head, with each shape group written directly (not through the
## controller, so blink timing and easing cannot hide a broken shape). Saves one
## PNG per body and beat to SHOT_DIR. Windowed only; headless writes nothing.
## Review evidence, not runtime proof.

const DATA := "res://data/characters/face_performance.json"
const CAST := "res://assets/characters/cast"
const EXTRA: Array[String] = ["res://assets/characters/lily/lily.gltf", "res://assets/characters/stacy/stacy.gltf"]

var _data: Dictionary = {}


func _bodies() -> Array[String]:
	var only := OS.get_environment("FACE_ONLY")
	var paths: Array[String] = []
	for id: String in DirAccess.get_directories_at(CAST):
		var path := "%s/%s/%s.gltf" % [CAST, id, id]
		if ResourceLoader.exists(path):
			paths.append(path)
	paths.append_array(EXTRA)
	if not only.is_empty():
		paths = paths.filter(func(p: String) -> bool: return p.get_file().get_basename() in only.split(","))
	return paths


func _beats() -> Array:
	var eyes: Dictionary = _data.eyes
	var beats: Array = [
		["rest", {}],
		["blink", {"eyeBlinkLeft": 1.0, "eyeBlinkRight": 1.0}],
		["lips_PP", {"viseme_PP": 1.0}],
		["jaw_aa", {"viseme_aa": 1.0}],
		["round_O", {"viseme_O": 1.0}],
		["teeth_FF", {"viseme_FF": 1.0}],
		["look_left", {eyes.left_out: 1.0, eyes.right_in: 1.0}],
		["look_right", {eyes.left_in: 1.0, eyes.right_out: 1.0}],
		["look_up", {eyes.up[0]: 1.0, eyes.up[1]: 1.0}],
		["look_down", {eyes.down[0]: 1.0, eyes.down[1]: 1.0}],
	]
	for row: Dictionary in _data.expressions:
		if str(row.name) == "neutral":
			continue
		var shapes: Dictionary = {}
		for pair: Array in row.shapes:
			shapes[str(pair[0])] = float(pair[1])
		beats.append([str(row.name), shapes])
	return beats


func _write(model: Node, shapes: Dictionary) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for index in mesh.get_blend_shape_count():
			var shape := str(mesh.mesh.get_blend_shape_name(index))
			mesh.set_blend_shape_value(index, float(shapes.get(shape, 0.0)))


func _ready() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		print("NPC FACE AUDIT: needs a window and SHOT_DIR; nothing written")
		get_tree().quit(0)
		return
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	DirAccess.make_dir_recursive_absolute(directory)
	get_window().size = Vector2i(640, 640)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.3, 0.31, 0.33)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.8, 0.82)
	environment.environment.ambient_light_energy = 0.55
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-20, 30, 0)
	key.light_energy = 1.1
	add_child(key)
	var camera := Camera3D.new()
	camera.fov = 20
	add_child(camera)
	camera.current = true
	var failures := 0
	var shots := 0
	for path: String in _bodies():
		var packed := load(path) as PackedScene
		if packed == null:
			print("NPC FACE AUDIT: cannot load ", path)
			failures += 1
			continue
		var model := packed.instantiate() as Node3D
		add_child(model)
		for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
			player.stop()
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		var head_bone := (skeletons[0] as Skeleton3D).find_bone("Head") if not skeletons.is_empty() else -1
		if head_bone < 0:
			print("NPC FACE AUDIT: no Head bone in ", path)
			failures += 1
			model.queue_free()
			continue
		var skeleton := skeletons[0] as Skeleton3D
		var head := skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin
		var aim := head + Vector3(0, 0.085, 0)
		camera.position = aim + Vector3(0, 0.01, 0.78)
		camera.look_at(aim)
		var stem := path.get_file().get_basename()
		var counted := 0
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh != null:
				counted += mesh.get_blend_shape_count()
		print("NPC FACE AUDIT BODY: %s head=%s shape_slots=%d" % [stem, str(head), counted])
		for beat: Array in _beats():
			_write(model, beat[1])
			for index in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("%s__%s.png" % [stem, beat[0]]))
			shots += 1
		model.queue_free()
		await get_tree().process_frame
	print("NPC FACE AUDIT: %d shots; %d failures" % [shots, failures])
	get_tree().quit(1 if failures > 0 else 0)
