extends CanvasLayer
## Developer notes for play sessions (Lily, 2026-11-19: "a developer mode where I can easily leave bug notes per room
## and take screenshots"). Off unless the launcher sets ORISON_DEV_NOTES to a folder; then:
##   F6  note: takes the frame, pauses, asks for one line, and files both under the room she is standing in
##   F7  screenshot only, filed the same way
## Every note is one line of <folder>/notes.jsonl and one picture in <folder>/<room>/. It also keeps
## <folder>/context.json current with the room and the campaign time; the launcher relays that to the desktop
## playtest hotkey. It never reads the computer's clock (the period gate): pictures are numbered, and the launcher
## dates them from the files. It reads the world and writes only into that folder: no save, clock, route or
## campaign state.
const NOTE_KEY := KEY_F6
const SHOT_KEY := KEY_F7

var _folder := ""
var _build := ""
var _tag: Label
var _entry: LineEdit
var _panel: PanelContainer
var _frame: Image
var _was_paused := false
var _mouse := Input.MOUSE_MODE_VISIBLE
var _tick := 0.0
var _flash := 0.0


func _ready() -> void:
	_folder = OS.get_environment("ORISON_DEV_NOTES").replace("\\", "/")
	if _folder.is_empty() or DisplayServer.get_name() == "headless":
		process_mode = Node.PROCESS_MODE_DISABLED
		queue_free()
		return
	_build = OS.get_environment("ORISON_DEV_BUILD")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	DirAccess.make_dir_recursive_absolute(_folder)
	_tag = Label.new()
	_tag.position = Vector2(12, 8)
	_tag.add_theme_font_size_override("font_size", 13)
	_tag.add_theme_color_override("font_color", Color(1, 0.92, 0.6, 0.85))
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_tag.add_theme_constant_override("outline_size", 4)
	add_child(_tag)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -64
	_panel.visible = false
	add_child(_panel)
	_entry = LineEdit.new()
	_entry.placeholder_text = "What is wrong here? Enter saves, Esc cancels"
	_entry.add_theme_font_size_override("font_size", 20)
	_entry.text_submitted.connect(_save_note)
	_entry.gui_input.connect(_entry_key)
	_panel.add_child(_entry)


func _where() -> Dictionary:
	var world := get_tree().get_first_node_in_group("orison_v2_runtime") as Node
	if world == null:
		for node: Node in get_tree().root.find_children("*", "OrisonV2RuntimeRoot", true, false):
			world = node
			break
	var out := {"room": "", "position": [], "facing_deg": 0.0, "scene": str(get_tree().current_scene.scene_file_path) if get_tree().current_scene != null else ""}
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var at := camera.global_position
		out.position = [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)]
		var forward := -camera.global_basis.z
		out.facing_deg = snappedf(fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0), 0.1)
		if world != null and world.has_method("room_at_world"):
			out.room = str(world.call("room_at_world", at))
	if str(out.room).is_empty():
		out.room = "outside" if world != null else str(out.scene).get_file().get_basename()
	return out


func _game_time() -> String:
	if not RealityState.data.has("campaign_clock"):
		return ""
	return CampaignClock.new().datetime_string()


func _process(delta: float) -> void:
	_tick -= delta
	_flash = maxf(0.0, _flash - delta)
	if _tick > 0.0:
		return
	_tick = 1.0
	var where := _where()
	_tag.text = "DEV  %s   F6 note   F7 shot%s" % [where.room, "   saved" if _flash > 0.0 else ""]
	var file := FileAccess.open(_folder.path_join("context.tmp"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"game_time": _game_time(), "location": where.room, "source_label": "game developer mode"}))
		file.close()
		DirAccess.rename_absolute(_folder.path_join("context.tmp"), _folder.path_join("context.json"))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _panel.visible:
		if key.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		return
	if key.keycode == SHOT_KEY:
		get_viewport().set_input_as_handled()
		_tag.visible = false
		await RenderingServer.frame_post_draw
		_file(get_viewport().get_texture().get_image(), "")
		_tag.visible = true
	elif key.keycode == NOTE_KEY:
		get_viewport().set_input_as_handled()
		_tag.visible = false
		await RenderingServer.frame_post_draw
		_frame = get_viewport().get_texture().get_image()
		_tag.visible = true
		_was_paused = get_tree().paused
		_mouse = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_entry.text = ""
		_panel.visible = true
		_entry.grab_focus()


## Esc while typing: the line edit has the keyboard, so it is caught here and not as an unhandled key.
func _entry_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		_entry.accept_event()
		_close()


func _close() -> void:
	_panel.visible = false
	_frame = null
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse


func _save_note(text: String) -> void:
	if not text.strip_edges().is_empty() and _frame != null:
		_file(_frame, text.strip_edges())
	_close()


func _file(image: Image, note: String) -> void:
	var where := _where()
	var room := str(where.room).validate_filename()
	DirAccess.make_dir_recursive_absolute(_folder.path_join(room))
	var number := DirAccess.get_files_at(_folder.path_join(room)).size() + 1
	var picture := room.path_join("%04d.png" % number)
	while FileAccess.file_exists(_folder.path_join(picture)):
		number += 1
		picture = room.path_join("%04d.png" % number)
	if image != null:
		image.save_png(_folder.path_join(picture))
	var row := {"build": _build, "room": where.room, "position": where.position,
		"facing_deg": where.facing_deg, "game_time": _game_time(), "note": note, "picture": picture, "scene": where.scene}
	var path := _folder.path_join("notes.jsonl")
	var file := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line(JSON.stringify(row))
		file.close()
	_flash = 3.0
	_tick = 0.0
