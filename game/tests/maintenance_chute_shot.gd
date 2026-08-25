extends Node
## SR7-D proof sheet: the lobby mail chute and its choke.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/MaintenanceChuteShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, on the real lobby
## east wall, shot through the player's own camera and lit by the lobby's own
## fittings plus the player's service lamp. No proof-only light, mesh,
## material, camera rig or production owner.
##
## THE SHEET IS BUILT AROUND ONE MEASUREMENT. Frames 01 and 07 are the
## collection box choked and the collection box clear. If the apparatus is
## honest they are nearly identical, because the box cannot tell you which it
## is -- and that near-zero delta, against a byte-identical A/A floor, is the
## strongest form the claim "the empty box lies" can take. Frame 08 is the same
## box with a test piece in it, and it has to be large.

var root: Node3D
var player: PlayerController
var chute: Node3D
var out_dir := ""

## Building coordinates. The apparatus is on the east wall face at (5.24,
## -6.75); the lobby is west of it.
## Aimed slightly NORTH of the apparatus rather than square at it. Square-on,
## the frame's right-hand third catches the mail bank -- and with it a
## production artifact that has nothing to do with this apparatus: the Dream's
## `klimt_reflected_world_v1` plate is visible in the waking lobby (see the
## README). Turning a few degrees up the wall keeps the subject clean without
## moving the apparatus or touching anything that causes it.
const WORKS_EYE := [4.16, -6.62, 1.48]
const WORKS_AIM := [5.14, -6.70, 1.34]
const WORKS_FOV := 34.0
## Tight on the box mouth alone. Framed wide, this camera also saw the glass,
## the tray and the blade, so "the box choked vs the box clear" measured the
## whole apparatus instead of the one thing the claim is about.
const BOX_EYE := [4.52, -6.68, 1.06]
const BOX_AIM := [5.12, -6.73, 0.94]
const BOX_FOV := 30.0
const WIDE_EYE := [3.55, -8.30, 1.62]
const WIDE_AIM := [5.16, -6.85, 1.20]
const WIDE_FOV := 58.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_chute_sr7d"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	_hide_ui(get_tree().root)

	chute = root.find_child("LobbyMailChute", true, false) as Node3D
	player = root.get("player") as PlayerController
	if chute == null or player == null:
		push_error("[CHUTE SHOT] no production chute or player")
		get_tree().quit(1)
		return

	_aim(WORKS_EYE, WORKS_AIM, WORKS_FOV)
	await get_tree().create_timer(0.7).timeout
	player.set_lamp_enabled(true)
	# Pin the lamp gutter so its own breathing does not become the noise floor
	# the real claims then have to beat. No production default changes.
	player.pin_lamp_gutter_for_proof(1.0)
	player.set("_lamp_phase", 0.0)
	player.set("_lamp_phase_total", 0.0)
	player.call("_advance_lamp", 0.0)
	await get_tree().create_timer(0.5).timeout
	player.set_physics_process(false)
	player.set_process(false)
	chute.set_process(false)
	Engine.time_scale = 0.0

	# Both frozen controls in the as-found state: arch standing, load on it,
	# cover locked, box empty.
	await _snap("00_works_control_a")
	await _snap("00_works_control_b")
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)
	await _snap("01_box_control_a")
	await _snap("01_box_control_b")

	_aim(WIDE_EYE, WIDE_AIM, WIDE_FOV)
	await _snap("02_lobby_wall_context")

	# THE CHOKE FOUND. The lamp index runs up the three-quarters glass the 1883
	# patent put there for the purpose, and stops where the chute stops being
	# empty: two letters bearing on each other across the throat.
	_aim(WORKS_EYE, WORKS_AIM, WORKS_FOV)
	Engine.time_scale = 1.0
	chute.preview_maintenance_step({"id": "read_the_glass"}, 0.72)
	Engine.time_scale = 0.0
	await _snap("03_lamp_finds_the_arch")

	# THE DANGEROUS ORDER. Cover keyed, blade offered at the span with the whole
	# column still standing on it. The apparatus refuses and shakes.
	Engine.time_scale = 1.0
	chute.preview_maintenance_step({"id": "unlock_the_cover"}, 1.0)
	chute.preview_maintenance_step({"id": "break_the_arch"}, 0.41)
	Engine.time_scale = 0.0
	await _snap("04_avalanche_refused")

	# THE LOAD TAKEN. The glass draws in its grooves, the catch tray comes up,
	# and the loose mail comes off the arch -- which is still standing.
	Engine.time_scale = 1.0
	chute.preview_maintenance_step({"id": "take_the_load"}, 0.58)
	Engine.time_scale = 0.0
	await _snap("05_load_taken")

	# THE SPAN GOES.
	Engine.time_scale = 1.0
	chute.preview_maintenance_step({"id": "break_the_arch"}, 0.41)
	Engine.time_scale = 0.0
	await _snap("06_arch_broken")

	# THE POINT OF THE WHOLE SHEET. The chute is now clear. Photograph the box
	# from the same camera as 01, which saw it choked. If these two frames are
	# nearly identical, the box has been proved useless as evidence.
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)
	await _snap("07_box_still_empty")

	# And the only evidence there is: something arrives.
	Engine.time_scale = 1.0
	chute.preview_maintenance_step({"id": "prove_the_drop"}, 0.88)
	Engine.time_scale = 0.0
	await _snap("08_test_piece_landed")

	# COMMITTED, through the guarded seam and nothing else.
	Engine.time_scale = 1.0
	chute.apply_maintenance_result({
		"quality": "good",
		"note": "arch broken at the choke, load recovered and the chute proved by a test piece to the box",
		"mechanism_patch": {"arch_standing": false, "load_taken": true,
				"cover_locked": true, "glass_drawn": 0.0,
				"chute_clear": true},
	})
	Engine.time_scale = 0.0
	_aim(WORKS_EYE, WORKS_AIM, WORKS_FOV)
	await _snap("09_committed")
	_aim(WIDE_EYE, WIDE_AIM, WIDE_FOV)
	await _snap("10_wall_after")

	Engine.time_scale = 1.0
	print("[CHUTE SHOT] 11 frames saved to %s" % out_dir)
	print("[CHUTE SHOT] clear=%s arch=%s landed=%s locked=%s"
			% [chute.chute_clear, chute.arch_standing,
					chute.test_piece_landed, chute.cover_locked])
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
		push_error("[CHUTE SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
