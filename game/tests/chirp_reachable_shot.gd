extends Node
## K2-G proof sheet — the apartment is not the fault.
##
##     pwsh -NoProfile -File tools/run_godot_capture.ps1 `
##         -Scene res://tests/ChirpReachableShot.tscn `
##         -ProjectPath <worktree>/game `
##         -ShotRoot <worktree>/art/renders/first_minute_k2g `
##         -RunName production_04 -ExpectedFrames 11 -TimeoutSeconds 60 `
##         -Resolution 1280x720
##
## CAMERA CLASS: playable. Every station is the production player's own camera,
## so body, eye, carried service set and streaming origin agree with the frame.
##
## WHAT THIS SHEET CAN AND CANNOT PRICE. K2-G's change is acoustic and
## temporal: an interval, not a pixel. There is no honest way to photograph a
## schedule. So exactly ONE visual A/B claim is made here — the grille, which is
## the physical outcome of working the correct target — and everything else is
## declared context with no floor borrowed from anywhere.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const TAG := "CHIRP REACHABLE SHOT"
const EXPECTED_FRAMES := 11
const EYE := 1.41

var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController
var point: Node3D


func _ready() -> void:
	if not shots.setup(self, TAG, EXPECTED_FRAMES):
		get_tree().quit(2)
		return
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	if not await shots.settle(1.8, "production_ready"):
		get_tree().quit(2)
		return

	# Fail every missing owner BEFORE spending anything on settling or framing.
	player = root.get("player") as PlayerController
	var director: Node = root.get("first_shift_director")
	var orders: Node = root.get("work_orders")
	var hunt: Node = root.get("chirp_hunt")
	var net: Node = root.get("vantry_points")
	var tracker: CanvasLayer = root.get("objective_tracker") as CanvasLayer
	var door: Node3D = root.find_child("F02_DOOR_02", true, false) as Node3D
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	point = net.get("active_owner") as Node3D if net else null
	var camera: Camera3D = player.camera if player else null
	for row in [["player", player], ["camera", camera], ["vantry network", net],
			["active vantry point", point], ["chirp hunt", hunt],
			["work orders", orders], ["first shift director", director],
			["objective tracker", tracker], ["2A door", door],
			["watchman detector", detector], ["night register", register]]:
		if row[1] == null:
			_abort("required owner missing: %s" % row[0])
			return
	shots.checkpoint("owners_resolved")

	director.call("begin_first_shift")
	detector.call("interact_control", "detector", player)
	register.call("take_slip")
	door.call("interact", player)
	if not await shots.settle(1.0, "door_swung"):
		get_tree().quit(2)
		return

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	_look([-5.60, -1.62, 4.61], point.global_position, 78.0)
	if not await shots.settle(1.6, "lamp_and_camera_settled"):
		get_tree().quit(2)
		return
	player.set_process(false)
	Engine.time_scale = 0.0

	# Hide the two owners that animate on their own clock, by name, and sweep
	# every other CanvasLayer OUTSIDE the player. The player's own layers carry
	# the carried service set and the interaction prompt, which a playable
	# camera may not quietly put down. (K2-F learned this the expensive way.)
	tracker.visible = false
	if player.telegram_hud != null:
		player.telegram_hud.dismiss()
		player.telegram_hud.visible = false
	_hide_overlays_outside_the_player(get_tree().root)
	shots.checkpoint("overlays_hidden")

	# --- STATION 1: THE THRESHOLD. A/A, then context. -----------------------
	if not await shots.capture("00_threshold_control_a"):
		_abort_late()
		return
	if not await shots.capture("00_threshold_control_b"):
		_abort_late()
		return
	# The control pair above is already the threshold view at 78 degrees, so a
	# third frame of the same station and state would be padding, not evidence.
	# This one widens to 100 degrees: what a player actually takes in on the
	# doorstep, peripheral vision included, ceiling and all. Context only.
	_look([-5.60, -1.62, 4.61], point.global_position, 100.0)
	if not await shots.capture("01_the_room_from_the_threshold"):
		_abort_late()
		return

	# --- STATION 2: A PLAUSIBLE WRONG TARGET. Context only. -----------------
	# The intercom is the most defensible wrong answer in the room: a signal
	# head, in reach, belonging to Mina. It is silent, and the live suite
	# asserts that rather than this photograph.
	var decoy: Node3D = root.find_child("DomesticAnomaly_mina_intercom", true,
			false) as Node3D
	if decoy == null:
		decoy = root.find_child("CAPTION_CALIBRATOR", true, false) as Node3D
	if decoy != null:
		_look([-7.30, -2.30, 4.61], decoy.global_position, 70.0)
	if not await shots.capture("02_a_plausible_wrong_station"):
		_abort_late()
		return

	# --- STATION 3: UNDER THE POINT. A/A, then the one A/B claim. -----------
	# 38 degrees, not 66. At 66 the grille is a 52 x 54 px object washed by the
	# ceiling lamp behind it; the claim is a 0.05 m drop and it has to be legible
	# to a human, not only to a difference metric. The station is unchanged: the
	# body still stands where the live suite proved the grille is in reach.
	_look([-8.25, -3.04, 4.61], point.global_position, 38.0)
	if not await shots.capture("03_point_control_a"):
		_abort_late()
		return
	if not await shots.capture("03_point_control_b"):
		_abort_late()
		return
	# The single declared state change in this sheet, through the prop's own
	# service mechanism. Zero-second, because a tween cannot run frozen.
	point.call("set_grille_open", 0.0, 0.0)
	if not await shots.capture("04_the_grille_closed"):
		_abort_late()
		return
	point.call("set_grille_open", 1.0, 0.0)
	if not await shots.capture("05_the_grille_open"):
		_abort_late()
		return

	# --- CONTEXT: WHY THE ROOM HAS TO BE CROSSED ---------------------------
	point.call("set_grille_open", 0.0, 0.0)
	_look([-5.80, -1.62, 4.61], point.global_position, 66.0)
	if not await shots.capture("06_the_point_from_the_threshold"):
		_abort_late()
		return

	# --- CONTEXT: THE DOOR-TO-TARGET LINE, WIDE ----------------------------
	_look([-4.20, -1.62, 4.61], GameBoot.b2g([-8.20, -2.60, 4.30]), 92.0)
	if not await shots.capture("07_the_door_to_target_line"):
		_abort_late()
		return

	# --- CONTEXT: THE ROOM IS ORDINARY -------------------------------------
	_look([-7.60, -2.20, 4.61], GameBoot.b2g([-10.40, -4.20, 4.10]), 80.0)
	if not await shots.capture("08_an_ordinary_flat"):
		_abort_late()
		return

	Engine.time_scale = 1.0
	get_tree().quit(0 if shots.finish() else 2)


func _abort(message: String) -> void:
	push_error("[%s CAPTURE FAIL] %s" % [TAG, message])
	print("[%s CAPTURE FAIL] %s" % [TAG, message])
	print("[%s] RESULT: FAIL captures=%d expected=%d" % [
			TAG, shots.captures.size(), EXPECTED_FRAMES])
	Engine.time_scale = 1.0
	get_tree().quit(2)


func _abort_late() -> void:
	Engine.time_scale = 1.0
	shots.finish()
	get_tree().quit(2)


func _hide_overlays_outside_the_player(node: Node) -> void:
	if node == player:
		return
	if node is CanvasLayer and (node as CanvasLayer).visible:
		(node as CanvasLayer).visible = false
		print("[%s] hid overlay %s" % [TAG, node.name])
	for child in node.get_children():
		_hide_overlays_outside_the_player(child)


func _look(from: Array, at: Vector3, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(at, Vector3.UP)
	player.camera.make_current()
