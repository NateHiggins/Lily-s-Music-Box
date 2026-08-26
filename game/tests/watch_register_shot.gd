extends Node
## SR7-K proof sheet: the far end of the watchman's line.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/WatchRegisterShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, on the F01 lobby's
## east wall in the watchman's lane, shot through the player's own camera and
## lit by the corridor's own fixtures. No proof-only light, mesh, material,
## camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * The pilot is the first thing the eye lands on, and it is green or red.
##   * A shutter is up or fallen; the number on it is the station.
##   * The counter only goes up.
##   * On an OPEN line the board looks exactly like a board nobody signalled —
##     which is the whole lesson, and the reason the pilot exists.

var root: Node3D
var player: PlayerController
var board: Node
var box: Node
var net: Node
var out_dir := ""

## The case hangs at (5.24, -3.55, 1.42) facing west into the lobby.
const BOARD_EYE := [4.55, -3.55, 1.72]
const BOARD_AIM := [5.20, -3.55, 1.63]
const BOARD_FOV := 44.0
## The lane: detector, night register and this board on one wall.
const LANE_EYE := [3.55, -4.70, 1.68]
const LANE_AIM := [5.18, -2.60, 1.55]
const LANE_FOV := 62.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://watch_register_sr7k"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	board = root.find_child("F01_SIGNAL_REGISTER", true, false)
	box = root.find_child("F02_WATCH_STATION_01", true, false)
	net = root.find_child("WatchStationNetwork", true, false)
	player = root.get("player") as PlayerController
	if board == null or box == null or net == null or player == null:
		push_error("[SIGNAL SHOT] the line is not complete in production")
		get_tree().quit(1)
		return
	# The board's legends are Label3D, the established Orison prop lettering
	# idiom. The overlay sweep must not blank the instrument's own printing.
	_hide_ui(get_tree().root)

	player.set_physics_process(false)
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[SIGNAL SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	board.set_process(false)
	box.set_process(false)
	Engine.time_scale = 0.0
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)

	# --- AS FOUND -----------------------------------------------------------
	# Line closed, every shutter up, counter at nought.
	await _snap("00_board_control_a")
	await _snap("00_board_control_b")

	_aim(LANE_EYE, LANE_AIM, LANE_FOV)
	await _snap("01_lane_control_a")
	await _snap("01_lane_control_b")
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)

	var found: Dictionary = board.call("maintenance_snapshot")

	# --- A SIGNAL ARRIVES ---------------------------------------------------
	# Worked at the far end of the building, two floors up. Nothing here is
	# touched: the shutter falls because current came down the wire.
	_work_the_box()
	await _snap("02_signal_received")
	_aim(LANE_EYE, LANE_AIM, LANE_FOV)
	await _snap("03_lane_signal_received")
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)

	# --- A REPEAT IS REFUSED ------------------------------------------------
	_act(board, "receive_signal", {"station_number": 2, "sequence": 2})
	await _snap("04_repeat_refused")

	# --- RESET --------------------------------------------------------------
	_act(board, "reset_shutters")
	await _snap("05_shutters_restored")
	# The counter did not go back, and a clear board has nothing to restore.
	_act(board, "reset_shutters")
	await _snap("06_reset_of_clear_board_refused")

	# --- THE OPEN LINE ------------------------------------------------------
	_act(net, "set_line_closed", false)
	await _snap("07_line_open")
	# Work the box with the wire cut. Its drop falls; nothing arrives here.
	_reset_the_box()
	_work_the_box()
	await _snap("08_open_line_nothing_arrives")
	_act(net, "set_line_closed", true)
	await _snap("09_line_closed_no_backfill")

	# --- ABORT --------------------------------------------------------------
	Engine.time_scale = 1.0
	board.call("restore_maintenance_snapshot", found)
	Engine.time_scale = 0.0
	await _snap("10_restored_after_abort")
	_aim(LANE_EYE, LANE_AIM, LANE_FOV)
	await _snap("11_lane_after_abort")

	Engine.time_scale = 1.0
	print("[SIGNAL SHOT] frames saved to %s" % out_dir)
	print("[SIGNAL SHOT] line=%s shutters=%d counter=%d marks=%d delivered=%d"
			% [board.get("line_closed"), board.call("indication_count"),
					board.get("signals_taken"), net.call("mark_count"),
					net.call("delivered_count")])
	get_tree().quit(0)


## Work the real station box two floors up, with the world briefly unfrozen so
## the network's own delivery runs. The board is never touched.
func _work_the_box() -> void:
	Engine.time_scale = 1.0
	box.set("_balk_left", 0.0)
	box.call("open_door")
	box.call("turn_crank")
	Engine.time_scale = 0.0


func _reset_the_box() -> void:
	Engine.time_scale = 1.0
	box.set("_balk_left", 0.0)
	box.call("reset_station")
	Engine.time_scale = 0.0


## One action on a frozen instrument. The balk is cleared first so each refusal
## frame shows its OWN refusal and never an inherited pose.
func _act(target: Node, method: String, argument: Variant = null) -> void:
	Engine.time_scale = 1.0
	target.set("_balk_left", 0.0)
	target.set("_balk_focus", "")
	if argument == null:
		target.call(method)
	else:
		target.call(method, argument)
	Engine.time_scale = 0.0


func _aim(eye: Array, target: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(eye) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(target), Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[SIGNAL SHOT] capture failed: %s" % label)


## Sweeps production's debug overlays. THE BOARD IS EXEMPT: its pilot legend,
## shutter numbers and counter are Label3D, and hiding every Label3D in the
## tree would blank the instrument this sheet exists to photograph.
func _hide_ui(node: Node) -> void:
	if node == board:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
