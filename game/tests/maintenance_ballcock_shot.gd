extends Node
## SR7-C proof sheet: the roof house-tank ball cock.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/MaintenanceBallcockShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, on the real roof,
## against the timber tank production has always baked there, shot through the
## player's own camera and lit by the roof garden lamp and the player's own
## service lamp. There is no proof-only light, mesh, material or camera rig.
##
## Two close framings, each with its own frozen A/A pair, because the two
## claims live at different heights: the WORKS -- cock, lever, weight, riser
## stop and the overflow witness -- sit at a standing hand's height, and the
## float rides two metres above them in its guard.

var root: Node3D
var player: PlayerController
var cock: RoofTankBallcockProp
var out_dir := ""

## Building coordinates. The apparatus hangs on the tank's south face at
## (-9.05, 4.90, 20.50); the roof deck is at 19.2 and the tank at 20.8..23.1.
##
## WORKS: the cock, its seat, the riser stop, the lever and its weight, and the
## overflow witness below them. This is where holding is proved or is not.
## Framed to hold the cock, the riser stop, the lever weight AND the overflow
## witness at once, because the claim is the relation between them.
const WORKS_EYE := [-8.05, 3.15, 20.80]
const WORKS_AIM := [-9.24, 4.86, 20.52]
const WORKS_FOV := 42.0
## COLUMN: the float riding high in its slotted guard, with the tank behind it.
const COLUMN_EYE := [-7.80, 1.95, 21.15]
const COLUMN_AIM := [-9.12, 4.88, 21.85]
const COLUMN_FOV := 44.0
## WIDE: the tank standing on the roof it has always stood on.
const WIDE_EYE := [-5.30, 1.15, 21.05]
const WIDE_AIM := [-8.55, 5.35, 21.30]
const WIDE_FOV := 58.0


