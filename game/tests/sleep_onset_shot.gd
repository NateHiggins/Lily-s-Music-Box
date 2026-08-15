extends Node
## N5 production-camera A/A/B/C: untouched waking frame, half warning and the
## last legible gradual frame before DreamDirector entry.

var shell: CampaignShell
var root: Node3D
var pressure: SleepPressureDirector
var failures := 0
var _frame_serial := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.dream_seed = "f123456789abcdef"
	shell = CampaignShell.new()
	shell.sleep_manual_clock = true
	add_child(shell)
	await get_tree().create_timer(2.0).timeout
	root = shell.active_world
	pressure = shell.sleep_pressure
	var player: PlayerController = root.player
	player.global_position = GameBoot.b2g([0.0, 0.0, 9.82])
	player.velocity = Vector3.ZERO
	player.look_at(GameBoot.b2g([0.0, 8.2, 10.85]))
	await get_tree().create_timer(1.0).timeout
	player.set_physics_process(false)
	if root.resident_routines:
		root.resident_routines.set_process(false)
	if root.sanity:
		root.sanity.stand_down()
	if root.light_rig:
		root.light_rig.set_process(false)
	if root.day_night_director:
		root.day_night_director.set_process(false)
	if root.street_traffic:
		root.street_traffic.set_process(false)
	player.camera.make_current()
	_check(player.sleep_entry_body_is_stable(),
			"the F04 production camera stands on a stable floor")
	shell.core_loop.dream_requested.emit("mina_caption_crisis",
			"mina_release_print", {
				"eligible_after_stage": "repaired",
				"protected_contexts": ["call", "conversation"],
			})
	_check(shell.dream_director.phase() == "armed",
			"the production shell holds the Mina request armed")
	await _capture("00_control_a")
	await _capture("01_control_b")
	pressure.advance_for_test(1.3)
	_check(is_equal_approx(pressure.pressure(), 0.5),
			"the midpoint frame is exact")
	await _capture("02_gradual_midpoint")
	pressure.advance_for_test(1.0)
	_check(pressure.pressure() > 0.88 and pressure.pressure() < 0.89,
			"the late frame remains before scene replacement")
	await _capture("03_gradual_late")
	print("[N5 ONSET SHOT] %s" % (
			"PASS" if failures == 0 else "FAIL %d" % failures))
	get_tree().quit(failures)


func _capture(stem: String) -> void:
	var expected := _frame_serial + 1
	RenderingServer.frame_post_draw.connect(_mark_frame, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + 2500
	while _frame_serial < expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(_mark_frame):
		RenderingServer.frame_post_draw.disconnect(_mark_frame)
	if _frame_serial < expected:
		_check(false, "%s rendered a frame" % stem)
		return
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(stem + ".png"))
	_check(error == OK, "%s frame saved" % stem)


func _mark_frame() -> void:
	_frame_serial += 1


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [n5 shot ok] ", label)
	else:
		failures += 1
		push_error("[N5 ONSET SHOT] " + label)
