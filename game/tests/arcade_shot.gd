extends Node
## Stands in front of the arcade cabinets and photographs them.
##
##     SHOT_DIR=... godot --path game res://tests/ArcadeShot.tscn
##
## Needs a real window: the cabinets' screens are SubViewports and the marquee is
## emissive, so a headless run photographs neither. Three frames land in
## SHOT_DIR - the row as the player meets it, one screen close enough to read the
## attract copy, and the same screen with the reality infection wound up, where
## the machine stops being able to hold the picture together and the compiled
## skin comes off the world behind it.

var root: Node3D
var _cabinets: Array = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	for child in root.get_children():
		if child is CanvasLayer:
			child.visible = false
	_run()


func _run() -> void:
	await get_tree().create_timer(1.5).timeout

	_cabinets = get_tree().get_nodes_in_group("arcade_cabinets")
	if _cabinets.is_empty():
		# The group is set by the prop; fall back to a name scan so this test
		# still reports something useful if that ever changes.
		_cabinets = root.find_children("Arcade_*", "", true, false)
	if _cabinets.is_empty():
		print("[SHOT] no arcade cabinets in the building")
		get_tree().quit(1)
		return

	var camera := Camera3D.new()
	camera.fov = 66
	add_child(camera)
	camera.make_current()

	# The cabinets are woken by proximity, and the camera is not the player, so
	# put the player in front of them too or the boards stay unpowered.
	var first: Node3D = _cabinets[0]
	var front := first.global_transform.basis.z * -1.0

	if root.player:
		root.player.global_position = first.global_position + front * 1.9 + Vector3.UP * 1.6

	await _shoot(camera, first.global_position + front * 2.6 + Vector3.UP * 1.75,
			first.global_position + Vector3.UP * 1.25, "arcade_row")

	await _shoot(camera, first.global_position + front * 1.45 + Vector3.UP * 1.32,
			first.global_position + Vector3.UP * 1.29, "arcade_attract")

	# The same board's output, straight off the viewport. If this has a picture
	# and the frame above does not, the fault is the screen and not the game.
	var directory := OS.get_environment("SHOT_DIR")
	if directory == "":
		directory = OS.get_user_data_dir()
	var machine = first.get("machine")
	print("[SHOT] booted=%s live=%s" % [
		str(machine != null and machine.is_booted()),
		str(machine != null and machine.render_target_update_mode != SubViewport.UPDATE_DISABLED),
	])
	if machine != null and machine.is_booted():
		machine.get_texture().get_image().save_png(directory + "/arcade_feed_inworld.png")
		print("[SHOT] saved ", directory, "/arcade_feed_inworld.png")

	# Wind the infection up by hand. In play this arrives from the acoustic graph
	# as a case escalates; here it is set directly so the frame is reproducible.
	for cabinet in _cabinets:
		cabinet._infection = 0.85
		cabinet._apply_infection()
	await _shoot(camera, first.global_position + front * 1.45 + Vector3.UP * 1.32,
			first.global_position + Vector3.UP * 1.29, "arcade_infected")

	get_tree().quit(0)


func _shoot(camera: Camera3D, from: Vector3, at: Vector3, stem: String) -> void:
	camera.global_position = from
	camera.look_at(at)
	# Long enough for the machine to boot, bind its package and run a few seconds
	# of attract, which is what makes the copy on the screen worth photographing.
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	if directory == "":
		directory = OS.get_user_data_dir()
	var path := "%s/%s.png" % [directory, stem]
	get_viewport().get_texture().get_image().save_png(path)
	print("[SHOT] saved ", path)
