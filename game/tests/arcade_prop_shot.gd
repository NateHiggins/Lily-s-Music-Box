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
	# Booted by the prop's own distance gate, not by hand. The camera stands 1.5 m
	# away, well inside the live radius, so the shipping path is the photographed
	# path. Reaching past the prop to machine.boot() is how this shot spent months
	# showing the raw board while the cabinet in the game showed the same thing
	# for a different reason - the prop binds the screen material before boot(),
	# so scope_texture() had no phosphor to return and the trail went nowhere.
	await get_tree().create_timer(0.6).timeout
	if prop.machine == null or not prop.machine.is_booted():
		print("[PROP] the distance gate did not boot the machine")
		get_tree().quit(1)
		return

	# A trail is hard to see in a still and easy to lose in a refactor, so assert
	# the wiring instead of squinting at the photograph: what the glass samples
	# has to be the phosphor viewport, not the board behind it. These are two
	# different ViewportTextures and the difference is the whole effect.
	var feed: Variant = prop._screen_mat.get_shader_parameter("feed")
	if prop.machine._phosphor == null:
		print("[PROP] FAIL the machine booted without a phosphor viewport")
		get_tree().quit(1)
		return
	if feed != prop.machine._phosphor.get_texture():
		print("[PROP] FAIL the glass is sampling the raw board; "
				+ "the phosphor trail is being rendered and thrown away")
		get_tree().quit(1)
		return
	print("[PROP] feed is the phosphor viewport, trail included")
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw

	var directory := OS.get_environment("SHOT_DIR")
	if directory == "":
		directory = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(directory + "/arcade_prop.png")
	print("[PROP] saved ", directory, "/arcade_prop.png")
	get_tree().quit(0)
