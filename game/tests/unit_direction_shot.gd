extends Node
## K2-F proof sheet — which way the apartments lie, from the real F02 arrival.
##
##     pwsh -NoProfile -File tools/run_godot_capture.ps1 `
##         -Scene res://tests/UnitDirectionShot.tscn `
##         -ProjectPath <worktree>/game `
##         -ShotRoot <worktree>/art/renders/first_minute_k2f `
##         -RunName production_01 -ExpectedFrames 11 -TimeoutSeconds 60 `
##         -Resolution 1280x720
##
## Migrated onto ShotHarness per game/docs/CAPTURE_EVIDENCE_PROTOCOL.md. The
## harness owns SHOT_DIR validation, save_png checking, the frame-count
## assertion, the receipt and the RESULT line; this file owns the world.
##
## CAMERA CLASS: playable. Every camera is the production player's own, so the
## body, the eye, the carried detector and the streaming origin all agree with
## what is framed. Resolution 1280x720, lamp off, DAYNIGHT=0, fresh campaign.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const TAG := "UNIT DIRECTION SHOT"
const EXPECTED_FRAMES := 11

var shots = ShotHarnessScript.new()
var root: Node3D
var player: PlayerController
var plate: Node3D

## WHERE THE PLATE IS ACTUALLY READ. The arrival itself, b(2.50, -2.26), sees
## the plate at about 65 degrees off its normal — 0.62 m of brass foreshortened
## to 0.26 m at 2.94 m, which is why an earlier pass photographed a landing with
## no legible sign in it. A player crossing the landing toward the west corridor
## passes square in front of it; this is that spot, 1.35 m out, and it is on the
## walk rather than staged for the lens.
const ARRIVAL_FROM := [-0.20, -3.25, 4.61]
const ARRIVAL_AT := [-0.35, -1.95, 4.15]
## THE CUE AND ITS DESTINATION IN ONE FRAME. The plate faces due south and the
## corridor it points down runs due west, so no camera holds both square-on.
## This is the reading position with the head turned 38 degrees left — the turn
## the legend itself asks for. The plate sits 31 degrees right of the axis, the
## west corridor mouth 37 degrees left of it, and an 88 degree frustum holds
## both. CONTEXT ONLY: there is no state change on this camera, so it carries
## no A/B claim.
const WEST_FROM := [-0.20, -3.25, 4.61]
const WEST_AT := [-2.72, 0.00, 4.30]
## The 2A door, framed with its own brass number — which hangs 1.04 m north of
## the leaf, so a camera at 1.4 m had the number off frame and photographed an
## anonymous dark door. x -3.20 is inside the pier between the stair hall and
## the corridor and photographs solid black; -3.90 is the first open station.
const DOOR_FROM := [-3.90, -2.14, 4.61]
const DOOR_AT := [-5.33, -1.45, 4.45]
## Floor four, where the same plate reads differently because the floor does.
## The same reading position as the F02 frame, 6.40 m higher.
const F04_FROM := [-0.20, -3.25, 11.01]
const F04_AT := [-0.35, -1.95, 10.55]
## An ordinary later shift.
const LATER_FROM := [0.90, -3.20, 4.61]
const LATER_AT := [-2.60, -2.20, 4.30]


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

	# RESOLVE AND VALIDATE EVERY OWNER BEFORE SPENDING ANOTHER SECOND. An absent
	# owner used to surface as a null call after the expensive boot, which reads
	# in the log like a capture failure and is not one.
	player = root.get("player") as PlayerController
	plate = root.find_child("LandingPlate_F02", true, false) as Node3D
	var director: Node = root.get("first_shift_director")
	var orders: Node = root.get("work_orders")
	var tracker: CanvasLayer = root.get("objective_tracker") as CanvasLayer
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	var camera: Camera3D = player.camera if player != null else null
	for row in [["player", player], ["camera", camera], ["landing plate", plate],
			["first shift director", director], ["work orders", orders],
			["objective tracker", tracker], ["watchman detector", detector],
			["night register", register]]:
		if row[1] == null:
			_abort("required owner missing: %s" % row[0])
			return
	shots.checkpoint("owners_resolved")

	# Drive the opening with its real owners, so the world is the one a player
	# would be standing in rather than a posed approximation.
	director.call("begin_first_shift")
	detector.call("interact_control", "detector", player)
	register.call("take_slip")

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	_look(ARRIVAL_FROM, ARRIVAL_AT, 74.0)
	# The lamp cross-fade is a real visual settle, not a HUD wait.
	if not await shots.settle(1.6, "lamp_and_camera_settled"):
		get_tree().quit(2)
		return
	player.set_process(false)
	Engine.time_scale = 0.0

	# HIDE THE PRESENTATION OWNERS EXPLICITLY.
	#
	# This sheet used to buy a quiet HUD with an eight-second real-time wait,
	# which measures elapsed time instead of naming the thing that moves. Two
	# owners animate over a frozen world: ObjectiveTracker's card, and the
	# player's TelegramHud toast whose tween was mid-fade when the world
	# stopped. Both are switched off by name, and then every remaining
	# CanvasLayer in the tree is swept, so nothing time-dependent can leak into
	# an evidence frame. This takes the literal wait budget from 14.7 s to 3.4 s.
	#
	# The work-order card is therefore ABSENT from these frames by choice. That
	# the order names unit 2A is asserted in UnitDirectionLiveTest, where it is
	# a string comparison rather than something read off a photograph.
	tracker.visible = false
	if player.telegram_hud != null:
		player.telegram_hud.dismiss()
		player.telegram_hud.visible = false
	_hide_overlays_outside_the_player(get_tree().root)
	shots.checkpoint("overlays_hidden")

	# --- ARRIVAL CAMERA: the only station carrying a quantitative claim -------
	# Local A/A, then exactly one declared state change, then a trailing control
	# so the floor BRACKETS the priced pair instead of merely preceding it.
	if not await shots.capture("00_arrival_control_a"):
		_abort_late()
		return
	if not await shots.capture("00_arrival_control_b"):
		_abort_late()
		return
	_set_units(false)
	if not await shots.capture("01_arrival_before"):
		_abort_late()
		return
	_set_units(true)
	if not await shots.capture("02_arrival_after"):
		_abort_late()
		return
	if not await shots.capture("02_arrival_control_c"):
		_abort_late()
		return

	# --- CORRIDOR CAMERA: local A/A, then one context frame ------------------
	# No state change on this station. 04 is placement evidence, NOT a claim;
	# the pair exists to show the station is reproducible, so that the single
	# context frame can be trusted as a frame.
	_look(WEST_FROM, WEST_AT, 88.0)
	if not await shots.capture("03_corridor_control_a"):
		_abort_late()
		return
	if not await shots.capture("03_corridor_control_b"):
		_abort_late()
		return
	if not await shots.capture("04_the_way_the_glyph_points"):
		_abort_late()
		return

	# --- THREE CONTEXT STATIONS, EACH WITH NO FLOOR OF ITS OWN ---------------
	# Attractive production-placement evidence and nothing more. They must NOT
	# borrow the arrival or corridor temporal floors, so no RMSE is reported
	# against them anywhere in this sheet.
	_look(DOOR_FROM, DOOR_AT, 75.0)
	if not await shots.capture("05_the_2a_door"):
		_abort_late()
		return
	_look(F04_FROM, F04_AT, 74.0)
	if not await shots.capture("06_floor_four_reads_its_own_floor"):
		_abort_late()
		return
	_look(LATER_FROM, LATER_AT, 72.0)
	if not await shots.capture("07_a_later_shift"):
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


