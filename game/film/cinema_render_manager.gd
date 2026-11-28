class_name CinemaRenderManager
extends Node
## Frame clock for a dedicated film scene. Connect before calling start_capture
## in the initial scene's _ready. Frame zero is delivered synchronously. Positive
## frame numbers are consecutive. The scene owns all presentation at that index.
## MovieWriter owns stereo master audio, output dimensions and image encoding.
signal frame_requested(frame_index: int, fps: int)
signal finished(frames: int)
signal failed(reason: String)

var is_rendering_film := false
var _active := false
var _last_requested := false
var _movie := false
var _quit_on_finish := true
var _first_tick := true
var _frame := 0
var _count := 0
var _fps := 0
var _preview_time := 0.0
var _hud_visibility := {}
var _taps := {}
var _sample_rate := 0
var _stem_samples := 0


func _ready() -> void:
	set_process(false)


## Pass only HUD CanvasItems or CanvasLayers owned by the film fixture; diegetic
## displays and subtitles can be left in the shot. Movie mode requires a fresh
## process with --write-movie <movie.png> --fixed-fps <fps>. Preview has no stems.
func start_capture(frame_count: int, fps: int, require_movie: bool,
		hud_nodes: Array = [], stem_buses: PackedStringArray = [],
		stem_dir: String = "", quit_on_finish: bool = true) -> Error:
	if _active:
		return ERR_BUSY
	if not is_inside_tree() or frame_count < 1 or fps < 1:
		return _reject("Capture needs a scene, positive frame count and positive FPS.")
	var has_writer := not Engine.get_write_movie_path().is_empty()
	if has_writer != require_movie:
		return _reject("Capture mode does not match the engine's startup MovieWriter.")
	if has_writer and (Engine.get_process_frames() != 0 or not quit_on_finish):
		return _reject("Movie capture must own the initial scene and final process exit.")
	if not has_writer and not stem_buses.is_empty():
		return _reject("Sample-aligned stem recording requires MovieWriter.")
	for node in hud_nodes:
		if not is_instance_valid(node) or not (node is CanvasItem or node is CanvasLayer):
			return _reject("Invalid film HUD node.")
	if not stem_buses.is_empty():
		var problem := _open_stems(stem_buses, stem_dir, frame_count, fps)
		if not problem.is_empty():
			_release_taps()
			return _reject(problem)
	_count = frame_count
	_fps = fps
	_frame = 0
	_first_tick = true
	_last_requested = false
	_preview_time = 0.0
	_movie = has_writer
	_quit_on_finish = quit_on_finish
	_active = true
	is_rendering_film = has_writer
	process_mode = Node.PROCESS_MODE_ALWAYS
	for node in hud_nodes:
		if not _hud_visibility.has(node):
			_hud_visibility[node] = node.visible
			node.visible = false
	set_process(true)
	frame_requested.emit(0, _fps)
	return OK


func _reject(reason: String) -> Error:
	push_error(reason)
	failed.emit(reason)
	return ERR_INVALID_PARAMETER


func _process(delta: float) -> void:
	if not _active:
		return
	if _movie:
		# MovieWriter appends one frame per main iteration. Godot can clamp
		# process delta even during fixed-FPS capture. Drive the picture by
		# index; the launcher checks native movie FPS and decoded duration.
		var problem := _drain_stems()
		if not problem.is_empty():
			_fail_capture(problem)
			return
		if not _first_tick:
			_frame += 1
			frame_requested.emit(_frame, _fps)
		_first_tick = false
		if _active and _frame == _count - 1:
			# Main::iteration renders and MovieWriter mixes this last frame
			# after SceneTree::process returns. Keep HUD and taps until exit.
			_last_requested = true
			set_process(false)
			get_tree().quit()
		return
	if _first_tick:
		_first_tick = false
		return
	_preview_time += delta
	var target := mini(_count - 1, floori(_preview_time * _fps))
	while _active and _frame < target:
		_frame += 1
		frame_requested.emit(_frame, _fps)
	if _active and _preview_time >= float(_count) / _fps:
		var tree := get_tree()
		_finish_capture()
		if _quit_on_finish:
			tree.quit()


## End preview early or terminate an interrupted movie without a success signal.
func cancel_capture() -> void:
	if _active:
		_fail_capture("Film capture was cancelled.")


func _exit_tree() -> void:
	if not _active:
		return
	if _movie and _last_requested:
		var problem := _finalize_stems()
		if not problem.is_empty():
			_fail_capture(problem)
			return
		_finish_capture()
	else:
		_fail_capture("Film scene exited before the final frame.")


func _finish_capture() -> void:
	_restore()
	finished.emit(_count)


func _fail_capture(reason: String) -> void:
	var terminate := _movie and is_inside_tree()
	_restore()
	push_error(reason)
	if terminate:
		get_tree().quit(1)
	failed.emit(reason)


