extends Node
## K2-C proof sequence — the first step, from the real acceptance pose.
##
##     $env:SHOT_DIR="<abs>"
##     tools/run_godot_serial.ps1 -Scene res://tests/FirstStepShot.tscn `
##         -ProjectPath <checkout>/game -Windowed
##
## ONE FROZEN INSTANT. The shift is opened and the paper taken while thawed;
## then time stops and every frame below is an A/B on that instant, so nothing
## in the room can drift between two frames that are being compared.
##
## NO AUDIO IS CLAIMED HERE. The chirp's behaviour is proved in state by the
## focused and live suites; a still frame cannot show a sound, and the whole
## point of this increment is that the sound was not reaching the player.

var root: Node3D
var player: PlayerController
var director: Node
var tracker: Node
var guard: Node
var out_dir := ""

## Where the paper actually comes off the spindle.
const ACCEPTANCE_FROM := [4.28, -2.10, 1.62]
const ACCEPTANCE_AT := [5.16, -2.30, 1.55]
## The card exactly as it read before this increment, for a like-for-like A/B.
const OLD_CARD := "Follow the chirp to the 2A point and open the grille. " \
		+ "Before you leave the lobby, take the TOUR KEY from its hook. It " \
		+ "opens no door. On the way, work STATION 2 if you see it. The mark " \
		+ "is evidence, not permission."


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://k2c_shot"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root = load("res://scenes/building/orison_root.tscn").instantiate() as Node3D
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	player = root.get("player") as PlayerController
	director = root.get("first_shift_director")
	tracker = root.get("objective_tracker")
	guard = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)

	director.call("begin_first_shift")
	detector.call("interact_control", "detector", player)
	register.call("take_slip")

	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	_look(ACCEPTANCE_FROM, ACCEPTANCE_AT, 70.0)
	await get_tree().create_timer(1.6).timeout
	player.set_process(false)
	Engine.time_scale = 0.0

	var title := str(tracker._title.text)
	var new_card := str(tracker._objective.text)

	# A/A at the acceptance pose. Nothing is touched between these two.
	await _snap("00_acceptance_control_a")
	await _snap("00_acceptance_control_b")

	# THE CUE BECOMING LEGIBLE. Same instant, same light, same room — the only
	# thing that differs between these two frames is the sentence.
	tracker.call("show_objective", title, OLD_CARD)
	await _snap("01_three_instructions")
	tracker.call("show_objective", title, new_card)
	await _snap("02_one_first_step")

	# A LAWFUL ALTERNATE ORDER: the key taken second. The first step does not
	# change; only the key's own clause retires, because it is in the pocket.
	guard.call("take_key")
	director.call("present_resume")
	await _snap("03_a_lawful_alternate_order")

	# THE OPTIONAL STATION IS NOT A GATE. A mark is recorded through its own
	# owner and the first step is untouched by it.
	guard.call("return_key")
	director.call("observe_central_signal", 2, 1)
	director.call("present_resume")
	await _snap("04_the_optional_mark_is_not_a_gate")

	# ABORT / RESTORATION: the card is cleared and rebuilt from the owners
	# alone. Nothing is stored, so nothing has to be put back.
	tracker.call("clear")
	await _snap("05_cleared")
	director.call("present_resume")
	await _snap("06_rebuilt_from_the_owners")

	Engine.time_scale = 1.0
	print("[K2C SHOT] written to %s" % out_dir)
	get_tree().quit(0)


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
	print("[K2C SHOT] %s" % label)
