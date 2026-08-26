extends Node
## K2-E proof sheet — the landing plate, from the real choice point.
##
##     $env:SHOT_DIR="<abs>"
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/LandingPlateShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## ONE FROZEN INSTANT per camera, and every camera is the production player's:
## `player.global_position = from - player.camera.position`, so body, eye and
## carried lamp agree with what is framed. No weather is in any frame.

var root: Node3D
var player: PlayerController
var plate: Node3D
var fire: Node3D
var out_dir := ""

## The choice point: where a body arriving from the entrance hall is stopped by
## the well guard.
const CHOICE_FROM := [0.00, -2.90, 1.62]
const CHOICE_AT := [-0.35, -1.95, 0.95]
## Wide enough to hold the plate and the arm that actually climbs.
const BOTH_FROM := [0.30, -3.10, 1.62]
const BOTH_AT := [-1.60, 0.20, 1.05]
## The corrected fire plate at the corridor's north end.
const FIRE_FROM := [4.40, 2.60, 1.55]
const FIRE_AT := [4.94, 2.92, 1.45]
## The same landing three floors up, to show the wording repeats truthfully.
const F03_FROM := [0.00, -2.90, 8.02]
const F03_AT := [-0.35, -1.95, 7.35]
## An ordinary walk through the landing, nothing staged.
const LATER_FROM := [1.60, -3.40, 1.62]
const LATER_AT := [-1.40, -0.60, 1.30]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://k2e_shot"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	plate = root.find_child("LandingPlate_F01", true, false) as Node3D
	fire = root.find_child("FireDirection_F01", true, false) as Node3D
	var director: Node = root.get("first_shift_director")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	director.call("begin_first_shift")
	detector.call("interact_control", "detector", player)
	register.call("take_slip")

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	_look(CHOICE_FROM, CHOICE_AT, 74.0)
	await get_tree().create_timer(1.6).timeout
	player.set_process(false)
	Engine.time_scale = 0.0

	# 1. ARRIVAL AT THE CHOICE POINT, and its A/A control.
	await _snap("00_choice_control_a")
	await _snap("00_choice_control_b")

	# 2/3. THE AMBIGUITY AND ITS ANSWER. Same instant, same light; the only
	#      difference between these two frames is the plate.
	plate.visible = false
	await _snap("01_the_landing_as_it_was")
	plate.visible = true
	await _snap("02_the_landing_now")

	# 4. THE PLATE AND THE ARM THAT CLIMBS, in one composition — the flight
	#    that goes up on the left, and the plate naming the floors it reaches.
	_look(BOTH_FROM, BOTH_AT, 80.0)
	await _snap("03_control_a")
	await _snap("03_control_b")
	await _snap("04_plate_and_the_climbing_arm")

	# 5. F01'S STREET-LEVEL WORDING, corrected. K2-D reported the old line as a
	#    lie; this is the same plate carrying it, and carrying the truth.
	_look(FIRE_FROM, FIRE_AT, 50.0)
	await _snap("05_fire_control_a")
	await _snap("05_fire_control_b")
	_relabel(fire, "STREET LEVEL — THIS FLOOR", "STREET LEVEL ↓")
	await _snap("06_street_level_as_it_was")
	_relabel(fire, "STREET LEVEL ↓", "STREET LEVEL — THIS FLOOR")
	await _snap("07_street_level_corrected")

	# 6. THE SAME LANDING THREE FLOORS UP, where the wording differs because
	#    the building does: floor 3 offers both up and down.
	_look(F03_FROM, F03_AT, 74.0)
	await _snap("08_the_same_plate_on_floor_three")

	# 7. AN ORDINARY LATER SHIFT — nothing staged, the plate as fabric.
	_look(LATER_FROM, LATER_AT, 72.0)
	await _snap("09_a_later_shift")

	Engine.time_scale = 1.0
	print("[K2E SHOT] written to %s" % out_dir)
	get_tree().quit(0)


func _relabel(node: Node, from_text: String, to_text: String) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is Label3D and str((child as Label3D).text) == from_text:
			(child as Label3D).text = to_text
		_relabel(child, from_text, to_text)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	print("[K2E SHOT] %s" % label)
