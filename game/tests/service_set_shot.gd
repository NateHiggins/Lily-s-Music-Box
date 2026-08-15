extends Node
## Four-frame production proof: actual carried silhouette and the two faces of
## the model, including every physical state the player has to read.

const SHOTS := [
	{"name": "01_carried_lamp_on", "pose": 0, "lamp": true,
		"radio": true, "order": false},
	{"name": "02_carried_lamp_off", "pose": 0, "lamp": false,
		"radio": true, "order": false},
	{"name": "03_front_order_lit", "pose": 1, "lamp": false,
		"radio": true, "order": true},
	{"name": "04_back_mod_indicators", "pose": 2, "lamp": true,
		"radio": true, "order": true},
]

var root: Node3D
var _dir := ""


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	root.player.global_position = Vector3(-0.40, 0.0, 8.60)
	root.player.rotation.y = deg_to_rad(-152.0)
	root.player.camera.rotation.x = deg_to_rad(-6.0)
	root.player.camera.make_current()
	await _run()


func _run() -> void:
	var carrier: ServiceSetCarrier = root.service_set_carrier
	var orders: WorkOrders = root.work_orders
	var failures := 0
	for shot in SHOTS:
		carrier.set_proof_pose(int(shot.pose))
		carrier.set_radio_powered(bool(shot.radio))
		root.player.set_lamp_enabled(bool(shot.lamp))
		if bool(shot.order) and not orders.has_open_work():
			orders.issue("service_set_shot", "Proof order", "Photograph")
		for _frame in 24:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_dir, str(shot.name)]
		if image.save_png(path) != OK:
			print("[SERVICE SET SHOT] FAIL writing %s" % path)
			failures += 1
		else:
			print("[SERVICE SET SHOT] saved %s" % path)
	print("[SERVICE SET SHOT] RESULT: %s" % [
			"PASS" if failures == 0 else "FAIL"])
	get_tree().quit(failures)
