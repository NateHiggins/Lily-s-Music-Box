extends Node
## SR7-G proof sheet: the night register at the watchman station.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/NightRegisterShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, on the F01 east wall
## between the two entry doors, shot through the player's own camera and lit by
## the corridor's own ceiling fixtures. No proof-only light, mesh, material,
## camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION. A hook is never empty: it
## carries either its key or a numbered brass check, and those two things do
## not look alike. So "who has what" is readable across the frame, in one
## glance, from the shapes alone — and the spindle beside them is either
## carrying a report or standing bare.
##
## The abort frame is priced against the state the session started from, which
## is how reversibility is shown rather than asserted.

var root: Node3D
var player: PlayerController
var board: Node
var out_dir := ""

## Building coordinates. The board hangs at (5.24, -2.27, 1.42) facing west,
## 0.62 wide and 0.50 tall, with its shelf standing 0.17 m off the wall. The
## eye is 0.80 m off the face: any closer and the shelf and the book — half
## the apparatus — fall out of frame.
const BOARD_EYE := [4.37, -2.27, 1.70]
const BOARD_AIM := [5.15, -2.27, 1.60]
const BOARD_FOV := 44.0
const STATION_EYE := [3.60, -3.70, 1.68]
const STATION_AIM := [5.15, -1.92, 1.60]
const STATION_FOV := 60.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://night_register_sr7g"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	_hide_ui(get_tree().root)

	board = root.find_child("F01_NIGHT_REGISTER", true, false)
	player = root.get("player") as PlayerController
	if board == null or player == null:
		push_error("[REGISTER SHOT] no production register or player")
		get_tree().quit(1)
		return

	# The body stops FIRST and the camera is set afterwards: `_aim` moves the
	# player root and the camera rides on it, so a rig placed while physics is
	# still running settles before the first exposure. The player's own
	# `_process` stays alive a moment longer, because the lamp needs it —
	# `set_lamp_enabled` starts a gutter transient that `_process` has to
	# finish, and freezing first welds a half-lit lamp to the camera.
	player.set_physics_process(false)
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[REGISTER SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	board.set_process(false)
	Engine.time_scale = 0.0
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)

	# --- AS FOUND -----------------------------------------------------------
	# Both keys on their hooks and the spindle BARE, because at boot the
	# building has not reported anything. The board does not invent work.
	await _snap("00_station_control_a")
	await _snap("00_station_control_b")

	_aim(STATION_EYE, STATION_AIM, STATION_FOV)
	await _snap("01_station_context")
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)

	# --- THE REPORT ARRIVES, AND NOBODY TOUCHED THE BOARD -------------------
	# `ServiceRoundDirector.answer_incoming_call()` is the sole issuing owner;
	# this is the exact public call it makes. The slip appears on the spindle
	# because the spine now holds a job, not because the prop decided to.
	Engine.time_scale = 1.0
	var wo: Node = root.get("work_orders")
	wo.call("issue_job", str(board.get("JOB_ID")), "reported")
	Engine.time_scale = 0.0
	await _snap("02_report_arrives")

	# The condition the whole round has to be reversible from.
	var found: Dictionary = board.call("maintenance_snapshot")

	var plant := str(board.get("PLANT_HOOK"))
	var flat := str(board.get("APARTMENT_HOOK"))

	# --- THE REPORT OFF THE SPINDLE -----------------------------------------
	_act("take_slip")
	await _snap("03_report_taken")

	# --- EITHER KEY, IN ANY ORDER -------------------------------------------
	# The apartment key first here; the tests walk all six orders and prove
	# they reach one identical condition. There is no gate between these.
	_act("take_key", flat)
	await _snap("04_apartment_key_taken")
	_act("take_key", plant)
	await _snap("05_both_keys_taken")

	# --- REFUSAL 1: a hook carrying its check has no key on it --------------
	_act("take_key", plant)
	await _snap("06_second_plant_key_refused")

	# --- REFUSAL 2: you do not file the report holding the keys -------------
	_act("replace_slip")
	await _snap("07_filing_with_keys_out_refused")

	# --- BACK ON THEIR HOOKS ------------------------------------------------
	_act("return_key", plant)
	_act("return_key", flat)
	await _snap("08_keys_returned")
	_act("replace_slip")
	await _snap("09_report_filed")

	# --- THE ONE PUBLICATION ------------------------------------------------
	# Nothing above this line reached RealityState. Take the report and a key
	# again so there is something to sign for, then sign.
	_act("take_slip")
	_act("take_key", plant)
	_act("sign_register")
	await _snap("10_register_signed")

	_aim(STATION_EYE, STATION_AIM, STATION_FOV)
	await _snap("11_station_after")
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)

	# --- ABORT, PRICED ------------------------------------------------------
	# Restored through the same snapshot the panel's abort path uses. This
	# frame is measured against `02_report_arrives`: if the session is
	# genuinely reversible the two are the same photograph.
	Engine.time_scale = 1.0
	board.call("restore_maintenance_snapshot", found)
	Engine.time_scale = 0.0
	await _snap("12_restored_after_abort")

	Engine.time_scale = 1.0
	print("[REGISTER SHOT] 14 frames saved to %s" % out_dir)
	print("[REGISTER SHOT] slip_taken=%s keys_out=%d signed=%d stage=%s"
			% [board.get("slip_taken"), board.call("keys_out_count"),
					board.get("signed_lines"), board.call("job_stage")])
	get_tree().quit(0)


## One physical action on the frozen board. The balk timer is cleared first so
## each refusal frame shows its OWN refusal and never an inherited pose — with
## `_process` off to hold the world still, nothing else would clear it.
func _act(method: String, argument := "") -> void:
	Engine.time_scale = 1.0
	board.set("_balk_left", 0.0)
	if argument.is_empty():
		board.call(method)
	else:
		board.call(method, argument)
	Engine.time_scale = 0.0


## `PlayerController`'s camera sits a standing eye-height above its root, so the
## root goes to the requested eye MINUS that offset.
func _aim(eye: Array, target: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(eye) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(target), Vector3.UP)
	player.camera.make_current()


## `create_timer` is asked to ignore the time scale so the world can be frozen
## while the harness still waits in real seconds for the frame to settle.
func _snap(label: String) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[REGISTER SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
