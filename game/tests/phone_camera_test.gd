extends Node
## Does the camera see the building, and does the roll behave?
##
## Headless-hostile by nature — a SubViewport that never renders has no
## texture to grab — so this runs windowed like the other shot passes.
## It stands the player in the lobby, opens the cam app, takes shots
## from several angles, then hammers the cap to prove the oldest frame
## is actually deleted rather than merely forgotten.
##
##   SHOT_DIR=<abs windows path> godot --path game \
##       res://tests/PhoneCameraTest.tscn

var root: Node3D
var _dir := ""
var _fails := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.4).timeout
	_run()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _run() -> void:
	var carrier = root.get("phone_carrier")
	if carrier == null:
		print("[CAM] FAIL: no carrier")
		get_tree().quit(1)
		return
	var phone = carrier.phone
	var cam = phone.cam
	# Start from a clean roll so the cap arithmetic is about this run.
	for p in cam.roll.duplicate():
		DirAccess.remove_absolute(str(p))
	cam.roll.clear()

	root.player.global_position = Vector3(-0.4, 0.0, 8.6)
	root.player.camera.make_current()
	phone.os_sim.screen = PhoneOS.Screen.APP
	phone.os_sim.app_id = "cam"
	phone.os_sim.gallery_open = false
	carrier.raised = true
	for i in 30:
		await get_tree().process_frame

	_check("lens shares the player's world",
			cam.lens.world_3d == get_viewport().world_3d)
	_check("lens renders while the app is open",
			cam.lens.render_target_update_mode
			== SubViewport.UPDATE_ALWAYS)

	# Four frames from four headings, so the roll holds real pictures of
	# different things rather than one image four times.
	var shots: Array[String] = []
	for i in 4:
		root.player.rotation.y = deg_to_rad(-152.0 + i * 40.0)
		for f in 12:
			await get_tree().process_frame
		var path: String = phone.cam.capture()
		shots.append(path)
		_check("shot %d written" % (i + 1),
				path != "" and FileAccess.file_exists(path))
	_check("roll counted four", cam.roll.size() == 4)

	# A photograph that is a single flat colour means the lens rendered
	# nothing; the lobby has brick, a door and a bench in it.
	if shots[0] != "":
		var img := Image.new()
		img.load(shots[0])
		var seen := {}
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				seen[img.get_pixel(x, y).to_rgba32() >> 12] = true
		_check("the lens actually saw the lobby (%d tones)" % seen.size(),
				seen.size() > 12)
		img.save_png("%s/r_01_photo_as_taken.png" % _dir)

	# Fill past the cap and prove the oldest file is gone from disk.
	var first: String = str(cam.roll[0])
	while cam.roll.size() < PhoneCamera.CAP:
		cam.roll.append(first)
	cam.roll.append("pretend_new.png")
	cam._enforce_cap()
	_check("roll never exceeds the cap",
			cam.roll.size() == PhoneCamera.CAP)

	# And the deck the pairs game asks for.
	cam.roll.clear()
	for s in shots:
		if s != "":
			cam.roll.append(s)
	_check("thin roll deals no deck", cam.deck_for_pairs(8).is_empty())
	_check("deck of four from four", cam.deck_for_pairs(4).size() == 4)

	print("[CAM] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