## A capture refused mid-sequence has already logged its own reason; finish()
## records the short count and prints the single RESULT line.
func _abort_late() -> void:
	Engine.time_scale = 1.0
	shots.finish()
	get_tree().quit(2)


## Every remaining CanvasLayer EXCEPT the ones the player carries. Printed, so
## the handoff can say exactly what was suppressed rather than "the HUD".
##
## THE FIRST VERSION OF THIS SWEPT EVERYTHING, AND THAT WAS WRONG. The carried
## service set is composited through a CanvasLayer of its own
## (service_set_carrier.gd builds a SubViewport and a layer to show it), so a
## blanket sweep deleted the device out of the player's hands in all eleven
## frames. It made frame 04 look better -- the detector stopped occluding the
## plate's left label -- which is exactly why it had to go. This is a playable
## camera; the body, the eye and what the hands are holding have to agree with
## the frame, and an evidence sheet may not quietly put the lamp down.
##
## So: everything under the player is first-person presentation and is left
## alone. The two owners that actually animate on their own clock are hidden
## above, by name, and one of them (TelegramHud) is itself a child of the
## player -- which is why naming them is the load-bearing step and this sweep is
## only a backstop for overlays elsewhere in the tree.
func _hide_overlays_outside_the_player(node: Node) -> void:
	if node == player:
		return
	if node is CanvasLayer and (node as CanvasLayer).visible:
		(node as CanvasLayer).visible = false
		print("[%s] hid overlay %s (%s)" % [TAG, node.name, node.get_class()])
	for child in node.get_children():
		_hide_overlays_outside_the_player(child)


## Hide or show only the two units labels, leaving K2-E's plate intact. This is
## the single declared state change in the whole sheet.
func _set_units(on: bool) -> void:
	_walk_labels(plate, on)


func _walk_labels(node: Node, on: bool) -> void:
	if node is Label3D:
		var t := str((node as Label3D).text)
		if t.contains("←") or t.contains("→"):
			(node as Label3D).visible = on
	for child in node.get_children():
		_walk_labels(child, on)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()
