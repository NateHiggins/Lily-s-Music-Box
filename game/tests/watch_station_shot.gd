extends Node
## SR7-J proof sheet: the first watch station, on the way to 2A.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/WatchStationShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, on the F02 corridor's
## west wall between the lift and 2A's door, shot through the player's own
## camera and lit by the corridor's own fixtures. No proof-only light, mesh,
## material, camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * The box is a thing you walk past, not a waypoint: the approach frame is
##     taken from standing height in the middle of the corridor, and it has to
##     read as furniture that happens to be legible.
##   * A Gamewell door is SHUT or OPEN. There is no third picture.
##   * The drop is up or fallen, and fallen is the whole local record.
##   * The refusal moves the crank against its pawl and moves nothing else.

var root: Node3D
var player: PlayerController
var box: Node
var out_dir := ""

## Building coordinates. The case hangs at (-5.33, -3.10, 4.62) facing east
## into the corridor; F02's floor is at z 3.2.
## Standing in the corridor's WEST leg, south of the box, looking north the
## way the walk actually comes: the lift lands south-east, the round crosses
## the south leg and turns up this wall to 2A's door. An earlier rig stood in
## the south leg and sighted straight through the atrium's corner, which is a
## wall -- the frame came back as empty plaster.
const APPROACH_EYE := [-4.28, -4.85, 4.80]
const APPROACH_AIM := [-5.18, -3.15, 4.74]
const APPROACH_FOV := 64.0
const BOX_EYE := [-4.58, -3.09, 4.86]
const BOX_AIM := [-5.22, -3.10, 4.77]
const BOX_FOV := 40.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://watch_station_sr7j"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	box = root.find_child("F02_WATCH_STATION_01", true, false)
	player = root.get("player") as PlayerController
	if box == null or player == null:
		push_error("[STATION SHOT] no production station or player")
		get_tree().quit(1)
		return
	# The station's legend is Label3D -- the established Orison prop lettering
	# idiom. The overlay sweep must not take the apparatus's own printing.
	_hide_ui(get_tree().root)

	# Body first, camera after, lamp settled before `_process` stops: a rig
	# placed while physics runs drifts, and `set_lamp_enabled` starts a gutter
	# transient that freezing early welds half-lit to the camera.
	player.set_physics_process(false)
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[STATION SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	box.set_process(false)
	Engine.time_scale = 0.0
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)

	# --- AS FOUND -----------------------------------------------------------
	await _snap("00_station_control_a")
	await _snap("00_station_control_b")

	# THE APPROACH. Standing in the corridor where the walk actually comes
	# from: the box on the left, 2A's door beyond it. This frame is the whole
	# "discoverable without being a waypoint" claim.
	_aim(APPROACH_EYE, APPROACH_AIM, APPROACH_FOV)
	await _snap("01_approach_control_a")
	await _snap("01_approach_control_b")
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)

	# --- THE BOX OPENS ------------------------------------------------------
	var found: Dictionary = box.call("maintenance_snapshot")
	_act("open_door")
	await _snap("02_box_open")

	# --- THE MARK -----------------------------------------------------------
	_act("turn_crank")
	await _snap("03_marked_drop_fallen")
	_aim(APPROACH_EYE, APPROACH_AIM, APPROACH_FOV)
	await _snap("04_approach_marked")
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)

	# --- THE LOCK-OUT -------------------------------------------------------
	# The door shut itself when the wheel ran, so the box has to be opened
	# again before the crank can be refused.
	_act("open_door")
	await _snap("05_reopened_after_mark")
	_act("turn_crank")
	await _snap("06_second_crank_refused")

	# --- THE DOOR THAT WILL NOT SIT HALF-SHUT -------------------------------
	_act("close_door")
	await _snap("07_closed_after_marking")
	_act("close_door")
	await _snap("08_closing_a_shut_box_refused")

	# --- RESET, AND ABORT ---------------------------------------------------
	_act("reset_station")
	await _snap("09_drop_reset")
	Engine.time_scale = 1.0
	box.call("restore_maintenance_snapshot", found)
	Engine.time_scale = 0.0
	await _snap("10_restored_after_abort")
	_aim(APPROACH_EYE, APPROACH_AIM, APPROACH_FOV)
	await _snap("11_approach_after_abort")

	Engine.time_scale = 1.0
	print("[STATION SHOT] frames saved to %s" % out_dir)
	print("[STATION SHOT] door=%s drop=%s marks=%d"
			% [box.get("door_open"), box.get("drop_fallen"),
					box.get("marks")])
	get_tree().quit(0)


## One physical action on the frozen box. The balk is cleared first so each
## refusal frame shows its OWN refusal and never an inherited pose -- with
## `_process` off, nothing else would clear it.
func _act(method: String) -> void:
	Engine.time_scale = 1.0
	box.set("_balk_left", 0.0)
	box.set("_balk_focus", "")
	box.call(method)
	Engine.time_scale = 0.0


## `PlayerController`'s camera sits a standing eye-height above its root, so
## the root goes to the requested eye MINUS that offset.
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
		push_error("[STATION SHOT] capture failed: %s" % label)


## Sweeps production's debug overlays out of frame. THE STATION IS EXEMPT: its
## number plate is engraved with Label3D, the same lettering idiom
## `lobby_bulletin_board.gd` uses, and hiding every Label3D would blank the one
## thing that makes the box findable in passing.
func _hide_ui(node: Node) -> void:
	if node == box:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
