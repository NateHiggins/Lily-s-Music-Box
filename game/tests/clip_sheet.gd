extends Node3D
## Clip contact sheet (not shipped). Renders every animation on a rigged
## character at three phases per clip so the UUID-named Meshy clips can be
## identified and classified by eye — the ROLES map in resident_routines is
## re-pointed from what these frames show.
##   SHOT_DIR=<abs>   output directory
##   CLIP_MODEL=res://assets/characters/evelyn_marsh/evelyn_marsh.gltf

const PHASES := [0.05, 0.4, 0.75]  # fractions of each clip's length

var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	var model := OS.get_environment("CLIP_MODEL")
	if model == "":
		model = "res://assets/characters/evelyn_marsh/evelyn_marsh.gltf"
	_run(model)


func _run(model: String) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.13, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 1.1
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 28, 0)
	key.light_energy = 1.4
	add_child(key)
	var figure := (load(model) as PackedScene).instantiate()
	add_child(figure)
	var anim := _find_player(figure)
	if anim == null:
		push_error("no AnimationPlayer in %s" % model)
		get_tree().quit(1)
		return
	# Three-quarter view, framing a standing adult head to foot.
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.global_position = Vector3(1.6, 1.35, 2.4)
	cam.look_at(Vector3(0.0, 0.95, 0.0))
	cam.make_current()
	await get_tree().process_frame
	for clip_name in anim.get_animation_list():
		var clip := anim.get_animation(clip_name)
		for i in PHASES.size():
			anim.play(clip_name)
			anim.seek(clip.length * float(PHASES[i]), true)
			anim.pause()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var safe := str(clip_name).replace("/", "_")
			img.save_png("%s/clip_%s_p%d.png" % [_dir, safe, i])
			print("saved clip_%s_p%d.png" % [safe, i])
	get_tree().quit(0)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null
