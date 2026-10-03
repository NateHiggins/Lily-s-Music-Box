extends Node
## Dispatch real H input in both production roots. Captures use SHOT_DIR,
## never ShotCapture's owner image collection.

const ROOTS := {
	"v1": preload("res://scenes/building/orison_root.tscn"),
	"v2": preload("res://scenes/building/orison_v2_runtime.tscn"),
}
var failures: Array[String] = []
var checks := 0
var directory: String


func _ready() -> void:
	_watchdog()
	call_deferred("_run")


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if DisplayServer.get_name() == "headless" or directory.is_empty():
		push_error("Capture visibility proof needs windowed SHOT_DIR")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(InputMap.has_action("capture_device_toggle"), "H action registered")
	for id: String in ROOTS:
		await _inspect_root(id)
	FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE).store_string(
			JSON.stringify({"evidence_class":"INERT", "checks":checks,
			"failures":failures, "roots":ROOTS.keys()}, "\t"))
	print("CAPTURE DEVICE: %d/%d passed" % [checks - failures.size(), checks])
	get_tree().quit(0 if failures.is_empty() else 1)


func _inspect_root(id: String) -> void:
	var world: Node3D = ROOTS[id].instantiate()
	add_child(world)
	await get_tree().create_timer(1.0).timeout
	var player: PlayerController = world.player
	var carrier := player.carried_device as ServiceSetCarrier
	_check(is_instance_valid(carrier), id + " mounts production service carrier")
	if carrier == null:
		world.free()
		return
	player.set_physics_process(false)
	player.camera.make_current()
	player.set_lamp_enabled(true)
	carrier.set_radio_powered(true)
	carrier.reading = true
	await get_tree().create_timer(.6).timeout
	var layer: CanvasLayer = carrier.get_node("ServiceSetPresentation")
	# The optical driver varies instantaneous output during warm-up and mains
	# fluctuation. The visibility toggle must preserve the authoritative setting.
	var energy := player._lamp_base_energy
	var light_range := player.flashlight.spot_range
	var lamp_pose := player.flashlight.global_transform
	var printed_count: int = carrier.device.printed_count
	var reports_before: int = carrier.device.teletype.reports.size()
	_check(not carrier.is_capture_hidden() and layer.visible,
			id + " fresh building starts with device visible")
	await _shot(id + "_01_visible")

	await _key(false)
	_check(carrier.is_capture_hidden() and not layer.visible,
			id + " real H hides device and physical paper")
	await _key(true)
	_check(carrier.is_capture_hidden(), id + " held H ignores auto-repeat")
	_check(carrier.reading and carrier.radio_is_powered(),
			id + " hiding retains reading pose and radio power")
	_check(carrier.beam_valid and carrier.is_processing() and player.flashlight.visible,
			id + " hidden carrier continues publishing live lamp pose")
	_check(player.lamp_is_enabled() and is_equal_approx(player._lamp_base_energy, energy)
			and is_equal_approx(player.flashlight.spot_range, light_range)
			and player.flashlight.global_transform.is_equal_approx(lamp_pose),
			id + " lamp output range and pose unchanged")
	_check(carrier.device.printed_count == printed_count
			and carrier.device.teletype.reports.size() == reports_before,
			id + " visibility does not receive or replay a report")
	await _shot(id + "_02_hidden")

	player.telegram_hud.present({"title":"CAPTURE REVIEW",
			"body":"The carried lamp remains active while this report prints out of view."})
	_check(carrier.device.printed_count == printed_count + 1,
			id + " shared presenter delivers one report while hidden")
	await get_tree().create_timer(.7).timeout
	var printer = carrier.device.teletype
	var glyphs: int = printer.printed_characters
	_check(glyphs > 0 and "out of view" in " ".join(printer.pages),
			id + " hidden printer advances and retains complete copy")
	player.set_mouse_released(true)
	await _key(false)
	_check(not carrier.is_capture_hidden() and layer.visible and player.mouse_released,
			id + " H restores device with pointer still released")
	_check(printer.printed_characters >= glyphs
			and carrier.device.printed_count == printed_count + 1,
			id + " restoring retains printing without redelivery")
	await _shot(id + "_03_restored")

	# Native text entry must consume H before a review shortcut sees it.
	var ui := CanvasLayer.new()
	add_child(ui)
	var field := LineEdit.new()
	field.position = Vector2(600, 20)
	field.size = Vector2(200, 35)
	ui.add_child(field)
	field.grab_focus()
	await get_tree().process_frame
	await _key(false)
	_check(field.text == "h" and not carrier.is_capture_hidden(),
			id + " focused text entry owns H")
	ui.free()
	player.set_mouse_released(false)
	await _key(false)
	_check(carrier.is_capture_hidden() and not layer.visible,
			id + " repeat toggle hides again after text entry closes")
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	await get_tree().process_frame


func _key(echo: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_H
	event.physical_keycode = KEY_H
	event.unicode = 104
	event.pressed = true
	event.echo = echo
	get_viewport().push_input(event, true)
	event.pressed = false
	event.echo = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("CAPTURE DEVICE ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)


func _watchdog() -> void:
	await get_tree().create_timer(150.0).timeout
	printerr("CAPTURE DEVICE FAIL watchdog")
	get_tree().quit(1)
