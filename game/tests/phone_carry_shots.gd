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
	{"name": "q_04_pairs", "raised": true, "at": 6.0, "app": "pairs"},
	{"name": "q_05_maze", "raised": true, "at": 6.0, "app": "maze"},
	{"name": "q_06_shards", "raised": true, "at": 6.0, "app": "shards"},
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
	# Put something on the roll. Both cartridges hide a photograph the
	# player took, so with an empty roll these frames would show the
	# game over a dark rectangle and prove nothing about the join.
	carrier.raised = true
	carrier.phone.os_sim.screen = PhoneOS.Screen.APP
	carrier.phone.os_sim.app_id = "cam"
	carrier.phone.os_sim.gallery_open = false
	for i in 24:
		await get_tree().process_frame
	for i in 3:
		root.player.rotation.y = deg_to_rad(-152.0 + i * 42.0)
		for f in 10:
			await get_tree().process_frame
		carrier.phone.cam.capture()
	root.player.rotation.y = deg_to_rad(-152.0)
	var failures := 0
	for shot in SHOTS:
		carrier.raised = bool(shot.raised)
		# Drive the OS to a settled state rather than waiting out boot.
		if shot.has("app"):
			carrier.phone.os_sim.screen = PhoneOS.Screen.APP
			carrier.phone.os_sim.app_id = str(shot.app)
			var roll: Array = carrier.phone.cam.roll
			var load_photo := func(p): return carrier.phone.cam.load_photo(p)
			if str(shot.app) == "pairs":
				carrier.phone.pairs.start(roll, load_photo)
				# Turn three up so the frame catches the game mid-play
				# rather than as sixteen identical backs.
				for c in [0, 5, 9]:
					carrier.phone.pairs.cursor = c
					carrier.phone.pairs.key("ok")
			elif str(shot.app) == "maze":
				carrier.phone.maze.start(roll, load_photo, 1)
				# Roll the marble around for a moment so the shot shows a
				# trail wiped through the fog, which is the whole look of
				# the thing. A fresh chamber is just a dark rectangle.
				carrier.phone.maze.layout(Rect2(10, 32, 460, 304))
				# A slowly rotating tilt, which is close to what a hand
				# does when it is hunting rather than aiming. Ten seconds
				# of it wipes enough fog to see the picture underneath.
				for i in 640:
					var a := i * 0.011
					carrier.phone.maze.tilt_ax = 26.0 * cos(a)
					carrier.phone.maze.tilt_ay = 26.0 * sin(a * 1.37)
					carrier.phone.maze.tick(0.016)
				carrier.phone.maze.tilt_ax = 0.0
				carrier.phone.maze.tilt_ay = 0.0
			elif str(shot.app) == "shards":
				carrier.phone.shards.start(roll, load_photo, 12)
				carrier.phone.shards.layout(Rect2(10, 32, 460, 304))
				# Seat a third of the glass so the frame shows both
				# states at once: pieces home with their gold hairline,
				# and pieces still loose over their dashed ghosts.
				for i in [0, 3, 6, 9]:
					var s: Dictionary = carrier.phone.shards.shards[i]
					s["off"] = Vector2.ZERO
					s["v"] = Vector2.ZERO
				carrier.phone.shards.tick(0.016)
		else:
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
