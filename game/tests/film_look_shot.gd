extends Node3D
## What the projector puts on the wall.
##
##     SHOT_DIR=<abs> godot --path game res://tests/FilmLookShot.tscn
##
## Throws one frame onto a piece of plaster at four burn values so the effect
## can be judged as a sequence rather than as a still. The wall is a real
## material lit by a real light, because the whole point of blend_add is that
## the image cannot be darker than what it lands on.

## FOUR MOMENTS OF THE SAME CLIP, with ONE burn nailed to the spot the
## watermark occupies in the first of them. This is the test the owner asked
## for and it is the only honest way to answer the question: a burn is damage
## to a piece of film, so it cannot move, and the mark does.
const FRAMES := ["_wm_12", "_plate_ch_01", "_plate_ch_24", "_plate_ch_06"]
const BURNS := [0.0, 0.0, 0.0, 0.0]
const CUES := [0.0, 0.0, 0.0, 0.0]
## Panel 1 is a single frame with no treatment. 2-4 are 40-frame accumulations
## - the long exposure - carrying the plate pass.
const PLATES := [0.0, 1.0, 1.0, 1.0]
## Measured off frame 12: the Sora mark sits upper-left, and this is sized to
## swallow it whole.
const PATCH_AT := Vector2(0.175, 0.075)
const PATCH_R := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.02, 0.02, 0.025)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.16, 0.15, 0.15)
	settings.ambient_light_energy = 0.8
	env.environment = settings
	add_child(env)

	for i in FRAMES.size():
		var x := (float(i) - 1.5) * 1.28
		_wall(x)
		var tex: Texture2D = load("res://assets/video/clips/%s.png" % FRAMES[i])
		_image(x, tex, float(BURNS[i]), float(CUES[i]), i == 0, float(PLATES[i]))

	var cam := Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0.0, 0.0, 4.35)
	cam.look_at(Vector3(0.0, 0.0, 0.0))
	_run()


## Plaster, so the projection has something to be dimmer than.
func _wall(x: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.22, 1.72)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.69, 0.63)
	mat.roughness = 0.95
	m.material_override = mat
	m.position = Vector3(x, 0.0, -0.004)
	add_child(m)


func _image(x: float, tex: Texture2D, burn: float, cue: float, raw: bool, plate: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.10, 1.56)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/projected_film.gdshader")
	mat.set_shader_parameter("frame", tex)
	mat.set_shader_parameter("burn", burn)
	mat.set_shader_parameter("mono", 0.0 if burn == 0.0 else 1.0)
	# Panel one is the plate: everything off, so the difference the pass makes
	# is visible rather than asserted.
	if raw:
		mat.set_shader_parameter("grain_amount", 0.0)
		mat.set_shader_parameter("dust_amount", 0.0)
		mat.set_shader_parameter("flicker_depth", 0.0)
		mat.set_shader_parameter("falloff", 0.0)
		mat.set_shader_parameter("mono", 0.0)
		mat.set_shader_parameter("gain", 1.0)
	# A cue is fired continuously here only so it can be photographed; in the
	# game it is four frames and gone.
	mat.set_shader_parameter("cue_period", 1000.0 if cue > 0.0 else 0.0)
	mat.set_shader_parameter("plate", plate)
	if plate > 0.0:
		mat.set_shader_parameter("gain", 1.02)
		mat.set_shader_parameter("falloff", 1.05)
		mat.set_shader_parameter("lamp_tint", Color(1.0, 0.97, 0.90))
	mat.set_shader_parameter("mono", 1.0 if plate > 0.0 else 0.0)
	mat.set_shader_parameter("grain_amount", 0.18 if plate > 0.0 else 0.32)
	mat.set_shader_parameter("dust_amount", 0.12 if plate > 0.0 else 0.30)
	mat.set_shader_parameter("cigar_size", PATCH_R)
	mat.set_shader_parameter("cigar_at", PATCH_AT)
	m.material_override = mat
	m.position = Vector3(x, 0.0, 0.0)
	add_child(m)


func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("SHOT_DIR")
	get_viewport().get_texture().get_image().save_png(dir + "/film_look.png")
	print("[FILM] saved %s/film_look.png" % dir)
	get_tree().quit(0)
