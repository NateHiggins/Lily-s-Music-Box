extends Node3D
## The five lamps side by side, against nothing.
##
##     SHOT_DIR=... godot --path game --audio-driver Dummy res://tests/LampShot.tscn
##
## The warehouse shows them in the shed with everything else; this is the family
## on its own, which is the comparison the pass was actually about.

const ORDER := ["emeralite", "office_green", "bench_friction",
		"landlord_enamel", "architect_counterweight"]


func _ready() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.13, 0.13, 0.15)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.42, 0.44, 0.48)
	settings.ambient_light_energy = 0.9
	env.environment = settings
	add_child(env)

	for i in ORDER.size():
		# A bench under each one, so the spot has something to land on.
		var top := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.62, 0.04, 0.55)
		top.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.38, 0.31, 0.24)
		mat.roughness = 0.8
		top.material_override = mat
		top.position = Vector3(i * 0.78 - 1.56, -0.02, 0.0)
		add_child(top)

		var lamp := LampProp.new()
		lamp.name = "LAMP_%s" % ORDER[i]
		lamp.variant = ORDER[i]
		lamp.position = Vector3(i * 0.78 - 1.56, 0.0, 0.0)
		add_child(lamp)

	var cam := Camera3D.new()
	cam.fov = 52
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0.0, 0.58, 2.55)
	cam.look_at(Vector3(0.0, 0.34, 0.0))
	_run()


func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir()
	get_viewport().get_texture().get_image().save_png(dir + "/lamp_family.png")
	print("[LAMP] saved ", dir, "/lamp_family.png")
	get_tree().quit(0)
