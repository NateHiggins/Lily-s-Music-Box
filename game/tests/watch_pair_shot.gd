extends Node
## SR7-M proof sheet: two boxes, two numbers, one board.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/WatchPairShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Three places in one building: the boiler room in the basement, the F02
## corridor, and the lobby board that hears from both. All through the player's
## own camera, lit by the rooms' own fixtures. No proof-only light, mesh,
## material, camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * The second station is somewhere ELSE, and somewhere different in kind:
##     the plant, not a papered corridor.
##   * Its drop is its own, and its plate reads STATION 1 against the other's 2.
##   * The lobby board's two windows fill independently, and a shutter that is
##     still parked says nothing at all.

var root: Node3D
var player: PlayerController
var boiler: Node
var landing: Node
var guard: Node
var board: Node
var net: Node
var out_dir := ""
var part := ""

## The boiler box hangs at (9.05, -0.88, -1.38) facing north into the plant.
const BOILER_OFFSET := Vector3(0.0, 0.24, -0.66)
const BOILER_FOV := 40.0
## The room, from inside it, with the boiler beyond the box.
## Standing in the boiler room with the boiler on the left and the station on
## the bunker wall to the right -- the two things the round is here for, in one
## frame, under the room's one cage bulb.
const PLANT_EYE := [12.10, 5.30, -1.15]
const PLANT_AIM := [12.00, 2.85, -1.42]
const PLANT_FOV := 62.0
## The lobby board.
const BOARD_EYE := [4.55, -3.55, 1.72]
const BOARD_AIM := [5.20, -3.55, 1.63]
const BOARD_FOV := 44.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	part = OS.get_environment("SHOT_PART").to_lower()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://watch_pair_sr7m"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	boiler = root.find_child("B1_WATCH_STATION_01", true, false)
	landing = root.find_child("F02_WATCH_STATION_01", true, false)
	guard = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	board = root.find_child("F01_SIGNAL_REGISTER", true, false)
	net = root.find_child("WatchStationNetwork", true, false)
	player = root.get("player") as PlayerController
	if boiler == null or landing == null or board == null or player == null:
		push_error("[PAIR SHOT] the two-station line is not complete")
		get_tree().quit(1)
		return
	# The plates are Label3D, the established Orison prop lettering idiom.
	_hide_ui(get_tree().root)

	player.set_physics_process(false)
	_aim_boiler()
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[PAIR SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	for prop in [boiler, landing, board, guard]:
		if prop != null:
			prop.set_process(false)
	Engine.time_scale = 0.0

	if part != "b":
		# --- THE SECOND PLACE -----------------------------------------------
		_aim_boiler()
		await _snap("00_boiler_control_a")
		await _snap("00_boiler_control_b")
		_aim(PLANT_EYE, PLANT_AIM, PLANT_FOV)
		await _snap("01_plant_control_a")
		await _snap("01_plant_control_b")
		_aim_boiler()

		# NO KEY: the refusal, at the second box as at the first.
		_act(boiler, "open_door")
		await _snap("02_boiler_open_no_key")
		_act(boiler, "turn_crank")
		await _snap("03_boiler_empty_socket_refused")

		# THE KEY, taken three floors up, and the same box works.
		_act(guard, "take_key")
		_act(boiler, "restore_maintenance_snapshot",
				boiler.call("maintenance_snapshot"))
		_act(boiler, "open_door")
		await _snap("04_boiler_open_with_key")
		_act(boiler, "turn_crank")
		await _snap("05_boiler_marked")
		_aim(PLANT_EYE, PLANT_AIM, PLANT_FOV)
		await _snap("06_plant_marked")
	if part == "a":
		_finish()
		return

	# --- THE LOBBY BOARD ----------------------------------------------------
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)
	await _snap("07_board_control_a")
	await _snap("07_board_control_b")

	# STATION 1 ALONE. One window fills; the other stays empty and says
	# nothing at all.
	_act(guard, "take_key")
	_work(boiler)
	await _snap("08_board_station_1_only")

	# AND THEN STATION 2. Both windows, counter at two.
	_work(landing)
	await _snap("09_board_both_stations")

	# THE OTHER ORDER, from a clean line: same two indications.
	_reset_line()
	_work(landing)
	await _snap("10_board_station_2_first")
	_work(boiler)
	await _snap("11_board_both_other_order")

	# OPEN LINE: both locals fall, the board hears neither.
	_reset_line()
	_act(net, "set_line_closed", false)
	_work(boiler)
	_work(landing)
	await _snap("12_board_open_line_neither")

	Engine.time_scale = 1.0
	print("[PAIR SHOT] part '%s' frames saved to %s" % [part, out_dir])
	print("[PAIR SHOT] delivered=%d shutters=%d counter=%d"
			% [net.call("delivered_count"), board.call("indication_count"),
					board.get("signals_taken")])
	get_tree().quit(0)


func _work(box: Node) -> void:
	_act(box, "open_door")
	_act(box, "turn_crank")


func _reset_line() -> void:
	Engine.time_scale = 1.0
	for box in [boiler, landing]:
		box.call("restore_maintenance_snapshot",
				{"door_open": false, "drop_fallen": false, "marks": 0,
						"last_record": {}})
	board.call("restore_maintenance_snapshot",
			{"line_closed": true, "dropped": [], "signals_taken": 0,
					"last_indication": {}})
	net.call("clear_marks")
	Engine.time_scale = 0.0


## One action on a frozen instrument, with its balk cleared so each refusal
## frame shows its OWN refusal.
func _act(target: Node, method: String, argument: Variant = null) -> void:
	Engine.time_scale = 1.0
	target.set("_balk_left", 0.0)
	target.set("_balk_focus", "")
	if argument == null:
		target.call(method)
	else:
		target.call(method, argument)
	Engine.time_scale = 0.0


## The boiler box, close, framed on its own case rather than on authored
## coordinates -- the lesson SR7-H's card and SR7-L's hook both paid for.
func _aim_boiler() -> void:
	var case_node := (boiler as Node3D).find_child("StationCase", true,
			false) as Node3D
	if case_node == null:
		return
	var at := case_node.global_position
	player.global_position = at + BOILER_OFFSET - player.camera.position
	player.camera.fov = BOILER_FOV
	player.camera.look_at(at, Vector3.UP)
	player.camera.make_current()


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
		push_error("[PAIR SHOT] capture failed: %s" % label)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[PAIR SHOT] part '%s' frames saved to %s" % [part, out_dir])
	get_tree().quit(0)


## Sweeps production's debug overlays. THE APPARATUS IS EXEMPT: its plates and
## numbers are Label3D, and hiding every Label3D would blank the lettering the
## sheet exists to photograph.
func _hide_ui(node: Node) -> void:
	if node == boiler or node == landing or node == board or node == guard:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
