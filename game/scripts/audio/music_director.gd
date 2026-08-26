class_name OrisonMusicDirector
extends Node
## Diegetic soundtrack: an unlocatable carrier-current station that the
## reality director may tune at will, plus the player's earned music library.

signal track_changed(track_id: String)
signal library_changed

const CATALOG_PATH := "res://data/music_catalog.json"
const FIRST_TRACK := "am_maintenance"

var catalog: Dictionary = {}
var current_track_id := ""
var world: Node

var _radio: AudioStreamPlayer3D
var _dialogue: CaseDialoguePanel
var _next_broadcast := 12.0
var _rng := RandomNumberGenerator.new()
var _panel: PanelContainer
var _track_list: VBoxContainer
var _cover: TextureRect
var _now_playing: Label
var _lore: Label
var _station_bug: Label
var _station_bug_until := 0.0
var _radio_destination := Vector3.ZERO
var _next_radio_move := 0.0
var _signal_phase := 0.0
var _signal_strength := 0.0


func setup(building: Node) -> void:
	world = building


func _ready() -> void:
	name = "OrisonMusicDirector"
	add_to_group("music_director")
	_rng.seed = 1610
	_load_catalog()
	_ensure_save_data()
	_ensure_bus()
	_radio = AudioStreamPlayer3D.new()
	_radio.name = "UnlocatableGhostRadio"
	_radio.bus = "GhostRadio"
	_radio.volume_db = -60.0
	_radio.unit_size = 3.2
	_radio.max_distance = 24.0
	_radio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_radio)
	_radio.finished.connect(_on_track_finished)
	_choose_radio_destination(true)
	_dialogue = CaseDialoguePanel.new()
	add_child(_dialogue)
	_build_mp3_player()
	RealityCases.case_changed.connect(_on_case_changed)
	_reconcile_resolved_rewards()


func _load_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_warning("music catalog missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		catalog = parsed


func _ensure_save_data() -> void:
	if not RealityState.data.has("music_library"):
		RealityState.data.music_library = []
	if not RealityState.data.has("heard_music_anecdotes"):
		RealityState.data.heard_music_anecdotes = []
	if FIRST_TRACK not in RealityState.data.music_library:
		RealityState.data.music_library.append(FIRST_TRACK)


func _ensure_bus() -> void:
	var index := AudioServer.get_bus_index("GhostRadio")
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "GhostRadio")
	AudioServer.set_bus_send(index, "Diegetic")
	AudioServer.set_bus_volume_db(index, -2.0)
	if AudioServer.get_bus_effect_count(index) == 0:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 6400.0
		low_pass.resonance = 0.22
		AudioServer.add_bus_effect(index, low_pass)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.42
		reverb.damping = 0.68
		reverb.wet = 0.16
		reverb.dry = 0.86
		AudioServer.add_bus_effect(index, reverb)


func _process(delta: float) -> void:
	if _station_bug.visible and Time.get_ticks_msec() / 1000.0 > _station_bug_until:
		_station_bug.visible = false
	if _radio.playing:
		_update_ghost_radio(delta)
		return
	_next_broadcast -= delta
	if _next_broadcast <= 0.0:
		choose_director_track()


func _update_ghost_radio(delta: float) -> void:
	if world == null or world.player == null:
		return
	_next_radio_move -= delta
	if _next_radio_move <= 0.0 or _radio.global_position.distance_to(
			_radio_destination) < 0.8:
		_choose_radio_destination(false)
	var travel_rate := 0.10 if _signal_strength > 0.25 else 0.22
	_radio.global_position = _radio.global_position.lerp(
			_radio_destination, 1.0 - exp(-delta * travel_rate))
	_signal_phase += delta * _rng.randf_range(0.075, 0.12)
	# Long irregular swells make the station seem carried by pipes and rooms,
	# not volume-automated. It can vanish even while the track keeps playing.
	var carrier := smoothstep(-0.45, 0.65,
			sin(_signal_phase) + sin(_signal_phase * 0.37 + 1.8) * 0.42)
	var pressure: float = world.sanity.pressure if world.sanity else 0.0
	var target := clampf(carrier * (0.72 + pressure * 0.28), 0.0, 1.0)
	_signal_strength = lerpf(_signal_strength, target,
			minf(1.0, delta * (0.35 if target > _signal_strength else 0.16)))
	_radio.volume_db = lerpf(-46.0, -7.5, _signal_strength)


