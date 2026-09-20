extends Node3D
func _ready() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.1,3.3)
	add_child(camera)
	camera.look_at(Vector3(0,.95,0))
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.15,.16,.18)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .6
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	add_child(light)
	var actor := AnimatedResident.new()
	actor.setup("Mina Vale","mina_vale","2A","res://assets/characters/mina_vale/mina_vale.gltf")
	actor.externally_driven = true
	add_child(actor)
	preload("res://scripts/characters/mina_idle_animation.gd").install(actor)
	var animation := actor._animation_player
	var skeleton := ResidentMovesLibrary._find_skeleton(actor)
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	for pose in ["rest","idle_12","idle_15","idle_6","mina_vale_Walk","mina_calm_idle"]:
		animation.stop()
		skeleton.reset_bone_poses()
		if pose != "rest":
			animation.play(pose)
			animation.seek(.4,true)
			animation.pause()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(pose+".png"))
		print("MINA POSE: ",pose)
	get_tree().quit()
