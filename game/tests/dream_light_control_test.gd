extends Node
## N3 Gate-B measurement. Every scenario in a pair uses the same seed and the
## same corridor; only the public lamp state changes.

const SEEDS: Array[int] = [7, 19, 43, 71, 101, 131, 163, 199, 251, 307, 379]
const STEP_S := 1.0 / 120.0

var _fails := 0
var _harness: DreamLightControlHarness


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_harness = DreamLightControlHarness.new()
	_harness.name = "N3DisposableControl"
	add_child(_harness)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_check("control corridor is exactly 3.20 x 42.00 x 3.00 m",
			is_equal_approx(_harness.CORRIDOR_WIDTH_M, 3.20)
			and is_equal_approx(_harness.CORRIDOR_LENGTH_M, 42.0)
			and is_equal_approx(_harness.CORRIDOR_HEIGHT_M, 3.0))
	_check("the pursuer is one invisible navigation body",
			_harness.tenant_body is CharacterBody3D
			and _visible_geometry_count(_harness.tenant_body) == 0)
	_check("the diagnostic proxy contributes shadows only",
			_harness.shadow_proxy.cast_shadow ==
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)

	var on_times: Array[float] = []
	var dark_times: Array[float] = []
	var extinguished_times: Array[float] = []
	var rows: Array[String] = [
			"seed,light_on_s,light_off_s,extinguished_after_acquisition_s,buy_s"]
	for seed in SEEDS:
		var light_on := _run_scenario(seed, "on")
		var light_off := _run_scenario(seed, "off")
		var extinguished := _run_scenario(seed, "extinguish")
		on_times.append(light_on)
		dark_times.append(light_off)
		extinguished_times.append(extinguished)
		rows.append("%d,%.3f,%.3f,%.3f,%.3f" % [seed, light_on,
				light_off, extinguished, extinguished - light_on])

	var on_median := _median(on_times)
	var dark_median := _median(dark_times)
	var extinguished_median := _median(extinguished_times)
	var shortening := 1.0 - on_median / dark_median
	var bought := extinguished_median - on_median
	_check("light-on shortens median survival by at least one third (%.1f%%)"
			% (shortening * 100.0), shortening >= 1.0 / 3.0)
	_check("extinguishing after acquisition buys at least six seconds (%.2f s)"
			% bought, bought >= 6.0)
	_check("darkness delays capture but never creates an indefinite safe state",
			dark_times.all(func(value: float) -> bool:
				return value > on_median and value < _harness.MAX_RUN_S))

	_harness.prepare_opaque_control(true)
	await get_tree().physics_frame
	_check("an opaque collision body blocks light acquisition",
			not _harness.scan_light_once())
	_harness.prepare_opaque_control(false)
	await get_tree().physics_frame
	_check("the same lamp acquires around the wall's open end",
			_harness.scan_light_once())

	await _prove_input_parity()
	_write_results(rows, on_median, dark_median, extinguished_median,
			shortening, bought)
	print(("[DREAM LIGHT N3] medians on=%.3f off=%.3f extinguish=%.3f "
			+ "shortening=%.1f%% buy=%.3fs result=%s") % [on_median,
			dark_median, extinguished_median, shortening * 100.0, bought,
			"PASS" if _fails == 0 else "FAIL"])
	get_tree().quit(_fails)


func _run_scenario(seed: int, mode: String) -> float:
	_harness.reset_run(seed, mode != "off")
	var extinguished := false
	while not _harness.captured and _harness.elapsed_s < _harness.MAX_RUN_S:
		_harness.advance_fixed(STEP_S)
		if mode == "extinguish" and _harness.acquired and not extinguished \
				and _harness.elapsed_s >= _harness.acquisition_time_s + 0.15:
			_harness.set_light_enabled(false)
			extinguished = true
	return _harness.capture_time_s if _harness.captured \
			else _harness.MAX_RUN_S


func _prove_input_parity() -> void:
	var player := PlayerController.new()
	player.name = "InputContractPlayer"
	add_child(player)
	player.call_locked = true
	await get_tree().process_frame

	player.set_lamp_enabled(true)
	Input.action_press("lamp_toggle")
	player._process(0.0)
	Input.action_release("lamp_toggle")
	_check("keyboard action reaches PlayerController.toggle_lamp",
			not player.lamp_is_enabled())

	player.set_lamp_enabled(true)
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	joy_event.pressed = true
	_check("left shoulder is mapped to the shared lamp action",
			InputMap.event_is_action(joy_event, "lamp_toggle"))
	Input.parse_input_event(joy_event)
	Input.flush_buffered_events()
	_check("a physical left-shoulder event presses the shared action",
			Input.is_action_pressed("lamp_toggle"))
	player._process(0.0)
	var joy_release := InputEventJoypadButton.new()
	joy_release.button_index = JOY_BUTTON_LEFT_SHOULDER
	joy_release.pressed = false
	Input.parse_input_event(joy_release)
	Input.flush_buffered_events()
	_check("controller action reaches the same public lamp owner",
			not player.lamp_is_enabled())

	# Let the controller edge retire before the touch HUD presses the same
	# action; the two devices deliberately converge on one InputMap state.
	await get_tree().create_timer(0.05).timeout
	player.set_lamp_enabled(true)
	var touch := TouchControls.new()
	touch.name = "InputContractTouch"
	add_child(touch)
	await get_tree().process_frame
	touch.set_enabled(true)
	var lamp_button: Dictionary = {}
	for button in touch._buttons:
		if str(button.get("action", "")) == "lamp_toggle":
			lamp_button = button
			break
	if lamp_button.is_empty():
		_check("touch publishes a lamp control", false)
	else:
		touch._press(17, lamp_button["centre"])
		_check("touch lamp button presses the shared action",
				Input.is_action_pressed("lamp_toggle"))
		player._process(0.0)
		touch._release(17)
		_check("touch reaches the same public lamp owner",
				not player.lamp_is_enabled())
	touch.set_enabled(false)
	player.queue_free()
	touch.queue_free()


func _visible_geometry_count(node: Node) -> int:
	var count := 0
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		if geometry.cast_shadow != \
				GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			count += 1
	for child in node.get_children():
		count += _visible_geometry_count(child)
	return count


func _median(values: Array[float]) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[ordered.size() / 2]


func _write_results(rows: Array[String], on_median: float,
		dark_median: float, extinguished_median: float, shortening: float,
		bought: float) -> void:
	var output_dir := OS.get_environment("N3_RESULT_DIR")
	if output_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	rows.append("median,%.3f,%.3f,%.3f,%.3f" % [on_median, dark_median,
			extinguished_median, bought])
	rows.append("shortening_percent,%.3f" % (shortening * 100.0))
	var file := FileAccess.open(output_dir.path_join("capture_times.csv"),
			FileAccess.WRITE)
	if file:
		file.store_string("\n".join(rows) + "\n")