func _choose_radio_destination(initial: bool) -> void:
	if world == null or world.player == null:
		return
	var here: Vector3 = world.player.global_position
	var candidates: Array[Vector3] = []
	for node_id in AcousticGraphData.nodes:
		var at := AcousticGraphData.node_pos(node_id)
		var horizontal := Vector2(at.x - here.x, at.z - here.z).length()
		var vertical := absf(at.y - here.y)
		if horizontal > 6.0 and horizontal < 27.0 and vertical < 4.8:
			candidates.append(at + Vector3(0.0, _rng.randf_range(0.4, 1.5), 0.0))
	if candidates.is_empty():
		_radio_destination = here + Vector3(10.0, 1.0, -8.0)
	else:
		_radio_destination = candidates[
				_rng.randi_range(0, candidates.size() - 1)]
	if initial:
		_radio.global_position = _radio_destination
	_next_radio_move = _rng.randf_range(12.0, 31.0)


func choose_director_track() -> void:
	var candidates: Array = []
	var current_case: String = RealityState.data.get("current_case_id", "")
	if current_case != "":
		var definition := RealityCases.definition(current_case)
		var resident_id: String = definition.get("resident_id", "")
		candidates = _likes_for(resident_id)
	if candidates.is_empty():
		candidates = catalog.get("tracks", {}).keys()
	if candidates.is_empty():
		return
	play_track(str(candidates[_rng.randi_range(0, candidates.size() - 1)]),
			"THE BUILDING SELECTED")


func play_track(track_id: String, reason := "WORS 1610") -> bool:
	var tracks: Dictionary = catalog.get("tracks", {})
	if not tracks.has(track_id):
		return false
	var track: Dictionary = tracks[track_id]
	var stream := load(str(track.path)) as AudioStream
	if stream == null:
		push_warning("music stream missing: " + str(track.path))
		return false
	_radio.stream = stream
	_radio.play()
	_signal_strength = 0.0
	_choose_radio_destination(false)
	current_track_id = track_id
	_show_station_bug("%s\n“%s” — %s" % [
			reason, str(track.title), str(track.artist)])
	_refresh_now_playing()
	track_changed.emit(track_id)
	return true


func stop_radio() -> void:
	_radio.stop()
	current_track_id = ""
	_next_broadcast = _rng.randf_range(24.0, 70.0)
	_refresh_now_playing()


func play_for_resident(resident_id: String) -> bool:
	var favorite := str(catalog.get("residents", {}).get(
			resident_id, {}).get("favorite", ""))
	return play_track(favorite, "REQUEST DEDICATION") if favorite != "" else false


func interrupt_with(track_id: String, reason := "SIGNAL OVERRIDE") -> bool:
	return play_track(track_id, reason)


func _on_track_finished() -> void:
	current_track_id = ""
	_next_broadcast = _rng.randf_range(22.0, 85.0)
	_refresh_now_playing()


func _on_case_changed(case_id: String, state: Dictionary) -> void:
	var definition := RealityCases.definition(case_id)
	var resident_id: String = definition.get("resident_id", "")
	if bool(state.get("resolved", false)):
		var newly_added := unlock_resident_music(resident_id)
		if newly_added > 0:
			var resident: Dictionary = catalog.get("residents", {}).get(
					resident_id, {})
			_show_station_bug("%s SHARED %d TRACKS\n[M] OPEN MUSIC PLAYER" % [
					str(resident.get("name", "A RESIDENT")).to_upper(),
					newly_added], 7.0)
		play_for_resident(resident_id)
	elif str(state.get("stage", "")) in ["active", "reopened"] \
			and _rng.randf() < 0.65:
		play_for_resident(resident_id)


func unlock_resident_music(resident_id: String) -> int:
	var added := 0
	for track_id in _likes_for(resident_id):
		if track_id not in RealityState.data.music_library:
			RealityState.data.music_library.append(track_id)
			added += 1
	if added > 0:
		RealityState.commit()
		_refresh_library()
		library_changed.emit()
	return added


func _likes_for(resident_id: String) -> Array:
	return catalog.get("residents", {}).get(resident_id, {}).get(
			"likes", []).duplicate()


func _reconcile_resolved_rewards() -> void:
	for case_id in RealityCases.definitions:
		var state := RealityState.case_state(case_id)
		if bool(state.get("resolved", false)):
			unlock_resident_music(str(
					RealityCases.definition(case_id).get("resident_id", "")))


