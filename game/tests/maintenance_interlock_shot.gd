extends Node
## SR7-B proof sheet: the production elevator's F01 landing-door interlock.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/MaintenanceInterlockShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, lit by the lobby's
## own chandelier. There is no proof-only wall, prop, material, light or camera
## rig: the camera stands on the lobby floor in front of the real elevator
## opening, and the mechanism is worked through the same public preview and
## commit seam the player's panel uses. The landing door in these frames is the
## production door, moved only through the lift's own guarded service setter.
##
## The pair 00a/00b is the A/A control -- identical state, identical camera --
## and prices the noise floor every worked frame must beat.

var root: Node3D
var player: PlayerController
var lock: ElevatorInterlockProp
var lift: OrisonElevator
var out_dir := ""

## Blender coordinates. The interlock sits in the reveal of the F01 opening at
## (2.33, -6.72, 1.34); the lobby runs south of the core wall to y -9.65.
##
## Three framings, because three different claims have to be legible and no
## single distance serves them all. Each close framing gets its OWN frozen A/A
## pair, so every worked frame is priced against the camera that took it.
##
## DETAIL sits on the contact block at (2.34, -6.88, 1.50): the two silver
## faces and the bridge across them. This is where "closed is not locked"
## actually happens.
const DETAIL_EYE := [2.21, -7.32, 1.52]
const DETAIL_AIM := [2.23, -6.88, 1.49]
const DETAIL_FOV := 30.0
## LOCK holds the whole assembly -- case, keeper, latch, roller arm, cam --
## against the door behind it.
const LOCK_EYE := [2.06, -7.66, 1.45]
const LOCK_AIM := [2.20, -6.80, 1.33]
const LOCK_FOV := 32.0
## The opening itself, head on, from standing height in the lobby.
const LANDING_EYE := [1.92, -8.30, 1.60]
const LANDING_AIM := [2.02, -6.76, 1.26]
const LANDING_FOV := 46.0
## Far enough back to place the whole apparatus in the real room.
const WIDE_EYE := [0.55, -8.95, 1.74]
const WIDE_AIM := [2.02, -6.80, 1.30]
const WIDE_FOV := 55.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_interlock_sr7b"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(2.5).timeout
	_hide_ui(get_tree().root)

	lock = root.find_child("F01LandingInterlock", true, false) \
			as ElevatorInterlockProp
	lift = root.get("elevator") as OrisonElevator
	if lock == null or lift == null:
		push_error("[INTERLOCK SHOT] the production F01 landing has no interlock")
		get_tree().quit(1)
		return

	# THE CAMERA IS THE PLAYER'S OWN, and so is the light.
	#
	# The first sheet used a free Camera3D and came back with the whole
	# assembly in silhouette: the interlock faces south into the lobby while
	# the only nearby source is the car's dome light behind it, so every part
	# read as the same dark brown. A superintendent reading a contact block
	# does it from arm's length with his lamp, and that lamp is production
	# equipment that already rides this camera. Nothing proof-only is added.
	player = root.get("player") as PlayerController
	if player == null:
		push_error("[INTERLOCK SHOT] no production player to stand behind")
		get_tree().quit(1)
		return
	player.set_physics_process(false)
	player.set_lamp_enabled(true)
	# Pin the lamp the way the LC-4B sheet did. The gutter breathes on its own
	# phase, and an unpinned lamp put roughly a percent of RMSE into the A/A
	# pair all by itself -- noise that would then have to be beaten by every
	# real claim. This changes no production default; it holds one already-lit
	# lamp still for the length of a photograph.
	player.pin_lamp_gutter_for_proof(1.0)
	player.set("_lamp_phase", 0.0)
	player.set("_lamp_phase_total", 0.0)
	player.call("_advance_lamp", 0.0)
	player.set_process(false)
	_aim(DETAIL_EYE, DETAIL_AIM, DETAIL_FOV)

	# Freeze the world so the A/A pair prices this apparatus and not the
	# building breathing around it. The prop's own balk shudder is driven by
	# `_process` and stops with it, so a refusal frame shows the pose rather
	# than a blur of it.
	lock.set_process(false)
	Engine.time_scale = 0.0

	# Both frozen controls are taken in the as-found state, before a single
	# verb, so each priced pair is a true A/A of its own camera.
	await _snap("00_detail_control_a")
	await _snap("00_detail_control_b")
	_aim(LOCK_EYE, LOCK_AIM, LOCK_FOV)
	await _snap("01_lock_control_a")
	await _snap("01_lock_control_b")

	# The opening in its lobby, before anything is touched.
	_aim(LANDING_EYE, LANDING_AIM, LANDING_FOV)
	await _snap("02_landing_context")
	_aim(DETAIL_EYE, DETAIL_AIM, DETAIL_FOV)

	# AS FOUND: the bridging wire lying across both terminals. Both contact
	# faces are dark -- neither is actually made -- and the circuit is reading
	# continuous anyway. That is the whole fault in one frame.
	Engine.time_scale = 1.0
	lock.preview_maintenance_step({"id": "gauge_keeper"}, 0.42)
	Engine.time_scale = 0.0
	await _snap("03_bridged_as_found")

	# THE BRIDGE COMES OFF, and nothing else moves. Isolated deliberately: this
	# pair of frames prices the copper strap alone, with the door still exactly
	# where it was, so the removal cannot borrow credit from the door closing.
	Engine.time_scale = 1.0
	lock.preview_maintenance_step({"id": "pull_jumper"}, 0.63)
	Engine.time_scale = 0.0
	await _snap("04_bridge_pulled")

	# THE LESSON. Door brought fully home, keeper still out of true: the SHUT
	# contact is made and the LOCKED contact is not. Closed is not locked, and
	# here that is a difference you can see across the room.
	Engine.time_scale = 1.0
	lock.preview_maintenance_step({"id": "bring_home"}, 1.0)
	Engine.time_scale = 0.0
	await _snap("05_shut_but_not_locked")

	# The keeper trued, the latch down its full depth, both pairs closed.
	Engine.time_scale = 1.0
	lock.preview_maintenance_step({"id": "true_keeper"}, 0.78)
	lock.preview_maintenance_step({"id": "bring_home"}, 1.0)
	Engine.time_scale = 0.0
	await _snap("06_door_home_and_locked")

	# THE PROVING TEST: the door deliberately cracked. The latch is out of the
	# keeper, the locked contact has fallen open, and with no bridge left to
	# answer for it the circuit is broken.
	_aim(LOCK_EYE, LOCK_AIM, LOCK_FOV)
	Engine.time_scale = 1.0
	lock.preview_maintenance_step({"id": "prove_refusal"}, 0.22)
	Engine.time_scale = 0.0
	await _snap("07_door_cracked_refusing")

	# COMMITTED, through the guarded seam and nothing else.
	Engine.time_scale = 1.0
	lock.apply_maintenance_result({
		"quality": "good",
		"note": "bridging wire removed; keeper trued and the landing interlock proved by refusal",
		"mechanism_patch": {"jumper_present": false,
				"keeper_true": ElevatorInterlockProp.KEEPER_TRUE,
				"door_home": 1.0, "interlock_proved": true},
	})
	Engine.time_scale = 0.0
	await _snap("08_committed")

	# And the apparatus in the real lobby, at the real opening.
	_aim(WIDE_EYE, WIDE_AIM, WIDE_FOV)
	await _snap("09_lobby_wide")

	Engine.time_scale = 1.0
	print("[INTERLOCK SHOT] 12 frames saved to %s" % out_dir)
	print("[INTERLOCK SHOT] proved=%s holds=%s bridge=%s"
			% [lock.interlock_proved, lock.interlock_holds(),
					lock.jumper_present])
	get_tree().quit(0)


## `PlayerController`'s camera already sits a standing eye-height above its
## root, so the root goes to the requested eye MINUS that offset. Placing the
## root at the eye point would shoot every frame from a second eye-height up.
func _aim(eye: Array, target: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(eye) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(target), Vector3.UP)
	player.camera.make_current()


## `create_timer` is asked to ignore the time scale so the world can be frozen
## while the harness still waits in real seconds for the frame to settle.
func _snap(label: String) -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[INTERLOCK SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
