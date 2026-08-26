extends Node
## SR7-L proof sheet: the tour key, its guard, and the box that asks for it.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/TourKeyShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Two ends of the building in one sheet. The lobby guard is shot in the
## watchman's lane; the F02 box is shot on its own corridor wall. Both through
## the player's own camera, lit by the rooms' own fixtures. No proof-only
## light, mesh, material, camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * The hook carries a KEY or a numbered CHECK, and those do not look alike.
##   * The latch lies across a loaded hook and stands open on an emptied one.
##   * The box's refusal with an empty socket shoves the SOCKET forward —
##     a different picture from its pawl refusal, which moves the crank.

var root: Node3D
var player: PlayerController
var guard: Node
var box: Node
var net: Node
var out_dir := ""
var part := ""

## The guard hangs at (5.24, -2.99, 1.42) facing west into the lobby. Its
## close-up is derived from the hook's own world position rather than authored,
## for the same reason SR7-H's conclusion card is: an authored rig and a small
## subject drift apart, and the first sheet came back with the guard a third of
## the way off-centre.
const GUARD_OFFSET := Vector3(-0.52, 0.02, 0.0)
const GUARD_FOV := 38.0
## The lane: signal register, guard, night register, detector.
const LANE_EYE := [3.70, -4.40, 1.70]
const LANE_AIM := [5.18, -2.30, 1.55]
const LANE_FOV := 64.0
## The F02 station box at (-5.33, -3.10, 4.62) facing east.
const BOX_EYE := [-4.58, -3.09, 4.86]
const BOX_AIM := [-5.22, -3.10, 4.77]
const BOX_FOV := 40.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	part = OS.get_environment("SHOT_PART").to_lower()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://tour_key_sr7l"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	guard = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	box = root.find_child("F02_WATCH_STATION_01", true, false)
	net = root.find_child("WatchStationNetwork", true, false)
	player = root.get("player") as PlayerController
	if guard == null or box == null or net == null or player == null:
		push_error("[TOUR KEY SHOT] the line is not complete in production")
		get_tree().quit(1)
		return
	# The guard's legend and check number are Label3D, the established Orison
	# prop lettering idiom; the overlay sweep must not blank them.
	_hide_ui(get_tree().root)

	player.set_physics_process(false)
	_aim_guard()
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[TOUR KEY SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	guard.set_process(false)
	box.set_process(false)
	Engine.time_scale = 0.0

	var found: Dictionary = guard.call("maintenance_snapshot")

	if part != "b":
		# --- THE GUARD ------------------------------------------------------
		_aim_guard()
		await _snap("00_guard_control_a")
		await _snap("00_guard_control_b")

		_aim(LANE_EYE, LANE_AIM, LANE_FOV)
		await _snap("01_lane_control")
		_aim_guard()

		# THE KEY COMES OFF, and the check goes on.
		_act(guard, "take_key")
		await _snap("02_key_taken_check_hung")
		# REFUSAL: a hook carrying its check has no second key to give.
		_act(guard, "take_key")
		await _snap("03_second_take_refused")
		# AND BACK.
		_act(guard, "return_key")
		await _snap("04_key_returned")
		# REFUSAL: a copied key offered to a loaded hook.
		_act(guard, "return_key")
		await _snap("05_copied_key_refused")
		_act(guard, "restore_maintenance_snapshot", found)
		await _snap("06_restored_after_abort")
	if part == "a":
		_finish()
		return

	# --- THE BOX ------------------------------------------------------------
	_aim(BOX_EYE, BOX_AIM, BOX_FOV)
	await _snap("07_box_control_a")
	await _snap("07_box_control_b")

	# EMPTY SOCKET. The key is on its hook in the lobby, and the crank runs
	# against nothing.
	_act(box, "open_door")
	await _snap("08_box_open_no_key")
	_act(box, "turn_crank")
	await _snap("09_empty_socket_refused")

	# THE KEY IS TAKEN, TWO FLOORS AWAY, and the same box now works.
	_act(guard, "take_key")
	_act(box, "restore_maintenance_snapshot",
			box.call("maintenance_snapshot"))
	_act(box, "open_door")
	await _snap("10_box_open_with_key")
	_act(box, "turn_crank")
	await _snap("11_marked_with_key")
	# REPEAT: the pawl, not the socket — a different refusal, a different pose.
	_act(box, "open_door")
	_act(box, "turn_crank")
	await _snap("12_repeat_crank_refused")

	Engine.time_scale = 1.0
	print("[TOUR KEY SHOT] part '%s' frames saved to %s" % [part, out_dir])
	print("[TOUR KEY SHOT] key_on_hook=%s marks=%d delivered=%d"
			% [guard.get("key_on_hook"), box.get("marks"),
					net.call("delivered_count")])
	get_tree().quit(0)


## One action on a frozen instrument. The balk is cleared first so each refusal
## frame shows its OWN refusal and never an inherited pose.
func _act(target: Node, method: String, argument: Variant = null) -> void:
	Engine.time_scale = 1.0
	target.set("_balk_left", 0.0)
	target.set("_balk_focus", "")
	if argument == null:
		target.call(method)
	else:
		target.call(method, argument)
	Engine.time_scale = 0.0


## The guard, close, framed on its own hook.
func _aim_guard() -> void:
	var hook := (guard as Node3D).find_child("GuardHook", true, false) as Node3D
	if hook == null:
		return
	var at := hook.global_position
	player.global_position = at + GUARD_OFFSET - player.camera.position
	player.camera.fov = GUARD_FOV
	player.camera.look_at(at, Vector3.UP)
	player.camera.make_current()


func _aim(eye: Array, target: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(eye) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(target), Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("[TOUR KEY SHOT] capture failed: %s" % label)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[TOUR KEY SHOT] part '%s' frames saved to %s" % [part, out_dir])
	get_tree().quit(0)


## Sweeps production's debug overlays. THE GUARD AND THE BOX ARE EXEMPT: their
## legends are Label3D, and hiding every Label3D would blank the lettering this
## sheet exists to photograph.
func _hide_ui(node: Node) -> void:
	if node == guard or node == box:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for c in node.get_children():
		_hide_ui(c)