func try_music_conversation(resident_id: String) -> bool:
	var resident: Dictionary = catalog.get("residents", {}).get(resident_id, {})
	if resident.is_empty() or current_track_id != str(resident.favorite):
		return false
	var case_id := RealityCases.case_for_resident(resident_id)
	var resolved := bool(RealityState.case_state(case_id).get("resolved", false))
	var words: String = str(resident.anecdote)
	if resolved:
		words += "\n\n" + str(resident.gift_line)
	var flag := "%s:%s" % [resident_id, current_track_id]
	if flag not in RealityState.data.heard_music_anecdotes:
		RealityState.data.heard_music_anecdotes.append(flag)
		RealityState.commit()
	_dialogue.present(str(resident.name), words, [
		{"text": "Keep listening.", "action": Callable()},
		{"text": "Open the music player.", "action": func(): _set_panel_visible(true)},
	])
	return true


func _build_mp3_player() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-410, -280)
	_panel.custom_minimum_size = Vector2(820, 560)
	layer.add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)
	var title := Label.new()
	title.text = "ORISON PM-1610  //  PERSONAL MUSIC LIBRARY"
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.52, 0.92, 0.78)
	root.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 350
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_track_list = VBoxContainer.new()
	_track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_track_list)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 420
	body.add_child(detail)
	_cover = TextureRect.new()
	_cover.custom_minimum_size = Vector2(280, 280)
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(_cover)
	_now_playing = Label.new()
	_now_playing.add_theme_font_size_override("font_size", 17)
	_now_playing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_now_playing)
	_lore = Label.new()
	_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_lore)
	var controls := HBoxContainer.new()
	root.add_child(controls)
	var stop := Button.new()
	stop.text = "STOP RADIO"
	stop.pressed.connect(stop_radio)
	controls.add_child(stop)
	var close := Button.new()
	close.text = "CLOSE [M]"
	close.pressed.connect(func(): _set_panel_visible(false))
	controls.add_child(close)
	_panel.visible = false
	_station_bug = Label.new()
	_station_bug.position = Vector2(24, 70)
	_station_bug.add_theme_font_size_override("font_size", 15)
	_station_bug.modulate = Color(0.58, 0.91, 0.80, 0.88)
	layer.add_child(_station_bug)
	_station_bug.visible = false
	_refresh_library()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("music_player"):
		_set_panel_visible(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_panel_visible(show: bool) -> void:
	_panel.visible = show
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show \
			else Input.MOUSE_MODE_CAPTURED
	var player := get_tree().get_first_node_in_group(
			"player_controller") as PlayerController
	if player:
		player.call_locked = show
	if show:
		_refresh_library()


func _refresh_library() -> void:
	if _track_list == null:
		return
	for child in _track_list.get_children():
		child.queue_free()
	var tracks: Dictionary = catalog.get("tracks", {})
	var unlocked: Array = RealityState.data.get("music_library", [])
	for track_id in unlocked:
		if not tracks.has(track_id):
			continue
		var track: Dictionary = tracks[track_id]
		var button := Button.new()
		button.text = "%s\n%s · %s" % [
				str(track.title), str(track.artist), str(track.year)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_library_track.bind(str(track_id)))
		_track_list.add_child(button)
	_refresh_now_playing()


func _select_library_track(track_id: String) -> void:
	play_track(track_id, "PERSONAL LIBRARY")
	var track: Dictionary = catalog.tracks[track_id]
	_cover.texture = load(str(track.cover)) as Texture2D
	_lore.text = "%s\n\n%s" % [str(track.provenance), str(track.mood)]


func _refresh_now_playing() -> void:
	if _now_playing == null:
		return
	if current_track_id == "" or not catalog.get("tracks", {}).has(
			current_track_id):
		_now_playing.text = "NO SIGNAL"
		return
	var track: Dictionary = catalog.tracks[current_track_id]
	_now_playing.text = "NOW PLAYING\n%s — %s" % [
			str(track.title), str(track.artist)]
	_cover.texture = load(str(track.cover)) as Texture2D
	_lore.text = "%s\n\nMood: %s" % [
			str(track.provenance), str(track.mood)]


func _show_station_bug(text: String, duration := 4.5) -> void:
	if _station_bug == null:
		return
	_station_bug.text = text
	_station_bug.visible = true
	_station_bug_until = Time.get_ticks_msec() / 1000.0 + duration
