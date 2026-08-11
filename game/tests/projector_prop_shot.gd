extends Node3D
## The machine on its own, lit, from three sides.
##
##     SHOT_DIR=<abs> godot --path game res://tests/ProjectorPropShot.tscn

const ANGLES := [220.0, 300.0, 20.0]


func _ready() -> void:
	var env := WorldEnvironment.new()
	var s := Environment.new()
	s.background_mode = Environment.BG_COLOR
	s.background_color = Color(0.16, 0.16, 0.175)
	s.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	s.ambient_light_color = Color(0.52, 0.53, 0.56)
	s.ambient_light_energy = 1.5
	env.environment = s
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 38, 0)
	key.light_energy = 2.2
	add_child(key)

	for i in ANGLES.size():
		var p := ProjectorProp.new()
		p.setup(null, "SHOT%d" % i, ShaderMaterial.new())
		p.position = Vector3(float(i) * 1.0 - 1.0, 0, 0)
		p.rotation_degrees.y = float(ANGLES[i])
		add_child(p)

	var cam := Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0.0, 0.62, 2.15)
	cam.look_at(Vector3(0.0, 0.25, 0.0))
	_run()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			OS.get_environment("SHOT_DIR") + "/projector_prop.png")
	print("[PROP] saved")
	get_tree().quit(0)
