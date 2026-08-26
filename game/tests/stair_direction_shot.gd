extends Node
## K2-D proof sheet — the stair plate, from the real acceptance pose.
##
##     $env:SHOT_DIR="<abs>"
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/StairDirectionShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## ONE FROZEN INSTANT. The shift is opened and the paper taken while thawed,
## then time stops and every comparison below is an A/B on that instant, so
## nothing in the room can drift between two frames being compared. No weather
## is in any frame, which is why the A/A floors are exact.
##
## The body, eye and lamp all belong to the production player: every camera
## here is `player.global_position = from - player.camera.position`, so what is
## framed is what a standing man at that spot can see.

var root: Node3D
var player: PlayerController
var pair: Node3D
var fire: Node3D
var out_dir := ""

## K2-C's measured acceptance pose, and the single turn away from it.
const DESK_FROM := [4.84, -2.27, 1.62]
const DESK_AT := [5.16, -2.30, 1.55]
const TURNED_AT := [3.56, -2.10, 1.55]
## The plate and the opening it points at, in one frame.
const AGREE_FROM := [4.55, -1.30, 1.62]
const AGREE_AT := [3.60, -6.60, 1.20]
## The corrected fire plate at the corridor's north end.
const FIRE_FROM := [4.40, 2.60, 1.55]
const FIRE_AT := [4.94, 2.92, 1.45]
## An ordinary later-shift walk-through, nothing staged.
const LATER_FROM := [4.30, 0.90, 1.62]
const LATER_AT := [3.60, -3.40, 1.45]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://k2d_shot"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	pair = root.find_child("StairDirectionPair_F01", true, false) as Node3D
	fire = root.find_child("FireDirection_F01", true, false) as Node3D
	var director: Node = root.get("first_shift_director")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	director.call("begin_first_shift")
	detector.call("interact_control", "detector", player)
	register.call("take_slip")

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	_look(DESK_FROM, DESK_AT, 72.0)
	await get_tree().create_timer(1.6).timeout
	player.set_process(false)
	Engine.time_scale = 0.0

	# 1. THE ACCEPTANCE POSE, and its A/A control. Facing the register, with the
	#    whole route behind the player's shoulder.
	await _snap("00_acceptance_control_a")
	await _snap("00_acceptance_control_b")

	# 2/3. THE ONE TURN. Same instant, same light, plate hidden and shown — the
	#      only difference between these two frames is the sign.
	_look(DESK_FROM, TURNED_AT, 72.0)
	await _snap("01_turned_control_a")
	await _snap("01_turned_control_b")
	pair.visible = false
	await _snap("02_the_turn_before")
	pair.visible = true
	await _snap("03_the_turn_after")

	# 4. DIRECTIONAL AGREEMENT. The plate and the opening it points at, in one
	#    frame: the arrow says south, and south down this corridor is the only
	#    place the west wall opens.
	_look(AGREE_FROM, AGREE_AT, 76.0)
	await _snap("04_the_plate_and_the_opening")

	# 5. THE MISLEADING CUE THE AUDIT FOUND — the same plate carrying its old
	#    arrow, which pointed north, away from the only route.
	_look(FIRE_FROM, FIRE_AT, 50.0)
	await _snap("05_fire_plate_control_a")
	await _snap("05_fire_plate_control_b")
	_relabel(fire, "FIRE EXIT — STAIRS  →", "←  FIRE EXIT — STAIRS")
	await _snap("06_the_arrow_as_it_was")
	_relabel(fire, "←  FIRE EXIT — STAIRS", "FIRE EXIT — STAIRS  →")
	await _snap("07_the_arrow_corrected")

	# 6. A LATER SHIFT. An ordinary walk down the corridor with nothing staged —
	#    the plate reading as building fabric, not as tutorial furniture.
	_look(LATER_FROM, LATER_AT, 70.0)
	await _snap("08_a_later_shift")

	Engine.time_scale = 1.0
	print("[K2D SHOT] written to %s" % out_dir)
	get_tree().quit(0)


## Swap one legend on a plate without rebuilding it, so the "before" frame is
## the same object at the same instant rather than a different scene.
func _relabel(node: Node, from_text: String, to_text: String) -> void:
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
	print("[K2D SHOT] %s" % label)
