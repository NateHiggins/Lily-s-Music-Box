extends Node
## The handset as the player actually sees it.
##
## Has to render through the PLAYER'S camera rather than a fresh one:
## the phone is parented to that camera, so any other viewpoint shows
## an empty lobby and proves nothing. screenshot_run.gd makes its own
## camera, which is why this is a separate pass and not another entry
## in its list.
##
##   SHOT_DIR=<abs windows path> godot --path game \
##       res://tests/PhoneCarryShots.tscn
##
## Real window required, as with every shot pass here.

const SHOTS := [
	{"name": "q_01_carried", "raised": false, "at": 2.6},
	{"name": "q_02_raised", "raised": true, "at": 2.6},
	{"name": "q_03_raised_home", "raised": true, "at": 6.0},
]

var root: Node3D
var _dir := ""


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.2).timeout
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false     # the phone IS the HUD here
	_run()


func _run() -> void:
	var carrier = root.get("phone_carrier")
	if carrier == null:
		print("[CARRY] FAIL: no phone_carrier on the building")
		get_tree().quit(1)
		return
	# Stand in the lobby looking at the mail bank, so the frame has some
	# building in it to judge the phone against.
	root.player.global_position = Vector3(-0.4, 0.0, 8.6)
	root.player.rotation.y = deg_to_rad(-152.0)
	root.player.camera.rotation.x = deg_to_rad(-6.0)
	root.player.camera.make_current()
	var failures := 0
	for shot in SHOTS:
		carrier.raised = bool(shot.raised)
		# Drive the OS to a settled state rather than waiting out boot.
		carrier.phone.os_sim.screen = PhoneOS.Screen.HOME \
				if float(shot.at) > 4.0 else PhoneOS.Screen.MOTD
		carrier.phone.os_sim.t = float(shot.at)
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [_dir, shot.name]
		if img.save_png(path) != OK:
			print("[CARRY] FAILED writing %s" % path)
			failures += 1
		else:
			print("[CARRY] saved %s" % path)
	print("[CARRY] RESULT: %s" % ["PASS" if failures == 0 else "FAIL"])
	get_tree().quit(failures)
