extends Node
## K2-F proof sheet — which way the apartments lie, from the real F02 arrival.
##
##     $env:SHOT_DIR="<abs>"
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/UnitDirectionShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## Every camera is the production player's, so body, eye and carried lamp agree
## with what is framed. One frozen instant per camera.

var root: Node3D
var player: PlayerController
var plate: Node3D
var out_dir := ""

## WHERE THE PLATE IS ACTUALLY READ. The arrival itself, b(2.50, -2.26), sees
## the plate at about 65 degrees off its normal — 0.62 m of brass foreshortened
## to 0.26 m at 2.94 m, which is why the first pass photographed a landing with
## no legible sign in it. A player crossing the landing toward the west corridor
## passes square in front of it; this is that spot, 1.35 m out, and it is on the
## walk rather than staged for the lens.
const ARRIVAL_FROM := [-0.20, -3.25, 4.61]
const ARRIVAL_AT := [-0.35, -1.95, 4.15]
## THE CUE AND ITS DESTINATION IN ONE FRAME. The plate faces due south and the
## corridor it points down runs due west, so no camera holds both square-on.
## This is the reading position with the head turned 38 degrees left — the turn
## the legend itself asks for. The plate sits 31 degrees right of the axis, the
## west corridor mouth 37 degrees left of it, and an 88 degree frustum holds
## both. Two earlier tries stood east of the plate and photographed a corridor
## with no sign in it.
const WEST_FROM := [-0.20, -3.25, 4.61]
const WEST_AT := [-2.72, 0.00, 4.30]
## The 2A door, reached on foot, framed with its own brass number — which hangs
## 1.04 m north of the leaf, so the first pass at 1.4 m had the number off frame
## and photographed an anonymous dark door.
## Both hang on the same west end wall at x -5.33, the leaf at y -2.11 and the
## number 1.04 m north of it at y -1.07, so the camera stands on the corridor
## axis the body actually walked and aims between them.
## x -3.20 is inside the pier between the stair hall and the corridor and
## photographs solid black; -3.90 is the first open station west of it.
const DOOR_FROM := [-3.90, -2.14, 4.61]
const DOOR_AT := [-5.33, -1.45, 4.45]
## Floor four, where the same plate reads differently because the floor does.
## The same reading position as the F02 frame, 6.40 m higher.
const F04_FROM := [-0.20, -3.25, 11.01]
const F04_AT := [-0.35, -1.95, 10.55]
## An ordinary later shift.
const LATER_FROM := [0.90, -3.20, 4.61]
const LATER_AT := [-2.60, -2.20, 4.30]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://k2f_shot"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	plate = root.find_child("LandingPlate_F02", true, false) as Node3D
	var director: Node = root.get("first_shift_director")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	director.call("begin_first_shift")
	detector.call("interact_control", "detector", player)
	register.call("take_slip")

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	_look(ARRIVAL_FROM, ARRIVAL_AT, 74.0)
	await get_tree().create_timer(1.6).timeout
	player.set_process(false)
	Engine.time_scale = 0.0
	# THE HUD KEEPS ITS OWN CLOCK. The first pass of this sheet priced a 671x288
	# difference centred on the objective card, not on the plate: the arrival
	# toast was still fading when the world froze, because that overlay decays on
	# real time rather than on `Engine.time_scale`. Six real seconds with the
	# world stopped lets it finish, so the only thing left changing between the
	# before and after frames is the thing under test.
	await get_tree().create_timer(8.0, true, false, true).timeout

	# 1. THE ARRIVAL, and its A/A control.
	await _snap("00_arrival_control_a")
	await _snap("00_arrival_control_b")

	# 2/3. THE AMBIGUITY AND ITS ANSWER. Same instant, same light; the only
	#      difference between these two frames is the units line.
	_set_units(false)
	await _snap("01_arrival_before")
	_set_units(true)
	await _snap("02_arrival_after")
	# A TRAILING CONTROL, so the A/A floor brackets the priced pair rather than
	# preceding it. A base landed mid-task whose props step once on their own
	# clock; a leading control alone cannot see drift that happens after it.
	await _snap("02_arrival_control_c")

	# 4. THE CUE AND ITS DESTINATION IN ONE FRAME: the plate on the right of
	#    frame, the west corridor it points down receding to the left.
	_look(WEST_FROM, WEST_AT, 88.0)
	await _snap("03_corridor_control_a")
	await _snap("03_corridor_control_b")
	await _snap("04_the_way_the_glyph_points")

	# 5. THE DOOR REACHED — 2A, with its own brass number.
	_look(DOOR_FROM, DOOR_AT, 75.0)
	await _snap("05_the_2a_door")

	# 6. RECURRENCE, because it was implemented: floor four reads differently
	#    because floor four IS different — 4A west, 4C and 4D east.
	_look(F04_FROM, F04_AT, 74.0)
	await _snap("06_floor_four_reads_its_own_floor")

	# 7. AN ORDINARY LATER SHIFT, nothing staged.
	_look(LATER_FROM, LATER_AT, 72.0)
	await _snap("07_a_later_shift")

	Engine.time_scale = 1.0
	print("[K2F SHOT] written to %s" % out_dir)
	get_tree().quit(0)


## Hide or show only the two units labels, leaving K2-E's plate intact.
func _set_units(on: bool) -> void:
	_walk_labels(plate, on)


func _walk_labels(node: Node, on: bool) -> void:
	if node is Label3D:
		var t := str((node as Label3D).text)
		if t.contains("←") or t.contains("→"):
			(node as Label3D).visible = on
	for child in node.get_children():
		_walk_labels(child, on)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	print("[K2F SHOT] %s" % label)
