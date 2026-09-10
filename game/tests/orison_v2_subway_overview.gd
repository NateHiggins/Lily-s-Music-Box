extends Node
## Daylight spatial review of the subway/arcade relationship, not gameplay proof.
func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	var world = preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	if world.startup_failed:
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for node in world.service_set_carrier.get_children():
		if node is CanvasLayer: node.visible = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8,4.5,9)
	camera.look_at(Vector3(7.5,1.7,17.5))
	camera.make_current()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join("subway_and_arcade.png"))
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().process_frame
	print("V2 SUBWAY OVERVIEW: captured")
	get_tree().quit()
