extends Node
## SR7-E proof sheet: the house panelboard in B1_ELECTRICAL.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/MaintenanceFuseShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, in the basement
## electrical room production already had, on the front plane of the baked
## cabinet `b1_panel0`. Shot through the player's own camera and lit by the
## room's own cage bulb plus the player's service lamp -- which is what a
## superintendent reads a fuse cap by. No proof-only light, mesh, material,
## camera rig or production owner.
##
## One frozen A/A pair prices the close camera, and every state claim is made
## on that camera so they are all priced against the same floor.

var root: Node3D
var player: PlayerController
var panel: Node
var out_dir := ""

## Building coordinates. The apparatus is on the cabinet face at
## (13.30, -6.80, -1.90); the room runs west of it and B1's floor is at -2.8.
## The apparatus is 0.90 m tall, from the card at the bottom to the knife
## switch at the top. At arm's length only the fuse block fits, and the switch
## -- the whole safety half of the round -- was above the frame, so the eye
## stands back about a metre and a half.
const PANEL_EYE := [11.78, -6.80, -1.26]
const PANEL_AIM := [13.20, -6.80, -1.34]
const PANEL_FOV := 42.0
const ROOM_EYE := [10.10, -8.30, -1.05]
const ROOM_AIM := [13.10, -6.55, -1.45]
const ROOM_FOV := 62.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_fuse_sr7e"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	_hide_ui(get_tree().root)

	panel = root.find_child("B1_HOUSE_PANEL", true, false)
	player = root.get("player") as PlayerController
	if panel == null or player == null:
		push_error("[FUSE SHOT] no production panel or player")
		get_tree().quit(1)
		return

	# Stand the player in the basement and let the floor-visibility gate notice
	# before anything is photographed.
	_aim(PANEL_EYE, PANEL_AIM, PANEL_FOV)
	await get_tree().create_timer(0.8).timeout
	# THE SERVICE LAMP IS DELIBERATELY OFF, and that is a finding rather than a
	# preference.
	#
	# `_bake_cookie` (player_controller.gd) assigns `flashlight.light_projector`
	# from `_mask_view.get_texture().get_image()`. The three mask plates it is
	# supposed to bake are correct, but the baked RESULT is not: the render
	# target is sampled before that SubViewport has drawn, so the cookie
	# captures whatever frame was last resident in it -- currently a Dream
	# plate -- and the torch then projects a Klimt mural onto the waking
	# building. It is visible in the SR7-B, SR7-D and SR7-E sheets, it survives
	# the retirement of `klimt_reflected_world_v1`, and a paired capture with
	# the lamp off removes it entirely.
	#
	# The room's own cage bulb lights this apparatus perfectly well without it,
	# so the sheet is shot on production fixtures alone and the defect is
	# reported instead of worked around silently. See the README.
	player.set_lamp_enabled(false)
	await get_tree().create_timer(0.5).timeout
	player.set_physics_process(false)
	player.set_process(false)
	panel.set_process(false)
	Engine.time_scale = 0.0

	# As found: a thirty in a fifteen-ampere circuit, main closed, panel live,
	# every lamp on the circuit working perfectly.
	await _snap("00_panel_control_a")
	await _snap("00_panel_control_b")

	_aim(ROOM_EYE, ROOM_AIM, ROOM_FOV)
	await _snap("01_room_context")
	_aim(PANEL_EYE, PANEL_AIM, PANEL_FOV)

	# THE FAULT, READ. The lamp index runs down to the cap and the stamped
	# rating is the only place the fault is written down.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "read_the_stamp"}, 0.63)
	Engine.time_scale = 0.0
	await _snap("02_stamp_read")

	# THE SAFETY REFUSAL. The holder is at line potential whatever the lamps
	# are doing, and the plug will not come out under the main.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "draw_the_plug"}, 0.55)
	Engine.time_scale = 0.0
	await _snap("03_live_draw_refused")

	# THE MAIN OPEN. Blades standing clear of their jaws: a knife switch shows
	# you it is dead, which is the whole reason it is shaped this way.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "pull_the_main"}, 0.0)
	Engine.time_scale = 0.0
	await _snap("04_main_open")

	# The plug backed out, its link whole. It never blew because it never could.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "draw_the_plug"}, 0.55)
	Engine.time_scale = 0.0
	await _snap("05_plug_out")

	# THE FAULT OFFERED AS A REPAIR, AND REFUSED. Another thirty fits the hole
	# perfectly; the apparatus will not hand it back.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "match_the_wire"}, 0.90)
	Engine.time_scale = 0.0
	await _snap("06_bigger_plug_refused")

	# The fifteen seated: the stamp goes quiet.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "match_the_wire"}, 0.34)
	Engine.time_scale = 0.0
	await _snap("07_fifteen_seated")

	# Proved under load, with the main closed again.
	Engine.time_scale = 1.0
	panel.call("preview_maintenance_step", {"id": "prove_under_load"}, 0.88)
	Engine.time_scale = 0.0
	await _snap("08_proved_under_load")

	# COMMITTED, through the guarded seam and nothing else.
	Engine.time_scale = 1.0
	panel.call("apply_maintenance_result", {
		"quality": "good",
		"note": "over-fused plug replaced with one rated to the conductor and proved under full load",
		"mechanism_patch": {"fitted_rating": 15, "main_open": false,
				"plug_out": false, "panel_safe": true},
	})
	Engine.time_scale = 0.0
	await _snap("09_committed")
	_aim(ROOM_EYE, ROOM_AIM, ROOM_FOV)
	await _snap("10_room_after")

	Engine.time_scale = 1.0
	print("[FUSE SHOT] 11 frames saved to %s" % out_dir)
	print("[FUSE SHOT] safe=%s over=%s fitted=%s main_open=%s"
			% [panel.get("panel_safe"), panel.call("over_fused"),
					panel.get("fitted_rating"), panel.get("main_open")])
	get_tree().quit(0)


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
		push_error("[FUSE SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
