extends Node
## Preview directly under the engine clock. Run separately with
## ORISON_CINEMA_PREVIEW_PROBE=expected_failure for the deliberate error paths.

const Manager := preload("res://film/cinema_render_manager.gd")

var _manager := Manager.new()
var _visible_layer := CanvasLayer.new()
var _hidden_item := Control.new()
var _frames: Array[int] = []
var _rates: Array[int] = []
var _completions: Array[int] = []
var _errors: Array[String] = []
var _hud_hidden_on_all_frames := true
var _checks := 0
var _failures := 0


func _ready() -> void:
	add_child(_manager)
	add_child(_visible_layer)
	add_child(_hidden_item)
	_hidden_item.hide()
	_manager.frame_requested.connect(_on_frame)
	_manager.finished.connect(func(frames: int): _completions.append(frames))
	_manager.failed.connect(func(reason: String): _errors.append(reason))
	_run.call_deferred()


func _on_frame(index: int, fps: int) -> void:
	_frames.append(index)
	_rates.append(fps)
	_hud_hidden_on_all_frames = _hud_hidden_on_all_frames and not _visible_layer.visible and not _hidden_item.visible


func _check(result: bool, label: String) -> void:
	_checks += 1
	if not result:
		_failures += 1
		print("  FAIL  ", label)


func _wait_for_completion(total: int) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while _completions.size() < total and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _run() -> void:
	var probe := OS.get_environment("ORISON_CINEMA_PREVIEW_PROBE")
	var hud := [_visible_layer, _hidden_item]
	var directory := ProjectSettings.globalize_path("user://preview_stems_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var master := AudioServer.get_bus_index("Master")
	var effects := AudioServer.get_bus_effect_count(master)
	_check(not DirAccess.dir_exists_absolute(directory), "fresh stem sentinel path")
	if probe == "expected_failure":
		# Both failures intentionally produce engine error lines. This mode
		# is separate from the clean acceptance run.
		_check(_manager.start_capture(3, 24, false, hud, PackedStringArray(["Master"]), directory, false) != OK,
				"preview refuses a stem request")
		_check(_errors == ["Sample-aligned stem recording requires MovieWriter."], "reported the expected refusal")
		_check(_frames.is_empty() and _visible_layer.visible and not _hidden_item.visible, "refusal precedes any frame or HUD change")
		_check(_manager.start_capture(30, 24, false, hud, PackedStringArray(), directory, false) == OK,
				"starts interrupted preview")
		var deadline := Time.get_ticks_msec() + 3500
		while _frames.size() < 2 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_check(_frames.size() >= 2 and _frames.size() < 30, "interrupts between authored frames")
		_manager.cancel_capture()
		var interrupted_at := _frames.size()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(_errors.size() == 2 and _errors.back() == "Film capture was cancelled.", "cancel signaled once")
		_check(_completions.is_empty() and _frames.size() == interrupted_at, "cancel prevents completion and further frames")
	else:
		_check(probe.is_empty(), "requested a recognized preview probe")
		_check(_manager.start_capture(5, 24, false, hud, PackedStringArray(), directory, false) == OK, "starts native preview")
		_check(_frames == [0] and not _manager.is_rendering_film, "synchronous first preview frame")
		_check(_manager.start_capture(1, 60, false) == ERR_BUSY, "rejects a concurrent owner")
		await _wait_for_completion(1)
		_check(_frames == [0, 1, 2, 3, 4] and _rates == [24, 24, 24, 24, 24], "24 fps consecutive indices and rate")
		_check(_completions == [5] and _errors.is_empty(), "first preview completed once")
		_check(_visible_layer.visible and not _hidden_item.visible, "first run restored distinct visibility states")
		_frames.clear()
		_rates.clear()
		_check(_manager.start_capture(1, 60, false, hud, PackedStringArray(), directory, false) == OK, "reuses manager for a one-frame take")
		await _wait_for_completion(2)
		await get_tree().process_frame
		_check(_frames == [0] and _rates == [60] and _completions == [5, 1], "first and final indices coincide exactly once")
		_check(_errors.is_empty(), "preview signaled no failures")
	_check(_hud_hidden_on_all_frames, "HUD stayed hidden when frames were applied")
	_check(_visible_layer.visible and not _hidden_item.visible, "restored both HUD nodes")
	_check(AudioServer.get_bus_effect_count(master) == effects and not DirAccess.dir_exists_absolute(directory),
			"preview left the master bus and stem output untouched")
	var label := "expected_failure" if probe == "expected_failure" else "preview"
	print("CINEMA RENDER MANAGER: %s mode=%s checks=%d failures=%d" % ["PASS" if _failures == 0 else "FAIL", label, _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
