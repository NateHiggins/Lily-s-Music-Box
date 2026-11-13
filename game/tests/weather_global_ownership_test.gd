extends Node
## Isolated rendered probe of real extension.publish + manager tree retirement.
## No world, clock, HTTP service, noise allocation or weather simulation setup.
const Manager := preload("res://scripts/building/WeatherManager.gd")
const Extension := preload("res://scripts/building/queens_weather_extension.gd")
const ErrorCapture := preload("res://tests/guide_bell_error_capture.gd")
const CHANNEL_TOLERANCE := 0.015

class MinimalManager extends Manager:
	func _ready() -> void:
		# Only the unrelated startup is bypassed. _exit_tree is inherited intact.
		set_process(false)

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var _view: SubViewport
var _sky: ShaderMaterial
var _started := 0
var _executed := false
var _initial_inputs: Dictionary = {}
var _final_inputs: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok:
		failures.append(label)
	print("WEATHER GLOBAL OWNERSHIP: ", label, " = ", ok)


func _manager() -> MinimalManager:
	var manager := MinimalManager.new()
	manager.extreme_weather = Extension.new()
	add_child(manager)
	return manager


func _publish(manager: MinimalManager, wet: float, blood: float) -> void:
	manager.extreme_weather.wetness = wet
	manager.extreme_weather.blood_deposit = blood
	# Actual production publication; the sky is a parameter sink, not a copy
	# of its publisher or a substitute setter for either global.
	manager.extreme_weather.publish(_sky, Vector3.ZERO)


func _probe() -> void:
	_sky = ShaderMaterial.new()
	_view = SubViewport.new()
	_view.size = Vector2i(8, 8)
	_view.disable_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
global uniform float wetness;
global uniform float weather_blood;
void fragment() { COLOR = vec4(wetness, weather_blood, 0.0, 1.0); }
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var panel := ColorRect.new()
	panel.size = Vector2(8, 8)
	panel.material = material
	_view.add_child(panel)


func _sample(label: String) -> Color:
	# Pinned Godot forbids global_shader_parameter_get outside the editor.
	# Render actual globals instead. Reference samples avoid sRGB assumptions.
	for frame in 2:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := _view.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(8, 8):
		check(false, label + ": rendered global probe is available")
		return Color(-1, -1, -1, 1)
	var colour := image.get_pixel(4, 4)
	observations.append({"label": label, "wetness_channel": colour.r, "blood_channel": colour.g})
	return colour


func _same_channels(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= CHANNEL_TOLERANCE and absf(actual.g - expected.g) <= CHANNEL_TOLERANCE


func _run() -> void:
	_started = Time.get_ticks_msec()
	var logger := ErrorCapture.new()
	OS.add_logger(logger)
	_initial_inputs = _source_snapshot()
	check(DisplayServer.get_name() != "headless", "windowed renderer is required for actual global sampling")
	if DisplayServer.get_name() != "headless":
		_probe()
		var zero: Color = await _sample("initial globals")
		check(absf(zero.r) <= CHANNEL_TOLERANCE and absf(zero.g) <= CHANNEL_TOLERANCE, "isolated scene starts with both globals reset")
		var first := _manager()
		_publish(first, 0.23, 0.41)
		var prior: Color = await _sample("first publisher reference")
		var latest := _manager()
		_publish(latest, 0.67, 0.79)
		var current: Color = await _sample("latest publisher reference")
		check(prior.r > 0.05 and prior.g > 0.05 and current.r > prior.r + 0.05 and current.g > prior.g + 0.05,
				"probe independently distinguishes both published channels and owners")
		var unpublished := _manager()
		unpublished.free()
		check(_same_channels(await _sample("after unpublished manager retirement"), current), "unpublished manager retirement leaves current globals unchanged")
		# Retiring a publisher that is not current must not blank the survivor.
		first.free()
		check(_same_channels(await _sample("after prior publisher retirement"), current), "non-owner retirement preserves latest wetness and blood")
		latest.free()
		check(_same_channels(await _sample("after last publisher retirement"), zero), "last owner retirement resets both globals")
		# A repeated current publication must not erase the older live publisher.
		first = _manager()
		_publish(first, 0.23, 0.41)
		latest = _manager()
		_publish(latest, 0.67, 0.79)
		_publish(latest, 0.67, 0.79)
		check(_same_channels(await _sample("after duplicate latest publish"), current), "duplicate republish still presents current owner")
		latest.free()
		check(_same_channels(await _sample("after duplicate publisher retirement"), prior), "latest retirement restores surviving prior publisher despite duplicate republish")
		first.free()
		check(_same_channels(await _sample("after restored owner retirement"), zero), "restored final owner retirement resets both globals")
		# A still-live earlier owner can publish again and become the current one.
		first = _manager()
		_publish(first, 0.23, 0.41)
		latest = _manager()
		_publish(latest, 0.67, 0.79)
		_publish(first, 0.23, 0.41)
		check(_same_channels(await _sample("after older live owner republishes"), prior), "older live owner republishing becomes latest")
		first.free()
		check(_same_channels(await _sample("after republished owner retires"), current), "republished owner retirement restores other surviving publisher")
		latest.free()
		check(_same_channels(await _sample("after republish scenario cleanup"), zero), "republish scenario last owner resets both globals")
		# Remove a middle publisher, then restore the oldest surviving owner.
		first = _manager()
		_publish(first, 0.23, 0.41)
		var middle := _manager()
		_publish(middle, 0.45, 0.57)
		latest = _manager()
		_publish(latest, 0.67, 0.79)
		middle.free()
		check(_same_channels(await _sample("after middle publisher retirement"), current), "middle retirement preserves latest publisher")
		latest.free()
		check(_same_channels(await _sample("after latest with retired middle"), prior), "latest retirement skips retired middle and restores live prior owner")
		first.free()
		check(_same_channels(await _sample("final cleanup"), zero), "all fixture publishers retire with both globals reset")
		_executed = true
		_view.free()
		_sky = null
	_final_inputs = _source_snapshot()
	check(_initial_inputs == _final_inputs, "runtime, repository and LF-normalized fixture sources remain stable throughout execution")
	check(logger.errors.is_empty(), "actual publication, rendered probe and inherited teardown report no engine errors")
	_write_contract(logger.errors)
	print("WEATHER GLOBAL OWNERSHIP RESULT: ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks.size())
	OS.remove_logger(logger)
	get_tree().quit(0 if failures.is_empty() else 1)


func _source_snapshot() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var digest: Array = []
	var head: Array = []
	check(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], digest) == 0 and not digest.is_empty(), "bind production runtime digest")
	check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "record repository provenance")
	var runtime := str(digest[0]).strip_edges() if not digest.is_empty() else ""
	var revision := str(head[0]).strip_edges() if not head.is_empty() else ""
	check(runtime.length() == 64 and revision.length() == 40, "runtime digest and repository provenance are complete")
	var sources: Dictionary = {}
	for path: String in [get_script().resource_path, scene_file_path, "res://tests/guide_bell_error_capture.gd",
			"res://scripts/building/WeatherManager.gd", "res://scripts/building/queens_weather_extension.gd", "res://project.godot"]:
		check(not path.is_empty() and FileAccess.file_exists(path), "source dependency exists: " + path)
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		sources["game/" + path.trim_prefix("res://")] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	check(sources.get("game/tests/weather_global_ownership_test.gd", "") == get_script().source_code.replace("\r\n", "\n").sha256_text(), "loaded fixture matches LF source on disk")
	return {"runtime": runtime, "repository_head": revision, "dependencies_lf_sha256": sources}


