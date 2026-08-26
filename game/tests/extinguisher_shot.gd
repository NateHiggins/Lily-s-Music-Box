extends Node
## SR7-O proof sheet: the seal is not the charge.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/ExtinguisherShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Through the real `res://scenes/building/orison_root.tscn`, on the F03 stair
## landing, on the player's own camera, lit by the core's own pendant. No
## proof-only light, mesh, material, camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * A DEAD EXTINGUISHER AND A SOUND ONE ARE THE SAME PHOTOGRAPH. Frame `00`
##     is the unit as found -- sealed, charged, correctly heavy, and inert.
##     Frame `10` is the same unit repaired and re-sealed. They must be one
##     picture, because everything that changed is inside a bottle inside a
##     cage inside a cap.
##   * Hefting it changes nothing, including the frame.
##   * And the one thing that DOES show is the diagnosis: lift at the bottle's
##     cap and the bottle comes with it.

var root: Node3D
var player: PlayerController
var unit: Node3D
var out_dir := ""


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://extinguisher_sr7o"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	unit = root.find_child("F03_EXTINGUISHER_STAIR", true, false) as Node3D
	player = root.get("player") as PlayerController
	if unit == null or player == null:
		push_error("[EXT SHOT] the extinguisher is not in the building")
		get_tree().quit(1)
		return
	# The plates are Label3D, the established Orison prop lettering idiom.
	_hide_ui(get_tree().root)

	player.set_physics_process(false)
	_aim_board()
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[EXT SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	unit.set_process(false)
	Engine.time_scale = 0.0

	var found: Dictionary = unit.call("maintenance_snapshot")

	# --- AS FOUND, from three places ----------------------------------------
	_aim_board()
	await _snap("00_board_control_a")
	await _snap("00_board_control_b")
	_aim_cap()
	await _snap("01_cap_control_a")
	await _snap("01_cap_control_b")
	_aim_shelf()
	await _snap("02_shelf_control_a")
	await _snap("02_shelf_control_b")

	# --- WEIGHT SETTLES NOTHING, AND MOVES NOTHING --------------------------
	_aim_board()
	_act(unit, "heft")
	await _snap("03_hefted_no_change")

	# --- THE SEAL STOPS THE CAP ---------------------------------------------
	_aim_cap()
	_act(unit, "unscrew_cap")
	await _snap("04_cap_refused_by_seal")
	_calm(unit)
	_act(unit, "cut_seal")
	await _snap("05_seal_cut")
	_act(unit, "unscrew_cap")
	await _snap("06_cap_off_cage_up")

	# --- THE DIAGNOSIS, ON THE SHELF ----------------------------------------
	_aim_shelf()
	_act(unit, "draw_bottle")
	await _snap("07_bottle_drawn")
	_act(unit, "try_loose_cap")
	await _snap("08_diagnosis_bottle_comes_up")
	_calm(unit)
	_act(unit, "free_loose_cap")
	await _snap("09_cap_worked_free")

	# --- PUT IT BACK, AND IT LOOKS EXACTLY AS IT DID ------------------------
	_act(unit, "seat_bottle")
	_act(unit, "screw_cap")
	_act(unit, "wire_seal")
	_aim_board()
	await _snap("10_sound_and_sealed")
	_act(unit, "sign_tag")
	await _snap("11_tag_signed")
	_act(unit, "invert")
	await _snap("12_invert_refused")
	_calm(unit)
	_act(unit, "restore_maintenance_snapshot", found)
	await _snap("13_restored_after_abort")

	Engine.time_scale = 1.0
	print("[EXT SHOT] frames saved to %s" % out_dir)
	print("[EXT SHOT] sealed=%s charged=%s lifts=%s usable=%s tag=%s"
			% [unit.call("sealed"), unit.call("charged"),
					unit.call("will_lift"), unit.call("usable"),
					unit.call("tag_reads")])
	get_tree().quit(0)


## Put a refused instrument back at rest. A balk is a held pose that decays in
## `_process`, and a frozen sheet does not tick, so a refusal taken at one frame
## would still be standing at the next one -- the bug SR7-N's measurements
## caught. Every refusal frame is followed by this.
func _calm(target: Node) -> void:
	Engine.time_scale = 1.0
	target.set("_balk_left", 0.0)
	target.set("_balk_focus", "")
	target.call("_refresh_extinguisher")
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


## The whole apparatus on its board, framed off the prop's own transform so the
## aim survives a placement change -- the lesson SR7-H's card and SR7-L's hook
## both paid for.
func _aim_board() -> void:
	_look(unit.to_global(Vector3(0.0, 0.420, 0.130)),
			unit.to_global(Vector3(-0.020, 0.470, 1.540)), 36.0)


## The neck, the lugs and the lead-and-wire seal.
func _aim_cap() -> void:
	_look(unit.to_global(Vector3(0.0, 0.762, 0.130)),
			unit.to_global(Vector3(-0.060, 0.940, 0.560)), 32.0)


## The shelf the drawn bottle stands on -- empty as found, and the place the
## whole diagnosis happens.
func _aim_shelf() -> void:
	_look(unit.to_global(Vector3(-0.192, 0.178, 0.150)),
			unit.to_global(Vector3(-0.400, 0.470, 0.560)), 34.0)


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
		push_error("[EXT SHOT] capture failed: %s" % label)


## Sweeps production's debug overlays. THE APPARATUS IS EXEMPT: its charge
## plate and its tag are Label3D, and hiding every Label3D would blank the
## printing the sheet exists to photograph.
func _hide_ui(node: Node) -> void:
	if node == unit:
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_ui(child)