func _ready() -> void:
	# DAYLIGHT, through the production day/night owner's own pin.
	#
	# `DAYNIGHT=0` gives the canonical 03:00 test hour, and the first sheet came
	# back as a rooftop silhouette in the rain: the garden lamp stands NORTH of
	# the tank and the tank itself shadows everything the camera wanted. A roof
	# tank is serviced in daylight, `DAYNIGHT_FORCE` is the mechanism
	# `day_night_director.gd` provides for exactly this, and "day" is an
	# ordinary production lighting state rather than a light invented for a
	# photograph.
	OS.set_environment("DAYNIGHT_FORCE", "day")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_ballcock_sr7c"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	_hide_ui(get_tree().root)

	cock = root.find_child("ROOF_TANK_BALLCOCK", true, false) \
			as RoofTankBallcockProp
	player = root.get("player") as PlayerController
	if cock == null or player == null:
		push_error("[BALLCOCK SHOT] no production ball cock or player")
		get_tree().quit(1)
		return

	# Stand the player on the roof and let the floor-visibility gate notice.
	# The gate keys on the player's own height (`p.y > 15.0` for ROOF), so the
	# roof has to be occupied for real before anything is photographed rather
	# than forced visible with `show_all_floors`.
	_aim(WORKS_EYE, WORKS_AIM, WORKS_FOV)
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(true)
	# Pin the lamp gutter so its own breathing does not become the noise floor
	# every real claim then has to beat. No production default changes; one
	# already-lit lamp is held still for the length of a photograph.
	player.pin_lamp_gutter_for_proof(1.0)
	player.set("_lamp_phase", 0.0)
	player.set("_lamp_phase_total", 0.0)
	player.call("_advance_lamp", 0.0)
	await get_tree().create_timer(0.5).timeout
	player.set_physics_process(false)
	player.set_process(false)
	cock.set_process(false)
	Engine.time_scale = 0.0

	# Both frozen controls are taken in the as-found state -- waterlogged float,
	# riser open, overflow running -- before a single verb.
	await _snap("00_works_control_a")
	await _snap("00_works_control_b")
	_aim(COLUMN_EYE, COLUMN_AIM, COLUMN_FOV)
	await _snap("01_column_control_a")
	await _snap("01_column_control_b")

	_aim(WIDE_EYE, WIDE_AIM, WIDE_FOV)
	await _snap("02_roof_context")

	# THE CONTRADICTION. The tell-tale is brought across and the float is
	# riding at the full mark -- while the overflow is still running. Nothing
	# about the float's position can tell you why.
	_aim(COLUMN_EYE, COLUMN_AIM, COLUMN_FOV)
	Engine.time_scale = 1.0
	cock.preview_maintenance_step({"id": "read_the_float"}, 0.86)
	Engine.time_scale = 0.0
	await _snap("03_telltale_reads_full")

	# The riser shut. The witness goes dry -- and that proves NOTHING, because
	# a dry witness under a shut stop is not a holding valve.
	_aim(WORKS_EYE, WORKS_AIM, WORKS_FOV)
	Engine.time_scale = 1.0
	cock.preview_maintenance_step({"id": "shut_the_riser"}, 0.0)
	Engine.time_scale = 0.0
	await _snap("04_riser_shut_witness_dry")

	# THE DIAGNOSIS. Held clear of a dead inlet, the float pours from its split
	# seam. It has been carrying water instead of lifting against it.
	_aim(COLUMN_EYE, COLUMN_AIM, COLUMN_FOV)
	Engine.time_scale = 1.0
	cock.preview_maintenance_step({"id": "lift_the_float"}, 0.55)
	Engine.time_scale = 0.0
	await _snap("05_float_pouring")

	# THE MECHANICALLY FALSE ORDER. The riser opened before the weight is set:
	# the float is sound now but the arm still has no leverage, so the cock
	# still cannot hold and the overflow starts again. The apparatus balks.
	_aim(WORKS_EYE, WORKS_AIM, WORKS_FOV)
	Engine.time_scale = 1.0
	cock.preview_maintenance_step({"id": "prove_the_hold"}, 0.91)
	Engine.time_scale = 0.0
	await _snap("06_opened_too_soon_refused")

	# The weight run out along the arm. Leverage, at last.
	Engine.time_scale = 1.0
	cock.preview_maintenance_step({"id": "shut_the_riser"}, 0.0)
	cock.preview_maintenance_step({"id": "set_the_weight"},
			RoofTankBallcockProp.WEIGHT_HOME)
	Engine.time_scale = 0.0
	await _snap("07_weight_set")

	# HONEST CLOSURE. Riser open, valve holding, witness dry -- and this time
	# the dry witness means something, because there is pressure behind it.
	Engine.time_scale = 1.0
	cock.preview_maintenance_step({"id": "prove_the_hold"}, 0.91)
	Engine.time_scale = 0.0
	await _snap("08_holding_dry")

	# COMMITTED, through the guarded seam and nothing else.
	Engine.time_scale = 1.0
	cock.apply_maintenance_result({
		"quality": "good",
		"note": "float drained and reseated; lever weight set to the riser pressure and the cock proved dry on the witness",
		"mechanism_patch": {"float_waterlogged": false,
				"weight_set": RoofTankBallcockProp.WEIGHT_HOME,
				"riser_open": true, "overflow_running": false,
				"ballcock_serviced": true},
	})
	Engine.time_scale = 0.0
	await _snap("09_committed")
	_aim(COLUMN_EYE, COLUMN_AIM, COLUMN_FOV)
	await _snap("10_column_committed")
	_aim(WIDE_EYE, WIDE_AIM, WIDE_FOV)
	await _snap("11_roof_wide_after")

	Engine.time_scale = 1.0
	print("[BALLCOCK SHOT] 12 frames saved to %s" % out_dir)
	print("[BALLCOCK SHOT] serviced=%s holds=%s overflow=%s force=%.3f"
			% [cock.ballcock_serviced, cock.valve_holds(),
					cock.overflow_running(), cock.closing_force()])
	get_tree().quit(0)


## `PlayerController`'s camera sits a standing eye-height above its root, so the
## root goes to the requested eye MINUS that offset.
func _aim(eye: Array, target: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(eye) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(target), Vector3.UP)
	player.camera.make_current()


## `create_timer` is asked to ignore the time scale, so the world can be frozen
## while the harness still waits in real seconds for the frame to settle.
func _snap(label: String) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[BALLCOCK SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
