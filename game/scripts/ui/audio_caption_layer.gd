class_name AudioCaptionLayer
extends CanvasLayer
## Accessibility parity for the bounded semantic cue catalog. Raw ambience,
## music and dialogue are not pretended to be captioned by this layer.

const SETTING_KEY := "gameplay_sound_captions"
const HOLD_S := 2.6
const FADE_S := 0.45
const MAX_LINES := 3

var enabled := false
var _rows: VBoxContainer
var _live: Array[Dictionary] = []


func _ready() -> void:
	layer = 59
	refresh_setting()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -190.0
	margin.offset_bottom = -54.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.alignment = BoxContainer.ALIGNMENT_END
	_rows.add_theme_constant_override("separation", 6)
	margin.add_child(_rows)


func refresh_setting() -> void:
	enabled = bool(GameBoot.settings.get(SETTING_KEY, false))


func listen_to(policy: Node) -> void:
	if policy != null and not policy.cue_presented.is_connected(_on_cue):
		policy.cue_presented.connect(_on_cue)


func _on_cue(_cue_id: StringName, record: Dictionary) -> void:
	if not enabled:
		return
	var words := str(record.get("caption", "")).strip_edges()
	var sector := str(record.get("sector", "")).strip_edges()
	if words.is_empty():
		return
	speak("%s%s" % [words, " — " + sector if not sector.is_empty() else ""])


func speak(text: String) -> void:
	# A repeating physical source sustains one fact. Reset its hold instead of
	# printing the same clock beat or machinery state into every available row.
	for row in _live:
		var existing: Label = row.label
		if is_instance_valid(existing) and existing.text == text:
			row.age = 0.0
			existing.modulate.a = 1.0
			return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(label)
	_live.append({"label":label, "age":0.0})
	while _live.size() > MAX_LINES:
		_retire(_live.pop_front().label)


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for row in _live:
		var label: Label = row.label
		if not is_instance_valid(label):
			continue
		row.age = float(row.age) + delta
		if float(row.age) >= HOLD_S + FADE_S:
			_retire(label)
			continue
		if float(row.age) > HOLD_S:
			label.modulate.a = 1.0 - (float(row.age) - HOLD_S) / FADE_S
		keep.append(row)
	_live = keep


func _retire(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()
