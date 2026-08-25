extends Node
## SR7-A proof sheet: the production dumbwaiter and its holding brake.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/MaintenanceDumbwaiterShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Every frame is the real `orison_root.tscn` in Forward+, lit by the building's
## own lobby lighting. There is no proof-only wall, prop, material or light: the
## camera simply walks up the back-of-house corridor to the apparatus the detail
## pass places, and the mechanism is worked through the same public preview and
## commit seam the player's panel uses.
##
## The pair 00a/00b is the A/A control -- identical state, identical camera --
## and prices the noise floor that every worked frame must beat.

var root: Node3D
var cam: Camera3D
var lift: DumbwaiterProp
var out_dir := ""

## Blender coordinates. The prop stands at [5.20, -4.90, 1.05] on the corridor's
## east wall; the eye stands back in the corridor, which is clear from x 3.43.
## The apparatus stands from about z 0.85 (the sill) to z 2.05 (the brake head),
## so the eye is at standing height and far enough back to hold both the shaft
## and the working head in one frame.
## The corridor is bounded by the partition at x 3.43, so the eye cannot go
## further back than that without ending up inside plaster -- which is
## exactly what the previous sheet came back as.
## The apparatus runs from the sill near z 0.80 to the sheave near z 1.88,
## so the frame is centred on 1.34 rather than on standing eye height.
const EYE := [3.58, -4.90, 1.40]
const AIM := [5.10, -4.90, 1.34]
const WIDE_EYE := [3.58, -6.60, 1.66]
const WIDE_AIM := [5.10, -5.25, 1.28]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://maintenance_dumbwaiter_sr7a"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(2.5).timeout
	_hide_ui(get_tree().root)

	lift = root.find_child("LobbyServiceDumbwaiter", true, false) \
			as DumbwaiterProp
	if lift == null:
		push_error("[DUMBWAITER SHOT] the production lobby has no dumbwaiter")
		get_tree().quit(1)
		return

	cam = Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	_aim(EYE, AIM)

	# Freeze the world so the A/A pair prices this prop and not the building
	# breathing around it. The prop's own slip animation is driven by `_process`
	# and is stopped with it; the slip frame therefore shows the pose, not a
	# blur of it.
	lift.set_process(false)
	Engine.time_scale = 0.0

	await _snap("00_control_a")
	await _snap("00_control_b")

	# Each frame is one authored step, worked through the public preview seam.
	Engine.time_scale = 1.0
	lift.preview_maintenance_step({"id": "take_strain"}, 0.58)
	Engine.time_scale = 0.0
	await _snap("01_strain_taken")

	Engine.time_scale = 1.0
	lift.preview_maintenance_step({"id": "ease_pawl"}, 0.71)
	Engine.time_scale = 0.0
	await _snap("02_pawl_clear")

	Engine.time_scale = 1.0
	lift.preview_maintenance_step({"id": "prove_balance"}, 1.0)
	Engine.time_scale = 0.0
	await _snap("03_counterweight_answers")

	# The committed state, through the guarded seam and nothing else.
	Engine.time_scale = 1.0
	lift.apply_maintenance_result({
		"quality": "good",
		"note": "pawl freed; band reseated and proved under load",
		"mechanism_patch": {"band_seated": true, "pawl_lift": 0.0,
				"rope_strain": 0.0, "brake_bite": DumbwaiterProp.BAND_HOME},
	})
	Engine.time_scale = 0.0
	await _snap("04_band_seated")

	# THE READABLE REFUSAL. The pawl is asked to come clear against a slack
	# rope. `_slip` runs inside the same preview call, so the refused pose is
	# already in this frame -- no world time is allowed to pass, which keeps the
	# A/A floor honest. This frame is priced against 02, not against the
	# control: the lesson is that the pawl did NOT move, and only 02 shows what
	# it looks like when it does.
	Engine.time_scale = 1.0
	lift.restore_maintenance_snapshot({"band_seated": false, "brake_bite": 0.34,
			"pawl_lift": 0.0, "rope_strain": 0.0, "car_travel": 0.0})
	lift.preview_maintenance_step({"id": "ease_pawl"}, 0.71)
	Engine.time_scale = 0.0
	await _snap("05_pawl_refused")

	# And the apparatus in its wall run, with the porter's board beyond it.
	_aim(WIDE_EYE, WIDE_AIM)
	await _snap("06_wall_run")

	Engine.time_scale = 1.0
	print("[DUMBWAITER SHOT] 8 frames saved to %s" % out_dir)
	get_tree().quit(0)


func _aim(eye: Array, target: Array) -> void:
	cam.global_position = GameBoot.b2g(eye)
	cam.look_at(GameBoot.b2g(target))


## `create_timer` is asked to ignore the time scale, so the world can be frozen
## while the harness still waits in real seconds for the frame to settle.
func _snap(label: String) -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[DUMBWAITER SHOT] capture failed: %s" % label)


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
