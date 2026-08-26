extends Node
## K2-B proof sequence — the clock answering where the hand touched it, and the
## paper arriving where the eye is not.
##
##     $env:SHOT_DIR="<abs>"; $env:SHOT_PART="a"|"b"
##     tools/run_godot_serial.ps1 -Scene res://tests/ClockAnswersShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## Both poses are driven by countdowns, never by `_t`, so a frozen frame holds
## them. Every state change happens THAWED, is waited out to a named instant,
## and is then frozen and photographed — which is how a 0.55 s key turn can be
## caught at its peak on a still sheet.

var root: Node3D
var player: PlayerController
var director: Node
var detector: Node
var register: Node
var out_dir := ""
var part := "a"

## The pose a hand actually clocks in from: the nearest standing place whose
## own 2.10 m prompt ray still lands on DetectorReach.
## The first pass stood at the interaction pose itself, 0.32 m off the case at
## FOV 55, and the paper dial filled the frame with the station key outside it
## entirely. A hand's reach is not a camera's. Pulled back to 0.9 m so the
## frame holds the key, the sheet and the lever together, which is what the
## claim is about.
const DETECTOR_FROM := [4.32, -1.46, 1.62]
const DETECTOR_AT := [5.16, -1.48, 1.58]
## Wide enough to hold the clock and the register together — which is the whole
## question this increment is about.
const DESK_FROM := [4.28, -1.72, 1.62]
const DESK_AT := [5.16, -1.95, 1.58]
## K2-A's corridor, for continuity.
const SPINE_FROM := [4.20, -9.10, 1.62]
const SPINE_AT := [5.10, -1.60, 1.50]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://k2b_shot"
	part = OS.get_environment("SHOT_PART")
	if part.is_empty():
		part = "a"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	director = root.get("first_shift_director")
	detector = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	register = root.find_child("F01_NIGHT_REGISTER", true, false)
	director.call("begin_first_shift")

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	if part == "a":
		await _part_a()
	else:
		await _part_b()
	Engine.time_scale = 1.0
	print("[K2B SHOT] part %s written to %s" % [part, out_dir])
	get_tree().quit(0)


# --- part A: the apparatus the hand is on ------------------------------------

func _part_a() -> void:
	_look(DETECTOR_FROM, DETECTOR_AT, 62.0)
	await get_tree().process_frame
	player.set_process(false)
	# Clock in FIRST, then freeze once and never thaw again. Everything below is
	# an A/B on ONE frozen instant, because the movement hand sweeps with the
	# house clock: an earlier pass thawed between shots and measured the hand
	# as well as the claim, which is a number about a clock rather than about
	# this increment.
	await _thaw()
	detector.call("interact_control", "detector", player)
	await get_tree().create_timer(0.27).timeout
	_freeze()
	print("[K2B SHOT] frozen with %.3f s of key turn left"
			% detector.call("key_turn_remaining"))
	var mark: Node3D = detector.find_child("ShiftPunch", true, false) as Node3D

	# A/A at this instant. Nothing is touched between these two.
	await _snap("00_detector_control_a")
	await _snap("00_detector_control_b")

	# THE KEY, TURNING AND HOME, at the same instant and the same light.
	await _snap("01_the_key_turns")
	var held: float = detector.call("key_turn_remaining")
	detector.set("_key_left", 0.0)
	detector.call("_refresh_mechanism")
	await _snap("02_the_key_home")

	# THE PUNCH, on the sheet and off it, at the same instant. The mark is the
	# only thing that differs between these two frames.
	if mark != null:
		mark.visible = false
	await _snap("03_the_sheet_without_it")
	if mark != null:
		mark.visible = true
	await _snap("04_the_punch_on_the_sheet")

	# A REFUSAL WINS OVER THE TURN. Same part, same instant: the key is mid
	# throw AND the machine is balking, and the frame shows the balk. This is
	# the ordering claim in the code, photographed.
	detector.set("_key_left", held)
	detector.call("_balk", 2.0)
	detector.call("_refresh_mechanism")
	await _snap("05_a_refusal_wins_over_the_turn")
	detector.set("_balk_left", 0.0)
	detector.set("_key_left", 0.0)
	detector.call("_refresh_mechanism")
	await _snap("06_calm")


# --- part B: the foot to the right -------------------------------------------

func _part_b() -> void:
	_look(DESK_FROM, DESK_AT, 78.0)
	await get_tree().process_frame
	player.set_process(false)
	# Clock in, catch the landing, and then FREEZE ONCE. Everything below is an
	# A/B on one instant, for the same reason part A is: thawing between shots
	# lets the detector's movement hand sweep, and an earlier pass measured a
	# 702 x 522 region for a claim about a sheet of paper.
	await _thaw()
	detector.call("interact_control", "detector", player)
	await get_tree().create_timer(0.22).timeout
	_freeze()
	print("[K2B SHOT] frozen with %.3f s of landing left"
			% register.call("slip_landing_remaining"))
	var held: float = register.call("slip_landing_remaining")

	# A/A at the wide camera that holds the clock AND the register — which is
	# the whole question this increment is about.
	await _snap("10_desk_control_a")
	await _snap("10_desk_control_b")

	# THE PAPER MID-FALL, and the same instant with it home on the spike.
	await _snap("11_the_paper_lands")
	register.set("_landing_left", 0.0)
	register.call("_refresh_board")
	await _snap("12_the_paper_settled")

	# TAKEN. State only; no thaw, so nothing else in the frame moves.
	register.call("take_slip")
	register.call("_refresh_board")
	await _snap("13_the_report_taken")

	# And put it back, to show the spindle bare against the settled frame.
	register.call("replace_slip")
	register.set("_landing_left", held)
	register.call("_refresh_board")
	await _snap("14_the_paper_lands_again")

	# CONTINUITY WITH K2-A: the same corridor frame, at the end of the minute.
	register.set("_landing_left", 0.0)
	register.call("_refresh_board")
	_look(SPINE_FROM, SPINE_AT, 66.0)
	await _snap("15_first_minute_continuity")


# --- harness -----------------------------------------------------------------

func _freeze() -> void:
	Engine.time_scale = 0.0


func _thaw() -> void:
	Engine.time_scale = 1.0
	await get_tree().process_frame


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
	print("[K2B SHOT] %s" % label)
