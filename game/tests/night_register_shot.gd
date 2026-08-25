extends Node
## SR7-G/H proof sheet: the night register at the watchman station.
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
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * A hook is never empty: it carries either its key or a numbered brass
##     check, and those two things do not look alike.
##   * The spindle is either carrying a report, standing bare, or holding the
##     torn stub of one that is in somebody's hand.
##   * SR7-H: the conclusion card is ENGRAVED, so the four things you may put
##     your name to are readable on the apparatus, and the brass index is
##     standing on exactly one of them -- or on the printed blank.
##
## The card gets its own camera. The board view proves the index MOVED; only
## the close view proves what it moved to, and a claim about wording has to be
## legible to be a claim.

var root: Node3D
var player: PlayerController
var board: Node
var out_dir := ""
## The production root costs most of the 60-second ceiling to build, so the
## sheet is taken in two passes over the same directory: SHOT_PART=a is the
## card, SHOT_PART=b is the round, the refusals and the abort. Unset takes
## both, which only fits on a machine that boots the Orison faster than this
## one does.
var part := ""

## Building coordinates. The board hangs at (5.24, -2.27, 1.42) facing west.
## The eye is 0.80 m off the face: any closer and the writing slope -- half
## the apparatus, and all of SR7-H -- falls out of frame.
const BOARD_EYE := [4.37, -2.27, 1.70]
const BOARD_AIM := [5.15, -2.27, 1.60]
const BOARD_FOV := 44.0
const STATION_EYE := [3.60, -3.70, 1.68]
const STATION_AIM := [5.15, -1.92, 1.60]
const STATION_FOV := 60.0
## The card close-up is derived from the card node's own world position rather
## than authored, so it cannot drift away from the thing it is photographing.
const CARD_OFFSET := Vector3(-0.30, 0.25, 0.0)
const CARD_FOV := 38.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	part = OS.get_environment("SHOT_PART").to_lower()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://night_register_sr7h"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	board = root.find_child("F01_NIGHT_REGISTER", true, false)
	player = root.get("player") as PlayerController
	if board == null or player == null:
		push_error("[REGISTER SHOT] no production register or player")
		get_tree().quit(1)
		return
	# The register's own engraving is Label3D, the established Orison prop
	# lettering idiom. The overlay sweep must not take the apparatus's printing
	# with it, or SR7-H photographs as a blank card.
	_hide_ui(get_tree().root)

	# The body stops FIRST and the camera is set afterwards: `_aim` moves the
	# player root and the camera rides on it, so a rig placed while physics is
	# still running settles before the first exposure. The player's own
	# `_process` stays alive a moment longer, because the lamp needs it --
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

	var plant := str(board.get("PLANT_HOOK"))
	var flat := str(board.get("APARTMENT_HOOK"))
	var outcomes: Array = board.get("OUTCOMES")

	if part != "b":
		# --- AS FOUND -------------------------------------------------------
		# Both keys on their hooks, the spike bare, and the index standing on
		# the printed blank. Nothing here has an opinion yet.
		await _snap("00_station_control_a")
		await _snap("00_station_control_b")

		_aim(STATION_EYE, STATION_AIM, STATION_FOV)
		await _snap("01_station_context")

		# --- THE FOUR CONCLUSIONS, CLOSE ------------------------------------
		# The A/A control for the card camera is taken here too, so the close
		# view has its own measured floor rather than borrowing the board's.
		_aim_card()
		await _snap("02_card_control_a")
		await _snap("02_card_control_b")
		for i in outcomes.size():
			_act("select_outcome", str(outcomes[i]))
			await _snap("%02d_card_%s" % [i + 3, str(outcomes[i])])
		_act("select_outcome", "")
		await _snap("07_card_returned_to_blank")
	if part == "a":
		_finish()
		return

	# --- A ROUND, ON THE BOARD ----------------------------------------------
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)
	Engine.time_scale = 1.0
	var wo: Node = root.get("work_orders")
	wo.call("issue_job", str(board.get("JOB_ID")), "reported")
	Engine.time_scale = 0.0
	await _snap("08_report_on_the_spindle")

	# The condition the whole round has to be reversible from.
	var found: Dictionary = board.call("maintenance_snapshot")

	_act("take_slip")
	_act("take_key", plant)
	await _snap("09_round_open")

	# --- EVERY REFUSAL -------------------------------------------------------
	# Four families, and the frame says which one by WHAT MOVED.
	_act("take_key", plant)
	await _snap("10_refused_key_already_out")
	_act("select_outcome", str(outcomes[0]))
	_act("sign_register")
	await _snap("11_refused_signing_with_keys_out")
	_act("return_key", plant)
	_act("sign_register")
	await _snap("12_refused_signing_report_in_hand")
	_act("replace_slip")
	_act("select_outcome", "")
	_act("sign_register")
	await _snap("13_refused_signing_on_the_blank")

	# --- THE ONE PUBLICATION -------------------------------------------------
	_act("select_outcome", str(outcomes[1]))
	await _snap("14_conclusion_chosen")
	_act("sign_register")
	await _snap("15_signed")
	# Idempotent: the round closed, so a second press has nothing to file.
	_act("sign_register")
	await _snap("16_refused_signing_again")

	_aim_card()
	await _snap("17_card_after_signing")

	_aim(STATION_EYE, STATION_AIM, STATION_FOV)
	await _snap("18_station_after")

	# --- ABORT, PRICED -------------------------------------------------------
	# Restored through the same snapshot the panel's abort path uses, and
	# measured against `08`: if the session is genuinely reversible -- index,
	# keys, report, round and written lines -- the two are one photograph.
	_aim(BOARD_EYE, BOARD_AIM, BOARD_FOV)
	Engine.time_scale = 1.0
	board.call("restore_maintenance_snapshot", found)
	Engine.time_scale = 0.0
	await _snap("19_restored_after_abort")

	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[REGISTER SHOT] part '%s' frames saved to %s" % [part, out_dir])
	print("[REGISTER SHOT] detent=%d outcome=%s round_open=%s signed=%d"
			% [board.get("index_detent"), board.call("selected_outcome"),
					board.get("round_open"), board.get("signed_lines")])
	get_tree().quit(0)


## One physical action on the frozen board. The balk timer is cleared first so
## each refusal frame shows its OWN refusal and never an inherited pose -- with
## `_process` off to hold the world still, nothing else would clear it.
func _act(method: String, argument := "") -> void:
	Engine.time_scale = 1.0
	board.set("_balk_left", 0.0)
	board.set("_balk_focus", "")
	if method == "select_outcome":
		board.call(method, argument)
	elif argument.is_empty():
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


## The card close-up, taken from the card's own world transform. Authoring it
## as fixed building coordinates would let the camera and the subject drift
## apart the first time the writing slope moves a centimetre.
func _aim_card() -> void:
	var card := (board as Node3D).find_child("ConclusionCard", true, false) \
			as Node3D
	if card == null:
		return
	var at := card.global_position
	player.global_position = at + CARD_OFFSET - player.camera.position
	player.camera.fov = CARD_FOV
	player.camera.look_at(at, Vector3.UP)
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


## Sweeps production's debug overlays out of frame. THE REGISTER IS EXEMPT:
## its conclusion card is engraved with Label3D, the same lettering idiom
## `lobby_bulletin_board.gd` uses for its brass plate, and hiding every Label3D
## in the tree would blank the one surface SR7-H exists to photograph.
func _hide_ui(node: Node) -> void:
	if node == board:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
