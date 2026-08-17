extends Node
## The service lamp's warm-up bloom and its pop, sampled frame by frame.
##
##     SHOT_DIR=<abs> godot --path game res://tests/LampCycleShot.tscn
##
## A tungsten lamp does not fade on and fade off. Cold filament is a low
## resistance, so switching on draws an inrush: the lamp overshoots and then
## settles, climbing through red and amber to its working warm white. Switching
## off is the same physics backwards and four times faster, which is why it
## pops — the filament flares as the current collapses and then lets go down
## the colour ramp it came up.
##
## These frames sample that cycle against a real wall so the curve can be read
## rather than described. The last row is the whole point of the guard: mashing
## the switch must never produce a strobe, so the transient is rate-limited
## while the SWITCH itself stays instant and ungated.

## Frames written as images. Everything else is traced as numbers.
const KEEP_FRAMES := [4, 8, 14, 24]

var _root: Node3D
var _player: PlayerController
var _out := ""


func _ready() -> void:
	_out = OS.get_environment("SHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(_root)
	await get_tree().create_timer(2.0).timeout
	_hide_capture_ui(get_tree().root)
	_player = _root.find_child("PlayerController", true, false)
	if _player == null:
		for child in _root.get_children():
			if child is PlayerController:
				_player = child
	if _player == null:
		printerr("[LAMP CYCLE] no player")
		get_tree().quit(1)
		return
	# A corridor wall a couple of metres off, so the beam has something to
	# land on and the colour ramp is legible on plaster.
	_player.global_position = GameBoot.b2g([4.3, 0.6, 0.1])
	_player.rotation.y = 0.0
	_player.camera.make_current()
	await get_tree().create_timer(0.6).timeout

	# Settle dark first, past the rate limiter, so the warm-up starts cold.
	_player.set_lamp_enabled(false)
	await get_tree().create_timer(1.2).timeout

	print("[LAMP CYCLE] warm-up")
	_player.set_lamp_enabled(true)
	await _sample("on", 34)
	await get_tree().create_timer(1.2).timeout

	print("[LAMP CYCLE] pop")
	_player.set_lamp_enabled(false)
	await _sample("off", 22)
	print("[LAMP CYCLE] frames saved")
	get_tree().quit(0)


## Capture at wall-clock offsets from the toggle. The energy is printed beside
## every frame so the curve is a table as well as a picture — a still cannot
## show an overshoot, only a brightness.
## SAMPLE BY FRAME, NOT BY CLOCK, and record what the frame actually cost.
##
## The first version waited on `create_timer` at 20 ms intervals and reported
## the pop as over almost instantly — which sent me tuning a curve that was
## fine. This scene runs 27 ms frames, so a 20 ms timer resolves a frame or
## more late and every "offset" was a fiction. The lamp advances on `_process`
## delta, so the only honest clock here is the frame's own.
##
## Each frame is captured and its true elapsed time printed beside the energy,
## and the peak is reported at the end because an overshoot is a single frame
## and a table of fixed offsets will always miss it.
func _sample(tag: String, frames: int) -> void:
	var elapsed := 0.0
	var peak := 0.0
	var peak_at := 0.0
	for i in frames:
		await RenderingServer.frame_post_draw
		elapsed += get_process_delta_time()
		var energy: float = _player.flashlight.light_energy
		var colour: Color = _player.flashlight.light_color
		if energy > peak:
			peak = energy
			peak_at = elapsed
		# WRITING A PNG COSTS ~100 ms OF FRAME, which is more than the pop
		# lasts. Saving every frame made the sampler slower than its subject
		# and hid the very transient it was built to show, so only a few
		# frames are written and the curve itself is traced numerically at
		# whatever rate the scene really runs.
		var label := "%s_%02d_t%03dms" % [tag, i, int(elapsed * 1000.0)]
		if i in KEEP_FRAMES:
			get_viewport().get_texture().get_image().save_png(
					_out.path_join(label + ".png"))
		print("   %-18s energy %5.3f  colour %s  visible %s  lamp_is_enabled %s"
				% [label, energy, colour.to_html(false),
				_player.flashlight.visible, _player.lamp_is_enabled()])
	print("   %s PEAK %5.3f at %d ms  (settled base %5.3f)"
			% [tag, peak, int(peak_at * 1000.0), _player._lamp_base_energy])


func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer or node is Label3D:
		node.visible = false
	for child in node.get_children():
		_hide_capture_ui(child)
