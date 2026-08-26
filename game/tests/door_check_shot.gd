extends Node
## SR7-Q proof sheet — the door check on ROOF_DOOR_01, photographed in the
## production building through the player's own camera.
##
##     $env:SHOT_DIR="<abs>"; $env:SHOT_PART="a"
##     tools/run_godot_serial.ps1 -Scene res://tests/DoorCheckShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## Split into parts because a full sheet does not fit the 60-second ceiling.
## Each part carries its OWN A/A control pair, so every part can be checked for
## a floor of its own rather than borrowing another part's.
##
## THE FREEZE ORDER, which is the harness lesson this lane paid for already:
## physics off, aim, lamp off, wait 1.6 s of real time, process off, time scale
## to zero. `create_timer(t, true, false, true)` then waits REAL seconds while
## everything else is stopped.
##
## AND THE ONE ADDITION SR7-Q NEEDS. A leaf moves by tween, and a tween does
## not tick at time scale zero. Every leaf change here THAWS, waits out
## `DoorProp`'s own half second, and freezes again — so what is photographed is
## a settled leaf and never a leaf caught halfway.

var root: Node3D
var player: PlayerController
var door: Node3D
var closer: Node
var out_dir := ""
var part := "a"

## The head of the door, from the stair landing. Fixed for every apparatus
## frame on the sheet so the numbers below compare like with like.
##
## AND WHY EVERY ONE OF THOSE FRAMES HAS THE LEAF STANDING OPEN. The head of
## this door is a shadowed reveal: five probe passes -- 03:00 house light,
## 13:10 daylight, the player's lamp, from below, from the side -- all came
## back with the apparatus reading as dark iron on a black leaf. With the leaf
## OPEN it stands against the sky and every part of it is legible. That is not
## a trick to flatter the sheet; it is the state the whole thesis is about,
## because a door check is only interesting while a door is open. The one frame
## that wants a shut leaf is the last one, where the shut leaf IS the evidence.
const HEAD_AT := [-0.97, -3.15, 21.14]
const HEAD_FROM := [-0.42, -2.20, 20.86]
const HEAD_FOV := 46.0
## The regulating screw alone, for the one change too small to read at the head.
const VALVE_AT := [-0.907, -3.15, 21.16]
const VALVE_FROM := [-0.62, -2.62, 21.05]
const VALVE_FOV := 26.0
## The bulkhead wall: the door, its closer, and SR7-P's roof board together.
const WALL_AT := [-2.00, -3.10, 20.50]
const WALL_FROM := [-1.80, -0.55, 20.80]
const WALL_FOV := 68.0


func _ready() -> void:
	# THE LIGHT IS DECLARED, NOT INHERITED. `DAYNIGHT=0` parks the house clock
	# at 03:00, and the first probe came back a black doorway in the rain --
	# this apparatus is on the ROOF, where 03:00 means no light at all. The
	# sheet is shot at a forced 13:10 with rain and mist off and the weather
	# seed pinned, so every frame below is the same daylight and the A/A pairs
	# have something to be a floor of. All four are named in the README.
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("DAYNIGHT_FORCE", "13:10")
	OS.set_environment("WEATHER_RAIN", "0")
	OS.set_environment("WEATHER_MIST", "0")
	OS.set_environment("WEATHER_SEED", "7")
	RealityState.persistence_enabled = false
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://sr7q_shot"
	part = OS.get_environment("SHOT_PART")
	if part.is_empty():
		part = "a"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	door = root.find_child("ROOF_DOOR_01", true, false) as Node3D
	closer = root.find_child("ROOF_DOOR_CHECK", true, false)
	if player == null or door == null or closer == null:
		printerr("[SR7Q SHOT] missing player/door/closer")
		get_tree().quit(1)
		return

	_hide_ui(get_tree().root)
	player.set_physics_process(false)
	_look(HEAD_AT, HEAD_FROM, HEAD_FOV)
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	player.set_process(false)
	Engine.time_scale = 0.0

	match part:
		"a":
			await _part_a()
		"b":
			await _part_b()
		_:
			await _part_probe()
	Engine.time_scale = 1.0
	print("[SR7Q SHOT] part %s written to %s" % [part, out_dir])
	get_tree().quit(0)


# --- part A: the fault, and the two hands that clear it ----------------------