func _restore() -> void:
	_active = false
	is_rendering_film = false
	set_process(false)
	_release_taps()
	for node in _hud_visibility:
		if is_instance_valid(node):
			node.visible = _hud_visibility[node]
	_hud_visibility.clear()


## One append-only tap per existing stereo bus, after its effects and before its
## fader/send. Parent and child buses overlap. Never sum both as independent
## sources. Use a new case directory. A failed take keeps only unfinished .part
## files unless the filesystem fails during final publication.
func _open_stems(buses: PackedStringArray, directory: String, count: int, fps: int) -> String:
	if not directory.is_absolute_path() or directory.begins_with("res://") or directory.begins_with("user://"):
		return "Use an absolute filesystem directory for stems."
	if AudioServer.get_speaker_mode() != AudioServer.SPEAKER_MODE_STEREO:
		return "This stem writer requires a stereo movie."
	_sample_rate = roundi(AudioServer.get_mix_rate())
	if _sample_rate <= 0 or _sample_rate % fps != 0:
		return "Movie mix rate must be divisible by the episode FPS."
	_stem_samples = count * floori(float(_sample_rate) / fps)
	if _stem_samples > 536870902:
		return "WAV exceeds RIFF32 capacity; split the episode at a shot boundary."
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "Cannot create the stem directory: " + directory
	var names := {}
	for bus in buses:
		var index := AudioServer.get_bus_index(bus)
		if index < 0 or AudioServer.is_bus_bypassing_effects(index):
			return "Stem bus is missing or bypassed: " + bus
		if not bus.is_valid_filename() or names.has(bus.to_lower()):
			return "Invalid or duplicated stem filename: " + bus
		names[bus.to_lower()] = true
		var path := directory.path_join(bus + ".wav")
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".part"):
			return "Stem output already exists: " + path
	for bus in buses:
		var target := directory.path_join(bus + ".wav")
		var file := FileAccess.open(target + ".part", FileAccess.WRITE)
		if file == null:
			return "Cannot create stem: " + target
		var tap := AudioEffectCapture.new()
		tap.buffer_length = 2.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), tap)
		_taps[bus] = {"effect": tap, "file": file, "target": target, "samples": 0}
		# IEEE float, stereo, 32-bit, little-endian. Length is known up front;
		# only complete takes receive their final .wav name.
		var byte_count := _stem_samples * 8
		file.store_buffer("RIFF".to_ascii_buffer())
		file.store_32(byte_count + 36)
		file.store_buffer("WAVEfmt ".to_ascii_buffer())
		file.store_32(16)
		file.store_16(3)
		file.store_16(2)
		file.store_32(_sample_rate)
		file.store_32(_sample_rate * 8)
		file.store_16(8)
		file.store_16(32)
		file.store_buffer("data".to_ascii_buffer())
		file.store_32(byte_count)
	return ""


func _drain_stems() -> String:
	for bus in _taps:
		var info: Dictionary = _taps[bus]
		var tap: AudioEffectCapture = info.effect
		if tap.get_discarded_frames() != 0:
			return "Stem capture overran: " + str(bus)
		# AudioServer mixes complete internal blocks. MovieWriter consumes
		# mix_rate/fps samples per image; trim only the unconsumed final block.
		var count := mini(tap.get_frames_available(), _stem_samples - int(info.samples))
		if count == 0:
			continue
		var bytes := tap.get_buffer(count).to_byte_array()
		if bytes.size() != count * 8:
			return "Unsupported stereo sample layout for " + str(bus)
		var file: FileAccess = info.file
		if not file.store_buffer(bytes):
			return "Could not write stem: " + str(bus)
		info.samples = int(info.samples) + count
	return ""


func _finalize_stems() -> String:
	var problem := _drain_stems()
	if not problem.is_empty():
		return problem
	for bus in _taps:
		var info: Dictionary = _taps[bus]
		var file: FileAccess = info.file
		file.flush()
		if info.samples != _stem_samples or file.get_length() != 44 + _stem_samples * 8 or file.get_error() != OK:
			return "Incomplete movie stem for " + str(bus)
		file.close()
	for info: Dictionary in _taps.values():
		var path: String = info.target
		if FileAccess.file_exists(path) or DirAccess.rename_absolute(path + ".part", path) != OK:
			return "Could not publish complete stem: " + path
	return ""


func _release_taps() -> void:
	for bus in _taps:
		var info: Dictionary = _taps[bus]
		var file: FileAccess = info.file
		if file.is_open():
			file.close()
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		for slot in range(AudioServer.get_bus_effect_count(index) - 1, -1, -1):
			if AudioServer.get_bus_effect(index, slot) == info.effect:
				AudioServer.remove_bus_effect(index, slot)
				break
	_taps.clear()
