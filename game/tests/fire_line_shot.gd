extends Node
## SR7-N proof sheet: the hose is not water.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/FireLineShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Through the real `res://scenes/building/orison_root.tscn`, in the F01 stair
## core, on the player's own camera, lit by the core's own pendant. No
## proof-only light, mesh, material, camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * A shut cabinet is a shut cabinet. The frame with three broken joints
##     behind the glass and the frame with a made-up line behind the glass must
##     be THE SAME PICTURE.
##   * A made-up coupling is a made-up coupling. The joint with a gasket in it
##     and the joint with nothing in it must also be the same picture -- and it
##     is, on the declared joint crop. The only trace anywhere in the frame is
##     an empty clip in the gasket tin, which is exactly right: the evidence of
##     the repair is a missing part in a tin, not anything at the joint.
##   * And the things that DO show -- the broken joint, the seated gasket, the
##     coupled play-pipe, the fresh fold -- must each move their own crop and
##     nobody else's.

var root: Node3D
var player: PlayerController
var cabinet: Node3D
var out_dir := ""


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://fire_line_sr7n"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	cabinet = root.find_child("F01_FIRE_LINE_STAIR", true, false) as Node3D
	player = root.get("player") as PlayerController
	if cabinet == null or player == null:
		push_error("[FIRE SHOT] the hose station is not in the building")
		get_tree().quit(1)
		return
	# The plates are Label3D, the established Orison prop lettering idiom.
	_hide_ui(get_tree().root)

	player.set_physics_process(false)
	_aim_cabinet()
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[FIRE SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	cabinet.set_process(false)
	Engine.time_scale = 0.0

	var found: Dictionary = cabinet.call("maintenance_snapshot")

	# --- AS FOUND: shut, full, and dead -------------------------------------
	_aim_cabinet()
	await _snap("00_cabinet_control_a")
	await _snap("00_cabinet_control_b")
	_aim_core()
	await _snap("01_core_control_a")
	await _snap("01_core_control_b")

	# --- OPEN: fifty feet of sound linen in front of three broken joints ----
	_aim_cabinet()
	_act(cabinet, "open_door")
	await _snap("02_open_as_found")
	_aim_joint()
	await _snap("03_joint_control_a")
	await _snap("03_joint_control_b")

	# --- THE HONEST DUTY THAT MAKES NO LINE ---------------------------------
	_aim_cabinet()
	_act(cabinet, "refold_hose")
	await _snap("04_refolded")
	_act(cabinet, "sign_tag")
	await _snap("05_sign_refused_hose_present")
	_calm(cabinet)
	_aim_joint()
	await _snap("06_joint_after_refold")

	# --- THE ORDERING REFUSAL, AND THE POCKET --------------------------------
	_act(cabinet, "seat_gasket")
	await _snap("07_gasket_refused_through_joint")
	_calm(cabinet)
	_act(cabinet, "break_joint")
	await _snap("08_joint_broken_empty_pocket")
	_act(cabinet, "seat_gasket")
	await _snap("09_gasket_seated")
	_act(cabinet, "make_up_coupling")
	await _snap("10_joint_made_up_properly")

	# --- THE FAR END, AND THE TAG -------------------------------------------
	_aim_cabinet()
	_act(cabinet, "couple_nozzle")
	_act(cabinet, "shut_nozzle")
	await _snap("11_line_made_up")
	_act(cabinet, "sign_tag")
	await _snap("12_tag_signed")
	_act(cabinet, "try_open_valve")
	await _snap("13_valve_refused")
	_calm(cabinet)

	# --- AND SHUT IT AGAIN ---------------------------------------------------
	_act(cabinet, "close_door")
	await _snap("14_shut_with_a_line")
	_act(cabinet, "restore_maintenance_snapshot", found)
	await _snap("15_restored_after_abort")
	_aim_core()
	await _snap("16_core_after")

	Engine.time_scale = 1.0
	print("[FIRE SHOT] frames saved to %s" % out_dir)
	print("[FIRE SHOT] line=%s hose=%s tag=%s"
			% [cabinet.call("line_made_up"), cabinet.call("hose_present"),
					cabinet.call("tag_reads")])
	get_tree().quit(0)


## Put a refused instrument back at rest.
##
## THE FIRST SHEET GOT THIS WRONG AND THE MEASUREMENTS CAUGHT IT. A balk is a
## held pose that decays in `_process`, and a frozen sheet does not tick, so a
## refusal taken at one frame was still standing at the next one -- the joint
## camera photographed a coupling tilted by the refusal BEFORE it and scored
## 0.044 on a crop that should have been at the noise floor. Every refusal
## frame is followed by this.
func _calm(target: Node) -> void:
	Engine.time_scale = 1.0
	target.set("_balk_left", 0.0)
	target.set("_balk_focus", "")
	target.call("_refresh_cabinet")
	Engine.time_scale = 0.0


## One action on a frozen instrument, with its balk cleared so each refusal
## frame shows its OWN refusal.
func _act(target: Node, method: String, argument: Variant = null) -> void:
	Engine.time_scale = 1.0
	target.set("_balk_left", 0.0)
	target.set("_balk_focus", "")
	if argument == null:
		target.call(method)
	else:
		target.call(method, argument)
	Engine.time_scale = 0.0


## Framed on the cabinet's own case rather than on authored coordinates -- the
## lesson SR7-H's card and SR7-L's hook both paid for. The case centre is local
## (0, 0.39, 0.11) and the whole apparatus faces local +z, so backing off along
## the prop's own +z is the one aim that survives a placement change.
func _aim_cabinet() -> void:
	_look(cabinet.to_global(Vector3(0.0, 0.390, 0.110)),
			cabinet.to_global(Vector3(0.0, 0.415, 1.420)), 38.0)


## The valve column, whole: the branch coming in, the outlet valve and its
## wheel, the tag on its wire, and the joint the whole thesis lives inside.
## Local (0.17, 0.52) is the coupling and (0.17, 0.70) is the handwheel, so the
## frame is set to hold both.
func _aim_joint() -> void:
	_look(cabinet.to_global(Vector3(0.170, 0.548, 0.110)),
			cabinet.to_global(Vector3(0.100, 0.720, 0.690)), 38.0)


## The stair core, square enough on the east wall that the 0.175 m of open
## wall between the riser and the cabinet is actually in the picture -- because
## the branch crossing that gap is the only proof, in a photograph, that this
## apparatus hangs on the building's own iron.
func _aim_core() -> void:
	_look(GameBoot.b2g([3.06, -2.78, 1.52]), GameBoot.b2g([1.72, -2.06, 1.84]),
			50.0)


func _look(at: Vector3, from: Vector3, fov: float) -> void:
	player.global_position = from - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(at, Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[FIRE SHOT] capture failed: %s" % label)


## Sweeps production's debug overlays. THE APPARATUS IS EXEMPT: its plates and
## lettering are Label3D, and hiding every Label3D would blank the printing the
## sheet exists to photograph.
func _hide_ui(node: Node) -> void:
	if node == cabinet:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_ui(child)