func _part_a() -> void:
	# The leaf is put where a leaf spends its interesting life. This is the
	# only motion in part A that is not the apparatus's own.
	await _swing(true)

	# A/A: the same frame twice with nothing touched between them. Anything
	# above zero here is the harness breathing, and every number below is only
	# worth what this one is. These two ARE the as-found frames -- the sheet
	# does not stage a separate copy of a frame it already has.
	await _snap("00_as_found_control_a")
	await _snap("00_as_found_control_b")

	# The hold-open catch, thrown so the arm can be worked without the spring
	# in a man's hands.
	closer.call("hold_leaf")
	await _snap("01_catch_thrown")

	# The arm shipped back onto its spindle. THIS IS THE WHOLE REPAIR, and it
	# is a different photograph of the same iron.
	closer.call("read_arm")
	closer.call("ship_arm")
	await _snap("02_arm_shipped")
	closer.call("release_leaf")
	await _snap("03_catch_off")

	# The regulating screw, home and then backed out. Too small to read at the
	# head, so it gets its own crop and its own A/A pair.
	_look(VALVE_AT, VALVE_FROM, VALVE_FOV)
	await _snap("04_valve_control_a")
	await _snap("04_valve_control_b")
	while not bool(closer.call("metered")):
		closer.call("turn_check")
	_calm()
	await _snap("05_port_open")

	# The wall this stands on: SR7-P's roof board and this door together.
	_look(WALL_AT, WALL_FROM, WALL_FOV)
	await _snap("06_bulkhead_wall")


# --- part B: the refusals, and what letting go actually proves ---------------

func _part_b() -> void:
	await _swing(true)
	await _snap("10_control_a")
	await _snap("10_control_b")

	# Five refusals, five different photographs. Each is snapped and then
	# calmed, because a pose left standing bleeds into the next frame -- the
	# mistake SR7-N paid for and this harness does not repeat.
	for row in [["11_refuse_arm", "arm"], ["12_refuse_valve", "valve"],
			["13_refuse_hold", "hold"], ["14_refuse_leaf", "leaf"],
			["15_refuse_lock", "lock"]]:
		closer.call("_balk", 3.0, str(row[1]))
		await _snap(str(row[0]))
		_calm()
	await _snap("16_calm")

	# STOPPED SHORT. Arm shipped, port screwed home: the closer is asked to
	# prove a close and does not request one, because it cannot deliver one.
	# The leaf is photographed exactly where it was left.
	closer.call("read_arm")
	closer.call("hold_leaf")
	closer.call("ship_arm")
	closer.call("release_leaf")
	closer.call("prove_close")
	await _snap("17_stopped_short")
	_calm()

	# THE PORT OPEN, AND THE LEAF LET GO. This is the only frame on the sheet
	# where a door closes without a hand on it.
	while not bool(closer.call("metered")):
		closer.call("turn_check")
	_calm()
	await _snap("18_ready_and_open")
	await _thaw()
	closer.call("prove_close")
	await get_tree().create_timer(0.7).timeout
	_freeze()
	await _snap("19_came_home")


# --- probe: candidate cameras, never committed -------------------------------

func _part_probe() -> void:
	await _swing(true)
	_look(HEAD_AT, HEAD_FROM, HEAD_FOV)
	await _snap("probe_as_found")
	closer.call("read_arm")
	closer.call("hold_leaf")
	closer.call("ship_arm")
	closer.call("release_leaf")
	await _snap("probe_shipped")
	_look(VALVE_AT, VALVE_FROM, VALVE_FOV)
	await _snap("probe_valve")
	_look(WALL_AT, WALL_FROM, WALL_FOV)
	await _snap("probe_wall")


# --- harness -----------------------------------------------------------------

## A leaf moves by tween and a tween does not tick frozen. Thaw, let `DoorProp`
## finish its own half second, freeze again.
func _swing(want_open: bool) -> void:
	if bool(door.get("open")) == want_open:
		return
	await _thaw()
	door.call("npc_set_open", want_open)
	await get_tree().create_timer(0.7).timeout
	_freeze()


func _thaw() -> void:
	Engine.time_scale = 1.0
	await get_tree().process_frame


func _freeze() -> void:
	Engine.time_scale = 0.0


## Clear the refusal and put every rest pose back. Without this the previous
## refusal is still on the iron when the next frame is taken.
func _calm() -> void:
	closer.set("_balk_left", 0.0)
	closer.set("_balk_focus", "")
	closer.call("_refresh_closer")


func _look(at: Array, from: Array, fov: float) -> void:
	var target := GameBoot.b2g(at)
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(target, Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.35, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))


## The apparatus's own lettering is part of the apparatus and stays visible;
## the player's HUD does not.
func _hide_ui(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	elif node is Label3D and not _is_apparatus(node):
		node.visible = false
	for child in node.get_children():
		_hide_ui(child)


func _is_apparatus(node: Node) -> bool:
	var walk: Node = node
	while walk != null:
		if str(walk.name) == "ROOF_DOOR_CHECK":
			return true
		walk = walk.get_parent()
	return false
