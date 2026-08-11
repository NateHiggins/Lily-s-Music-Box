extends Node3D
## The phonautograph on its own, from three sides.
##     SHOT_DIR=<abs> godot --path game res://tests/PhonautographShot.tscn

func _ready() -> void:
	var env := WorldEnvironment.new()
	var s := Environment.new()
	s.background_mode = Environment.BG_COLOR
	s.background_color = Color(0.14, 0.135, 0.14)
	s.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	s.ambient_light_color = Color(0.56, 0.54, 0.52)
	s.ambient_light_energy = 1.5
	env.environment = s
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 32, 0)
	key.light_energy = 2.0
	add_child(key)
	for i in 3:
		var p := SongbookTerminalProp.new()
		p.position = Vector3(float(i) * 1.35 - 1.35, 0, 0)
		p.rotation_degrees.y = [210.0, 270.0, 330.0][i]
		add_child(p)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0.0, 0.78, 2.6)
	cam.look_at(Vector3(0.0, 0.28, 0.0))
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			OS.get_environment("SHOT_DIR") + "/phonautograph.png")
	print("[PHON] saved")
	get_tree().quit(0)
