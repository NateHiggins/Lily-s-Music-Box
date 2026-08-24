extends Node
## TL-1 production proof and frozen A/A control.

const SHOTS := [
	{"name": "01_carried_historical_silhouette", "pose": 0},
	{"name": "02_instrument_side", "pose": 1},
	{"name": "03_service_side", "pose": 2},
	{"name": "Z_control_a", "pose": 1},
	{"name": "Z_control_b", "pose": 1},
]

var _dir := ""


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	var root: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	root.player.global_position = Vector3(-0.40, 0.0, 8.60)
	root.player.rotation.y = deg_to_rad(-152.0)
	root.player.camera.rotation.x = deg_to_rad(-6.0)
	root.player.camera.make_current()
	root.player.set_lamp_enabled(true)
	for shot in SHOTS:
		root.service_set_carrier.set_proof_pose(int(shot.pose))
		root.player.set_lamp_enabled(int(shot.pose) == 0)
		for _frame in 24:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [_dir, str(shot.name)]
		var error := get_viewport().get_texture().get_image().save_png(path)
		print("[MODEL 28-R SHOT] %s %s" % [
				"saved" if error == OK else "FAIL", path])
		if error != OK:
			get_tree().quit(1)
			return
	print("[MODEL 28-R SHOT] RESULT: PASS")
	get_tree().quit()
