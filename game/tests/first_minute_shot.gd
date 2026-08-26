extends Node
## K2-A proof sequence — the first minute as a player without source knowledge
## meets it, photographed in production through the player's own camera.
##
##     $env:SHOT_DIR="<abs>"
##     tools/run_godot_serial.ps1 -Scene res://tests/FirstMinuteShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## THE HUD STAYS ON. What the player is told is exactly what is under
## examination, so hiding the objective card would hide the evidence.
##
## The freeze order is the house one — physics off, aim, lamp off, 1.6 s of
## real time, process off, time scale zero — with the one addition this
## sequence needs: the register's slip only appears when the shift is open, and
## the shift opens through a real interaction, so every state change happens
## THAWED and is photographed after it has settled.

var root: Node3D
var player: PlayerController
var director: Node
var detector: Node
var register: Node
var plate: Node3D
var out_dir := ""
## Split in two. Thirteen frames plus a production boot writes every frame and
## then blows the 60-second ceiling on Godot's own shutdown -- the engine
## reports "indexing did not unpair geometries from light" and never exits. The
## work was complete either way; splitting it is how the run also EXITS clean,
## and each part carries its own A/A pair so neither borrows the other's floor.
var part := "a"

## Just inside the front door, where the plate has to do its work.
const DOORWAY := [-0.46, -9.30, 1.62]
const PLATE_AT := [2.80, -6.90, 1.60]
## The turn the plate asks for: straight up the service spine.
const SPINE_FROM := [4.20, -9.10, 1.62]
const SPINE_AT := [5.10, -1.60, 1.50]
## The desk itself, at a standing hand's distance.
const DESK_FROM := [4.35, -2.90, 1.62]
const DESK_AT := [5.16, -2.10, 1.58]


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://k2a_shot"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	director = root.get("first_shift_director")
	detector = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	register = root.find_child("F01_NIGHT_REGISTER", true, false)
	plate = root.find_child("ServiceSpineDirection", true, false) as Node3D
	director.call("begin_first_shift")
	part = OS.get_environment("SHOT_PART")
	if part.is_empty():
		part = "a"

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	await get_tree().create_timer(1.6).timeout
	player.set_process(false)
	_freeze()

	if part == "a":
		await _part_a()
	else:
		await _part_b()
	Engine.time_scale = 1.0
	print("[K2A SHOT] part %s written to %s" % [part, out_dir])
	get_tree().quit(0)


func _part_a() -> void:
	# 1. ARRIVAL. The kerb, the rain, the neon, and one sentence of instruction.
	#    The director's own pose, untouched: this is literally where a new game
	#    puts a player on the first frame.
	await _snap("00_arrival_control_a")
	await _snap("00_arrival_control_b")

	# 2. THE FIRST READABLE INVITATION — and its own A/B. Same frame, same
	#    light, same everything, with the plate hidden and shown. Nothing else
	#    in the two frames differs, so the number between them is the plate.
	_look(DOORWAY, PLATE_AT, 72.0)
	# An INTERIOR A/A pair of its own. The arrival controls above are shot
	# through rain, and a rain shader answers to its own clock rather than to
	# `Engine.time_scale`, so those two frames have a floor and this pair says
	# what the floor is once the weather is off the lens.
	await _snap("01_doorway_control_a")
	await _snap("01_doorway_control_b")
	plate.visible = false
	await _snap("01_doorway_before")
	plate.visible = true
	await _snap("02_doorway_the_invitation")


func _part_b() -> void:
	# 3. THE TURN IT ASKS FOR. The whole working spine of the building on one
	#    axis, with the watchman's clock at the head of it.
	_look(SPINE_FROM, SPINE_AT, 66.0)
	await _snap("03_up_the_spine")

	# 4. THE PREMATURE ACTION, REFUSED PHYSICALLY. The spindle is bare, because
	#    nothing has been reported to a watchman who has not clocked in.
	_look(DESK_FROM, DESK_AT, 44.0)
	await _snap("04_desk_control_a")
	await _snap("04_desk_control_b")
	await _snap("04_refusal_the_spindle_is_empty")

	# 5. THE PHYSICAL RESPONSE. Clocking in puts paper on the spindle. Same
	#    camera as 04, so the frame changes by exactly the thing that changed.
	await _thaw()
	detector.call("interact_control", "detector", player)
	await get_tree().create_timer(0.5).timeout
	_freeze()
	await _snap("05_the_paper_is_on_the_spindle")

	# 6. THE REPORT HONESTLY IN HAND. The spindle is bare again for the right
	#    reason this time, and the card carries the night's actual intention.
	await _thaw()
	register.call("take_slip")
	await get_tree().create_timer(0.5).timeout
	_freeze()
	await _snap("06_the_report_in_hand")
	_look(SPINE_FROM, SPINE_AT, 66.0)
	await _snap("07_the_round_ahead")


func _freeze() -> void:
	Engine.time_scale = 0.0


func _thaw() -> void:
	Engine.time_scale = 1.0
	player.set_process(true)
	await get_tree().process_frame
	player.set_process(false)


func _look(from: Array, at: Array, fov: float) -> void:
	player.global_position = GameBoot.b2g(from) - player.camera.position
	player.camera.fov = fov
	player.camera.look_at(GameBoot.b2g(at), Vector3.UP)
	player.camera.make_current()


func _snap(label: String) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	print("[K2A SHOT] %s" % label)
