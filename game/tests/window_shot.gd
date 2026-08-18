extends Node
## The apartment windows, from the two places the owner reported them broken.
##     SHOT_DIR=<abs> godot --path game res://tests/WindowShot.tscn
##
## Owner, 2026-08-18: *"some of the windows on the orison are missing their
## treatment and glass entirely"*, *"when i look at the orison from the street
## the treatment on all the lower windows disapear, when i stand next to the
## building the top floors disapear but the window treatments appear"*.
##
## Both halves are one boundary seen from either side, so the stations are
## chosen to straddle it rather than to flatter the building:
##
##   CARRIAGEWAY  Godot |z| > 11.2, which is `_point_is_low_street`. The
##                street-core sweep fires here and used to take `F01_glazing`,
##                `F01_stone_trim`, `F01_sash` and the slats with it — every
##                ground-floor pane and every limestone jamb, head, projecting
##                cill and sash member on the storey.
##   AGAINST THE  Godot |z| between the shell at 10.05 and the old `outside`
##   FACADE       threshold at 11.2. The eye was neither outside nor on an
##                interior storey, so the stack above the viewer was culled.
##
## The frames are pinned to one hour, because a pair that differs by the clock
## as well as by the change is not evidence of anything.

var root: Node3D
var cam: Camera3D
var _failed := 0
var _passed := 0


func _ready() -> void:
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT_FORCE", "14:20")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	cam = Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if root.street_traffic != null:
		root.street_traffic.set_process(false)

	# A same-build control FIRST. Two frames of one scene at one station, so
	# the noise floor is known before any pair is read as a difference —
	# §P has been burned once by a "regression" that was the scene moving.
	# Blender coordinates: the street face is y = -10.05, the carriageway runs
	# out to y = -19, and GameBoot.b2g turns them into the Godot z the
	# visibility gate actually tests.
	await _capture("00_control_a", [2.0, -17.5, 1.68], [2.0, -10.0, 7.40])
	await _capture("00_control_b", [2.0, -17.5, 1.68], [2.0, -10.0, 7.40])

	await _capture("01_carriageway_elevation",
			[2.0, -17.5, 1.68], [2.0, -10.0, 7.40])
	await _capture("02_carriageway_ground_windows",
			[-3.6, -14.0, 1.68], [-4.1, -10.0, 1.95])
	# Godot z 10.9: past the 10.05 shell, inside the 11.2 the old `outside`
	# test demanded. This is the exact band where the stack used to vanish.
	# Clear of the entrance marquee, which is glass and sits directly over the
	# only spot on this facade where x = 0.
	await _capture("03_against_the_facade",
			[-7.0, -10.8, 1.68], [-6.6, -10.05, 7.60])
	await _capture("04_window_close",
			[-4.0, -11.7, 1.55], [-4.2, -10.0, 2.10])
	await _capture("05_from_the_room",
			[-4.1, -7.9, 1.60], [-4.1, -10.4, 1.75])

	# The frames are the deliverable; these are the claims they are supposed
	# to show, asserted so a later change cannot quietly undo them.
	var carriageway := GameBoot.b2g([2.0, -17.5, 1.68])
	root._apply_visibility(carriageway)
	var glazing: GeometryInstance3D = root.floor_nodes["F01"].get_node_or_null(
			"F01_glazing")
	var joinery: GeometryInstance3D = root.floor_nodes["F01"].get_node_or_null(
			"F01_stone_trim")
	_check("the ground floor keeps its glass from the carriageway",
			glazing != null and glazing.layers != 0)
	_check("the ground floor keeps its joinery from the carriageway",
			joinery != null and joinery.layers != 0)

	var against := GameBoot.b2g([-7.0, -10.8, 1.68])
	root._apply_visibility(against)
	var above := 0
	for fid in root.floor_nodes:
		if fid in ["F02", "F03", "F04", "F05", "F06"] \
				and root.floor_nodes[fid].visible:
			above += 1
	_check("the stack survives standing against the facade", above == 5)
	var props_above := 0
	for prop in root.functional_props_by_floor.get("F04", []):
		if prop.visible:
			props_above += 1
	_check("an upper storey is furnished from outdoors", props_above > 0)

	print("[WINDOW SHOT] 7 frames, %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _capture(label: String, blender_eye: Array,
		blender_target: Array) -> void:
	cam.global_position = GameBoot.b2g(blender_eye)
	cam.look_at(GameBoot.b2g(blender_target))
	# The visibility gate reads the CAMERA when `view_override` is set, but it
	# reads it on a physics tick, so a frame grabbed immediately after moving
	# is the previous station's cull with this station's lens.
	await get_tree().create_timer(1.25).timeout
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	if out_dir == "":
		push_error("SHOT_DIR is unset; street_shot.gd fails silently here "
				+ "and this one refuses to instead")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + label)
	else:
		_failed += 1
		push_error("  FAIL  " + label)


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	# SHOT_HIDE="a,b" hides every node whose name contains a token, the same
	# contract street_shot.gd and free_cam.gd use. Hiding a WHOLE CLASS at
	# once is what decides a question; hiding candidates one at a time only
	# narrows it, which is an hour this project has already spent.
	var hide := OS.get_environment("SHOT_HIDE")
	if hide != "" and node is Node3D:
		for token in hide.split(","):
			var t := token.strip_edges()
			if t != "" and String(node.name).findn(t) >= 0:
				(node as Node3D).visible = false
				print("[HIDE] %s" % node.name)
				break
	for child in node.get_children():
		_hide_capture_ui(child)
