extends Node
## The earned music library in V2 (Lily, v1r_music_director_20261109: "Import
## the earned library; V2's station stands").
##
## What a resident shares when their case settles is V1's: the records they
## like join the player's library, their favourite goes out as a dedication,
## and while it is on the air they will talk about it. V1 played the library
## on its own carrier-current station. V2 has one station, the house broadcast
## every household set joins, so a library record is a request to it: the
## record goes on the air from its first bar and every switched-on set plays
## it. Nothing is heard where no set is on. The catalogue stays the single
## authority for records and for who likes what.

signal library_changed
signal record_requested(track_id: String, reason: String)

const Broadcast := preload("res://scripts/audio/orison_v2_broadcast.gd")
const CATALOG_PATH := "res://data/music_catalog.json"
const FIRST_TRACK := "am_maintenance"

var catalog: Dictionary = {}
var world: Node
var player: Node
var dialogue: CaseDialoguePanel
var opened := false

var _layer: CanvasLayer
var _panel: PanelContainer
var _track_list: VBoxContainer
var _cover: TextureRect
var _now_playing: Label
var _lore: Label
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _shown_record := ""


func setup(building: Node, player_node: Node, panel: CaseDialoguePanel) -> void:
	world = building
	player = player_node
	dialogue = panel


func _ready() -> void:
	name = "OrisonMusicLibrary"
	# AnimatedResident asks this group before it opens a case conversation.
	add_to_group("music_director")
	_load_catalog()
	_ensure_save_data()
	_build_panel()
	set_process(false)
	RealityCases.case_resolved.connect(_on_case_resolved)
	_reconcile_resolved_rewards()


func _load_catalog() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		catalog = parsed
	else:
		push_warning("music catalog missing")


func _ensure_save_data() -> void:
	if not RealityState.data.has("music_library"):
		RealityState.data.music_library = []
	if not RealityState.data.has("heard_music_anecdotes"):
		RealityState.data.heard_music_anecdotes = []
	if FIRST_TRACK not in RealityState.data.music_library:
		RealityState.data.music_library.append(FIRST_TRACK)


## The records the player holds, in the order they were shared.
func library() -> Array:
	return RealityState.data.get("music_library", []).duplicate()


## The record the house is broadcasting to a set that is on. Empty when no
## set is switched on: a record nobody can hear starts no conversation.
func on_air_track() -> String:
	if Broadcast.listeners().is_empty():
		return ""
	return str(Broadcast.now_playing().get("id", ""))


## Asks the station for a record the player holds. False when the record is
## not in the library or the programme cannot play it.
func play_track(track_id: String, reason := "PERSONAL LIBRARY") -> bool:
	if track_id not in RealityState.data.get("music_library", []):
		return false
	return _request(track_id, reason)


## A resident's favourite, sent out for them whether or not the player holds it.
func play_for_resident(resident_id: String) -> bool:
	var favorite := str(catalog.get("residents", {}).get(
			resident_id, {}).get("favorite", ""))
	return _request(favorite, "REQUEST DEDICATION") if favorite != "" else false


func _request(track_id: String, reason: String) -> bool:
	if not catalog.get("tracks", {}).has(track_id) or not Broadcast.request(track_id):
		return false
	_refresh_now_playing()
	record_requested.emit(track_id, reason)
	return true


## The moment a case settles: the resident's records join the library and
## their favourite goes out as a dedication.
func _on_case_resolved(case_id: String, _state: Dictionary) -> void:
	var resident_id := str(RealityCases.definition(case_id).get("resident_id", ""))
	var newly_added := unlock_resident_music(resident_id)
	if newly_added > 0:
		_announce(resident_id, newly_added)
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
		if bool(RealityState.case_state(case_id).get("resolved", false)):
			unlock_resident_music(str(
					RealityCases.definition(case_id).get("resident_id", "")))


## The slip that tells the player a resident has shared their records. It
## prints on the service set like any other field note, when the set is on.
func _announce(resident_id: String, count: int) -> void:
	if player == null or not is_instance_valid(player) \
			or not player.has_method("present_service_note"):
		return
	var resident: Dictionary = catalog.get("residents", {}).get(resident_id, {})
	player.present_service_note(self, {
		"title": "Records shared",
		"body": "%s shared %d record%s. Their favourite is on the wireless now." % [
				str(resident.get("name", "A resident")), count, "" if count == 1 else "s"],
		"condition": "LIBRARY", "stamp": "WIRELESS"})


## What a resident says about their favourite while it is heard, and after
## their case is settled what they gave. Empty when it is not on the air.
func anecdote(resident_id: String) -> Dictionary:
	var resident: Dictionary = catalog.get("residents", {}).get(resident_id, {})
	var favorite := str(resident.get("favorite", ""))
	if favorite == "" or on_air_track() != favorite:
		return {}
	var case_id := RealityCases.case_for_resident(resident_id)
	var words := str(resident.get("anecdote", ""))
	if bool(RealityState.case_state(case_id).get("resolved", false)):
		words += "\n\n" + str(resident.get("gift_line", ""))
	return {"track": favorite, "name": str(resident.get("name", "")), "words": words}


