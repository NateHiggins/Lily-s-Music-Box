extends Node
## SR7-P proof sheet: seven empty boards are a story.
##
##     tools/run_godot_serial.ps1 -Windowed `
##         -Scene res://tests/ExtinguisherBoardsShot.tscn `
##         -ShotDir <abs> -ProjectPath <checkout>/game
##
## Through the real `res://scenes/building/orison_root.tscn`. Every one of the
## eight authored backboards is photographed from the SAME player-reachable
## standing place on its own floor's landing, with the same lens, so the only
## thing that can differ between two frames is what is actually on the wall.
## No proof-only light, mesh, material, camera rig or production owner.
##
## WHAT THE SHEET HAS TO SAY WITHOUT A CAPTION.
##   * F03 is the one board with a working extinguisher on it, and it is the
##     control: SR7-O's apparatus, photographed but never operated.
##   * The other seven are not seven empty rectangles and not seven copies of
##     each other. Each reads as a specific physical condition at standing
##     distance.
##   * And an intact silhouette on the wall proves nothing about readiness,
##     which is why the passive vocabulary never shows a tag that says it does.

## The board is authored at b(-2.76, -3.10) on every floor, 0.34 x 0.08 x 0.70,
## its front face at y -3.06 and its span z+0.70..z+1.40.
const BOARD_X := -2.76
const BOARD_FACE_Y := -3.06
const BOARD_MID_Z := 1.02
## A standing place on the landing, one metre off the wall, at a walking eye
## height. The landing runs y -3.16..-1.46, so this is inside it by 0.96.
const STAND_Y := -1.71
const EYE_Z := 1.30
const BOARD_FOV := 38.0
## The same wall from along the landing, to show the board in its stair-core
## context beside the standpipe run.
const WIDE_FROM := [-0.42, -2.28, 1.60]
const WIDE_FOV := 46.0

const FLOORS := [
	["B1", -2.8], ["F01", 0.0], ["F02", 3.2], ["F03", 6.4],
	["F04", 9.6], ["F05", 12.8], ["F06", 16.0], ["ROOF", 19.2],
]

var root: Node3D
var player: PlayerController
var out_dir := ""


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://extinguisher_boards_sr7p"
	DirAccess.make_dir_recursive_absolute(out_dir)

	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	player = root.get("player") as PlayerController
	if player == null:
		push_error("[BOARDS SHOT] no player")
		get_tree().quit(1)
		return
	_hide_ui(get_tree().root)

	player.set_physics_process(false)
	_aim_board(0.0)
	await get_tree().create_timer(0.8).timeout
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	print("[BOARDS SHOT] lamp settled: flashlight visible=%s"
			% player.flashlight.visible)
	player.set_process(false)
	Engine.time_scale = 0.0

	# TWO RUNS. Thirteen frames plus a thirty-five second building did not fit
	# inside the runner's sixty-second ceiling, so the sheet is shot in halves
	# and each half carries its own A/A control pair.
	var part := OS.get_environment("SHOT_PART").to_lower()
	var first := 0 if part != "b" else 4
	var last := 4 if part != "b" else FLOORS.size()
	_aim_board(FLOORS[first][1])
	await _snap("%02d_%s_control_a" % [first, str(FLOORS[first][0]).to_lower()])
	await _snap("%02d_%s_control_b" % [first, str(FLOORS[first][0]).to_lower()])

	for index in range(first, last):
		var floor_id: String = FLOORS[index][0]
		var z: float = FLOORS[index][1]
		_aim_board(z)
		await _snap("%02d_board_%s" % [index + 1, floor_id.to_lower()])

	if part == "b":
		_aim_wide(6.4)
		await _snap("09_context_f03_working")
		_aim_wide(9.6)
		await _snap("10_context_f04")

	Engine.time_scale = 1.0
	print("[BOARDS SHOT] frames saved to %s" % out_dir)
	get_tree().quit(0)


## Square on the board, from a place a player can actually stand.
func _aim_board(z: float) -> void:
	_look(GameBoot.b2g([BOARD_X, BOARD_FACE_Y, z + BOARD_MID_Z]),
			GameBoot.b2g([BOARD_X, STAND_Y, z + EYE_Z]), BOARD_FOV)


## The board in its stair-core context.
func _aim_wide(z: float) -> void:
	_look(GameBoot.b2g([BOARD_X, BOARD_FACE_Y, z + BOARD_MID_Z]),
			GameBoot.b2g([WIDE_FROM[0], WIDE_FROM[1], z + WIDE_FROM[2]]),
			WIDE_FOV)


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
		push_error("[BOARDS SHOT] capture failed: %s" % label)


## Sweeps production's debug overlays. SR7-O's apparatus is exempt so that the
## control board photographs with its own lettering intact.
func _hide_ui(node: Node) -> void:
	if str(node.name) == "F03_EXTINGUISHER_STAIR":
		return
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_ui(child)
