extends Node
## Visual proof for the service-wire paper, type hierarchy, physical printer
## and its position away from the crosshair and work-order slip.

var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("TELEGRAM_REDUCED_TYPEWRITER", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	root.player.global_position = Vector3(-0.40, 0.0, 8.60)
	root.player.rotation.y = deg_to_rad(-152.0)
	root.player.camera.rotation.x = deg_to_rad(-6.0)
	root.player.camera.make_current()
	root.objective_tracker.show_objective("Cold-box inspection",
			"Open the 4B refrigerator and note the hinge condition.")
	root.service_set_carrier.print_telegram_card("Refrigerator")
	root.player.telegram_hud.present({
		"title": "General Electric monitor-top refrigerator",
		"body": "THE LATCH ANSWERED CLEANLY STOP THE HINGE SETTLES ONE DEGREE LOW STOP",
		"condition": "PRESENT CONDITION / OPEN",
		"stamp": "SERVICE NOTE",
	})
	for _frame in 28:
		await get_tree().process_frame
	print("[TELEGRAM SHOT] body chars=%d/%d rect=%s visible=%s" % [
			root.player.telegram_hud._body.visible_characters,
			root.player.telegram_hud._body.text.length(),
			root.player.telegram_hud._body.get_rect(),
			root.player.telegram_hud._body.is_visible_in_tree()])
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("telegram_service_wire.png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[TELEGRAM SHOT] %s %s" % ["saved" if error == OK else "FAIL", path])
	get_tree().quit(0 if error == OK else 1)
