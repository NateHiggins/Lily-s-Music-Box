extends Node3D
## One cabinet prop, one camera, no building.
##
##     SHOT_DIR=... godot --path game res://tests/ArcadePropShot.tscn
##
## The building is a dark room with heavy post-processing on it, which is a bad
## place to work out why a screen is not showing a picture. This is the prop on
## its own against a neutral background, so anything wrong in the frame is the
## prop's.

func _ready() -> void:
	var catalog := ArcadeCatalog.load_catalog()
	if catalog == null or catalog.size() == 0:
		print("[PROP] no catalog")
		get_tree().quit(1)
		return

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.16, 0.17, 0.19)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.5, 0.52, 0.56)
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	add_child(environment)

	var prop := ArcadeCabinetProp.new()
	prop.configure(catalog.spread()[0], 0)
	add_child(prop)

	var camera := Camera3D.new()
	camera.fov = 60
	add_child(camera)
	camera.make_current()
	# Straight in front of the cabinet, at the screen's height. The prop treats
	# local -Z as the face of the machine, so the camera stands there.
	camera.position = Vector3(0.0, 1.29, -1.5)
	camera.look_at(Vector3(0.0, 1.29, 0.0))

	_run(prop, camera)


func _run(prop: ArcadeCabinetProp, _camera: Camera3D) -> void:
	await get_tree().create_timer(0.4).timeout
	if prop.machine != null and not prop.machine.is_booted():
		prop.machine.boot(prop.cabinet, ArcadeCatalog.DIR)
	if prop.machine != null:
		prop.machine.set_live(true)
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw

	var directory := OS.get_environment("SHOT_DIR")
	if directory == "":
		directory = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(directory + "/arcade_prop.png")
	print("[PROP] saved ", directory, "/arcade_prop.png")
	get_tree().quit(0)
