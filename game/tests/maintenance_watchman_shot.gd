extends Node
## SR7-F proof sheet: the watchman's time detector in the Orison lobby.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/MaintenanceWatchmanShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, on the F01 east wall
## in the clear run between the two entry doors, shot through the
## player's own camera and lit by the lobby's own fixtures. No proof-only
## light, mesh, material, camera rig or production owner.
##
## THE PICTURE THIS SHEET HAS TO MAKE WITHOUT A CAPTION: a dial covered in
## marks that all lie on ONE STRAIGHT LINE out from the centre, against two
## marks with daylight between them. The first is a whole night recorded at a
## single instant, which is impossible. The second is the only thing that
## proves the paper moved.
##
## One frozen A/A pair prices the close camera. An abort frame is priced
## against that same control, which is how reversibility is shown rather than
## asserted.

var root: Node3D
var player: PlayerController
var det: Node
var out_dir := ""

## Building coordinates. The detector hangs at (5.24, -1.50, 1.44) facing west
## into the lobby -- above the dado cap, which is why it is at that height --
## and its dial centre stands about 0.11 m proud of the wall at z 1.66.
## The close eye is 0.60 m off the dial, which is the whole case plus
## a margin -- any nearer and the stop lever and the station key, which are the
## two things that visibly refuse, fall out of frame.
const DIAL_EYE := [4.53, -1.50, 1.66]
const DIAL_AIM := [5.13, -1.50, 1.66]
const DIAL_FOV := 42.0
const LOBBY_EYE := [3.40, -3.10, 1.62]
const LOBBY_AIM := [5.15, -1.56, 1.58]
const LOBBY_FOV := 62.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_watchman_sr7f"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	_hide_ui(get_tree().root)

	det = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	player = root.get("player") as PlayerController
	if det == null or player == null:
		push_error("[WATCHMAN SHOT] no production detector or player")
		get_tree().quit(1)
		return

	# The body is stopped FIRST and the camera set afterwards. `_aim` moves the
	# player root and the camera rides on it, so a rig placed while physics is
	# still running settles a few centimetres before the first exposure and
	# every frame comes back framed on something other than the dial. The
	# player's own `_process` stays alive a while longer, because the lamp
	# needs it.
	player.set_physics_process(false)
	_aim(DIAL_EYE, DIAL_AIM, DIAL_FOV)
	await get_tree().create_timer(0.8).timeout

	# THE SERVICE LAMP, TESTED RATHER THAN ASSUMED. SR7-D and SR7-E found the
	# torch projecting a Dream plate onto the waking building, and `e1314f0`
	# claims to have fixed the cookie bake. This paired capture is the check:
	# if the two frames differ only in brightness the lamp is clean and the
	# sheet can use it; if a mural appears it goes back off and is reported.
	#
	# BOTH DIAGNOSTICS ARE TAKEN WITH THE WORLD STILL RUNNING, and that is the
	# whole point of the ordering. `set_lamp_enabled` does not snap: it starts
	# a gutter transient that `_process` has to finish. Freeze the player first
	# and the lamp stops half-lit, welded to the camera, and throws a hot spot
	# into the lower right of every single plate on the sheet. An earlier pass
	# of this sheet was thrown away for exactly that.
	player.set_lamp_enabled(true)
	await get_tree().create_timer(1.2).timeout
	await _snap("zz_lamp_on_diagnostic")
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	await _snap("zz_lamp_off_diagnostic")
	print("[WATCHMAN SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)

	# THE WORLD STOPS HERE. The player's own process and the apparatus's balk
	# timer go still so that a refusal pose survives an exposure and an A/A
	# pair can be byte-identical.
	player.set_process(false)
	det.set_process(false)
	Engine.time_scale = 0.0

	# THE CAMERA IS SET AFTER THE BODY IS STOPPED, not before. `_aim` moves the
	# player root and the camera rides on it, so a rig placed while physics is
	# still running settles a few centimetres before the first exposure and
	# every frame comes back framed on something other than the dial.
	_aim(DIAL_EYE, DIAL_AIM, DIAL_FOV)

	# --- AS FOUND -----------------------------------------------------------
	# The movement runs, the hand sweeps, the sheet is full of marks, and the
	# dial has not turned since it was dropped on.
	await _snap("00_detector_control_a")
	await _snap("00_detector_control_b")

	_aim(LOBBY_EYE, LOBBY_AIM, LOBBY_FOV)
	await _snap("01_lobby_context")
	_aim(DIAL_EYE, DIAL_AIM, DIAL_FOV)

	# The condition the whole round has to be reversible from.
	var found: Dictionary = det.call("maintenance_snapshot")

	# --- THE RECORD, READ ---------------------------------------------------
	# The reading index sweeps last night's sheet. Six stations, one radial
	# line: a whole night at one instant.
	_step("read_the_dial", 0.58)
	await _snap("02_last_nights_record")

	# --- REFUSAL 1: the paper against a turning spindle ----------------------
	_step("seat_the_dial", 0.44)
	await _snap("03_seat_against_running_refused")

	# --- THE MOVEMENT STOPPED -----------------------------------------------
	_step("stop_the_movement", 0.0)
	await _snap("04_movement_stopped")

	# --- REFUSAL 2: a datum for a dial that is not on the spindle ------------
	_step("set_the_datum", float(det.call("correct_datum")))
	await _snap("05_datum_without_dial_refused")

	# --- THE DIAL ON ITS PIN ------------------------------------------------
	# The drive pin comes up through the index hole and stands proud of the
	# paper. That is the whole repair, and it is 4 mm of brass.
	_step("seat_the_dial", 0.44)
	await _snap("06_dial_seated_on_pin")

	# --- REFUSAL 3: the wrong hour ------------------------------------------
	# A datum a quarter-turn out would give a legible, careful, wholly false
	# account of the night.
	_step("set_the_datum", fposmod(float(det.call("correct_datum")) + 0.25, 1.0))
	await _snap("07_wrong_hour_refused")

	# --- THE DATUM AGREEING WITH THE HOUSE ----------------------------------
	_step("set_the_datum", float(det.call("correct_datum")))
	await _snap("08_datum_set_to_the_house")

	# --- REFUSAL 4: proving a round against a stopped movement --------------
	# THE FAULT ITSELF, offered as a repair. Both marks would land on the same
	# angle, which is exactly the record this round exists to throw away.
	_step("prove_the_round", 0.83)
	await _snap("09_proof_against_stopped_refused")

	# --- THE PROOF ----------------------------------------------------------
	_step("stop_the_movement", 1.0)
	await _snap("10_movement_running")
	_step("prove_the_round", 0.83)
	await _snap("11_two_marks_apart")

	# --- COMMITTED, through the guarded seam and nothing else ---------------
	Engine.time_scale = 1.0
	det.call("apply_maintenance_result", {
		"quality": "good",
		"note": "dial seated on its drive pin, datum set to the house hour and the movement proved by two separated marks",
		"mechanism_patch": {"dial_seated": true, "movement_running": true,
				"datum_set": true, "detector_honest": true},
	})
	Engine.time_scale = 0.0
	await _snap("12_committed")
	_aim(LOBBY_EYE, LOBBY_AIM, LOBBY_FOV)
	await _snap("13_lobby_after")
	_aim(DIAL_EYE, DIAL_AIM, DIAL_FOV)

	# --- ABORT, PRICED ------------------------------------------------------
	# Everything above is put back through the same snapshot the panel's abort
	# uses. This frame is measured against `00_detector_control_a`: if the
	# preview is genuinely reversible the two are the same photograph.
	Engine.time_scale = 1.0
	det.call("restore_maintenance_snapshot", found)
	Engine.time_scale = 0.0
	await _snap("14_restored_after_abort")

	Engine.time_scale = 1.0
	print("[WATCHMAN SHOT] 17 frames saved to %s" % out_dir)
	print("[WATCHMAN SHOT] honest=%s seated=%s running=%s datum_set=%s proof=%s"
			% [det.get("detector_honest"), det.get("dial_seated"),
					det.get("movement_running"), det.get("datum_set"),
					det.call("marks_prove_movement")])
	get_tree().quit(0)


## One authored step, worked on the frozen apparatus. The balk timer is cleared
## first so each refusal frame shows its OWN refusal and never an inherited
## pose -- with `_process` off to hold the world still, nothing else would
## clear it.
func _step(id: String, value: float) -> void:
	Engine.time_scale = 1.0
	det.set("_balk_left", 0.0)
	det.call("preview_maintenance_step", {"id": id}, value)
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
		push_error("[WATCHMAN SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
