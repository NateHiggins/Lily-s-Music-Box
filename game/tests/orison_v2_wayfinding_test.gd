extends Node
var failures: Array[String] = []

func _ready() -> void: call_deferred("_run")

func _run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if DisplayServer.get_name()=="headless" or directory.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	if world.startup_failed:
		get_tree().quit(2)
		return
	var player: PlayerController = world.player
	player.set_physics_process(false)
	player.camera.make_current()
	var signs = world.adapter.root.get_node("Wayfinding")
	_check(signs.plaques.size()==16,"both stairs identify all eight levels")
	for sign_node: Node3D in signs.plaques:
		var normal := sign_node.global_basis.z
		# Declared camera stations, not a claim of traversing the stair here.
		player.global_position = sign_node.global_position+normal*2.0-Vector3.UP*player.STANDING_EYE
		player.camera.global_position = sign_node.global_position+normal*2.0
		player.camera.look_at(sign_node.global_position)
		await get_tree().create_timer(.8).timeout
		var wall := PhysicsRayQueryParameters3D.create(sign_node.global_position+normal*.1,
			sign_node.global_position-normal*.3,1)
		wall.exclude = [player.get_rid()]
		_check(not world.get_world_3d().direct_space_state.intersect_ray(wall).is_empty(),str(sign_node.name)+" has physical wall support")
		var sight := PhysicsRayQueryParameters3D.create(player.camera.global_position,sign_node.global_position,1)
		sight.exclude = [player.get_rid()]
		_check(world.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),str(sign_node.name)+" is visible from its core")
		var title := sign_node.get_node("Floor") as Label3D
		_check(not title.text.is_empty() and not title.double_sided,str(sign_node.name)+" carries outward-facing floor lettering")
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(directory.path_join(str(sign_node.name)+".png"))
		var a := player.camera.unproject_position(sign_node.to_global(Vector3(-.58,.19,.016)))
		var b := player.camera.unproject_position(sign_node.to_global(Vector3(.58,-.01,.016)))
		var luminances: Array[float] = []
		for y in range(int(a.y),int(b.y),2):
			for x in range(int(a.x),int(b.x),2):
				var color := image.get_pixel(x,y).srgb_to_linear()
				var luminance := color.r*.2126+color.g*.7152+color.b*.0722
				luminances.append(luminance)
		luminances.sort()
		# Compare ink with its plate, not an absolute white target: upper stairs
		# retain their warmer, dimmer lighting. The title must have 3:1 contrast.
		var ink := luminances[int(luminances.size()*.05)] if not luminances.is_empty() else 1.0
		var plate := luminances[int(luminances.size()*.70)] if not luminances.is_empty() else 0.0
		var contrast := (plate+.05)/(ink+.05)
		print("V2 WAYFINDING: ",sign_node.name," ink=",ink," plate=",plate," contrast=",contrast)
		_check(plate>.12 and contrast>=3.0,
				str(sign_node.name)+" retains dark ink against the lamp-lit plate")
	world.shutdown_for_tests()
	world.free()
	print("V2 WAYFINDING: 16 plaques; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	print("V2 WAYFINDING: ",label," = ",ok)
	if not ok: failures.append(label)