func note_heard(resident_id: String, track_id: String) -> void:
	var flag := "%s:%s" % [resident_id, track_id]
	if flag not in RealityState.data.heard_music_anecdotes:
		RealityState.data.heard_music_anecdotes.append(flag)
		RealityState.commit()


## The topic V2's conversation trees offer while the favourite is heard
## (ResidentConversations.with_music).
func conversation_topic(resident_id: String) -> Dictionary:
	var heard := anecdote(resident_id)
	if heard.is_empty():
		return {}
	return {"label": "That record on the wireless.", "track": heard.track, "line": heard.words}


## The same anecdote for a resident met in person with no tree of their own:
## AnimatedResident asks this before it opens a case conversation.
func try_music_conversation(resident_id: String) -> bool:
	if dialogue == null or dialogue.attention_active():
		return false
	var conversations := get_tree().get_first_node_in_group("resident_conversations")
	if conversations != null and conversations.has_method("has_tree") \
			and conversations.has_tree(resident_id):
		return false  # their own tree carries the topic
	var heard := anecdote(resident_id)
	if heard.is_empty():
		return false
	note_heard(resident_id, str(heard.track))
	dialogue.present(str(heard.name), str(heard.words), [
		{"text": "Keep listening.", "action": Callable()},
		{"text": "Open the music player.", "action": func(): open_library()},
	])
	return true


## --- the library's face: V1's own player, opened on the same action ---------

func _build_panel() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-410, -280)
	_panel.custom_minimum_size = Vector2(820, 560)
	_layer.add_child(_panel)
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
	var close := Button.new()
	close.text = "CLOSE [M]"
	close.pressed.connect(close_library)
	controls.add_child(close)
	_panel.visible = false
	_refresh_library()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("music_player"):
		return
	if opened:
		close_library()
	elif _available():
		open_library()
	else:
		return
	get_viewport().set_input_as_handled()


## The player opens it with free hands: not in a call or a conversation, not
## typing, not holding a part and not seated at something.
func _available() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if bool(player.get("call_locked")) or bool(player.get("mouse_released")):
		return false
	if player.has_method("inspecting") and player.inspecting():
		return false
	var grab: Variant = player.get("_grab")
	if grab != null and grab.has_method("active") and grab.active():
		return false
	return not is_instance_valid(player.get("seated_interaction"))


func open_library() -> void:
	if opened or player == null or not is_instance_valid(player):
		return
	opened = true
	set_process(true)
	_mouse_before = Input.mouse_mode
	player.set("call_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_library()
	_panel.visible = true


func close_library() -> void:
	if not opened:
		return
	opened = false
	set_process(false)
	_panel.visible = false
	if player != null and is_instance_valid(player):
		player.set("call_locked", false)
	Input.mouse_mode = _mouse_before


func _refresh_library() -> void:
	if _track_list == null:
		return
	for child in _track_list.get_children():
		_track_list.remove_child(child)
		child.queue_free()
	var tracks: Dictionary = catalog.get("tracks", {})
	for track_id in RealityState.data.get("music_library", []):
		if not tracks.has(track_id):
			continue
		var track: Dictionary = tracks[track_id]
		var button := Button.new()
		button.name = "Record_" + str(track_id)
		button.text = "%s\n%s · %s" % [
				str(track.title), str(track.artist), str(track.year)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_library_track.bind(str(track_id)))
		_track_list.add_child(button)
	_refresh_now_playing()


func _select_library_track(track_id: String) -> void:
	play_track(track_id)


func _process(_delta: float) -> void:
	if opened and str(Broadcast.now_playing().get("id", "")) != _shown_record:
		_refresh_now_playing()


## The panel shows what the station is playing, which after a request is the
## record that was asked for.
func _refresh_now_playing() -> void:
	if _now_playing == null:
		return
	var now := Broadcast.now_playing()
	_shown_record = str(now.get("id", ""))
	if now.is_empty():
		_now_playing.text = "NO SIGNAL"
		_cover.texture = null
		_lore.text = ""
		return
	var heard := not Broadcast.listeners().is_empty()
	_now_playing.text = "%s\n%s — %s" % [
			"ON THE AIR" if heard else "ON THE AIR. SWITCH ON A WIRELESS TO HEAR IT.",
			str(now.title), str(now.performers)]
	var track: Dictionary = catalog.get("tracks", {}).get(_shown_record, {})
	var cover := str(track.get("cover", ""))
	_cover.texture = load(cover) as Texture2D if cover != "" and ResourceLoader.exists(cover) else null
	_lore.text = "%s\n\nMood: %s" % [str(track.provenance), str(track.mood)] if not track.is_empty() else ""


func _exit_tree() -> void:
	close_library()
