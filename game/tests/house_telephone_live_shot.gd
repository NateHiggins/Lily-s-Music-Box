extends Node
## PHONE-B production-context placement and ordinary-operation proof.

var root: Node3D
var player: PlayerController
var board: Node
var line: Node
var out_dir := ""

const BOARD_EYE := [-4.20, -6.62, 1.78]
const BOARD_AIM := [-5.02, -6.62, 1.76]
const CONTEXT_EYE := [-3.90, -5.55, 1.70]
const CONTEXT_AIM := [-5.00, -6.72, 1.67]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir == "": out_dir = "user://house_telephone_phone_b"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	board = root.find_child("F01_HOUSE_TELEPHONE_BOARD", true, false)
	line = root.find_child("HouseTelephoneNetwork", true, false)
	player = root.get("player") as PlayerController
	if board == null or line == null or player == null:
		push_error("[HOUSE TELEPHONE LIVE SHOT] production apparatus missing")
		get_tree().quit(1); return
	_hide_ui(get_tree().root)
	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.2).timeout
	player.set_process(false)
	Engine.time_scale = 0.0
	_aim(BOARD_EYE, BOARD_AIM, 43.0)
	await _snap("00_board_control_a")
	await _snap("00_board_control_b")
	_aim(CONTEXT_EYE, CONTEXT_AIM, 58.0)
	await _snap("01_west_wall_context")
	_aim(BOARD_EYE, BOARD_AIM, 43.0)
	line.call("request", "apt_4b")
	await _snap("02_4b_asking")
	board.call("interact")
	await _snap("03_a_answered")
	board.call("interact")
	await _snap("04_b_carrying")
	board.call("interact")
	await _snap("05_released")
	Engine.time_scale = 1.0
	print("[HOUSE TELEPHONE LIVE SHOT] RESULT: PASS captures=6 dir=%s" % out_dir)
	get_tree().quit()


func _aim(eye: Array, target: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(eye) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(target), Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(label + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("[HOUSE TELEPHONE LIVE SHOT] %s %s" % [
			"capture" if error == OK else "FAIL", path])
	if error != OK: get_tree().quit(1)


func _hide_ui(node: Node) -> void:
	if node == board: return
	if node is CanvasLayer or node is Label3D: node.visible = false
	for child in node.get_children(): _hide_ui(child)