func _write_contract(engine_errors: Array[String]) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(), "explicit contract destination is supplied")
	if directory.is_empty():
		return
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "contract destination is available")
	var target := directory.path_join("weather_global_ownership_contract.json")
	var pending := target + ".pending"
	check(not FileAccess.file_exists(target) and not FileAccess.file_exists(pending), "fresh contract paths preserve earlier run evidence")
	if FileAccess.file_exists(target) or FileAccess.file_exists(pending):
		return
	var file := FileAccess.open(pending, FileAccess.WRITE)
	check(file != null, "pending contract file opens")
	if file == null:
		return
	var dependencies: Dictionary = _final_inputs.get("dependencies_lf_sha256", {})
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": false,
		"scope": "Rendered shared wetness/blood globals through actual QueensWeatherExtension publication and inherited WeatherManager tree retirement; minimal startup override, no occupied world, weather simulation, visual surface acceptance or performance qualification",
		"execution": {"completed": _executed, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - _started) / 1000.0},
		"source": {"test_path": "game/tests/weather_global_ownership_test.gd", "test_sha256": dependencies.get("game/tests/weather_global_ownership_test.gd", ""),
			"test_scene_path": "game/tests/WeatherGlobalOwnershipTest.tscn", "test_scene_lf_sha256": dependencies.get("game/tests/WeatherGlobalOwnershipTest.tscn", ""),
			"error_capture_lf_sha256": dependencies.get("game/tests/guide_bell_error_capture.gd", ""),
			"runtime_inputs_sha256": _final_inputs.get("runtime", ""), "repository_head": _final_inputs.get("repository_head", ""),
			"test_dependencies_lf_sha256": dependencies, "before": _initial_inputs, "after": _final_inputs},
		"contracts": {"weather_global_ownership": {"executed": _executed, "status": "PASS" if failures.is_empty() and _executed else "FAIL"}},
		"checks": checks, "failures": failures, "observations": observations, "engine_errors": engine_errors}
	var serialized := JSON.stringify(result, "\t")
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	# Publication success cannot be asserted inside the bytes being written.
	# Only publish a completed receipt after flush and exact readback succeed;
	# failures leave the provisional .pending evidence and force a failing exit.
	if write_error != OK or FileAccess.get_file_as_string(pending) != serialized:
		check(false, "contract flush/readback failed; no completed receipt published")
		return
	if DirAccess.rename_absolute(pending, target) != OK:
		check(false, "contract publication failed; pending evidence retained")
		return
	print("WEATHER GLOBAL OWNERSHIP CONTRACT PUBLISHED: ", target)
