class_name DreamCaptionLayer
extends CanvasLayer
## N7: what the ear hears, written down, for players who cannot hear it.
##
## Gate C's third bullet: "directional-caption mode conveys the same
## information without revealing hidden geometry." Both halves of that are
## load-bearing. A caption that said "TRUNK HISS 4.2 m north-east" would hand
## a caption player a map a hearing player never gets, which is not
## accessibility — it is an advantage, and it would quietly break the light
## decision the whole dream is built on.
##
## So a line is exactly two things: the cue, and one of eight sectors relative
## to where the player is facing. No distances, no room names, no counts.
## DreamHazardField already refuses to put anything else in a perception row;
## this layer only renders what is there.

## Off by default. A hearing player gets the same facts from the mix, and the
## dream's whole grammar is listening -- so the text is opt-in rather than
## opt-out, and the key lives with the other accessibility settings.
const SETTING_KEY := "dream_directional_captions"
## Long enough to read one short line without the screen becoming a list.
const HOLD_S := 2.6
const FADE_S := 0.45
## More than this on screen and the channel stops being readable, which for a
## caption player is the same as it not working.
const MAX_LINES := 3

var enabled := false
var _rows: VBoxContainer
var _live: Array[Dictionary] = []


func _ready() -> void:
	layer = 60
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
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_rows)


func refresh_setting() -> void:
	enabled = _setting_enabled()


## Connect to a field's tell. The field emits a bearing in degrees; the sector
## is recomputed here through the same public helper the log uses, so the two
## can never disagree about which way the caption points.
func listen_to(field: DreamHazardField) -> void:
	if field == null:
		return
	field.tell_started.connect(_on_tell)


func _on_tell(_hazard_id: String, bearing_deg: float, caption: String) -> void:
	if not enabled or caption.is_empty():
		return
	speak("%s — %s" % [caption,
			DreamHazardField.bearing_sector(bearing_deg)])


## One line, oldest retired first. Public so the settings screen can show a
## sample without a hazard in the world.
func speak(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(label)
	_live.append({"label": label, "age": 0.0})
	while _live.size() > MAX_LINES:
		_retire(_live.pop_front().label)


func _process(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for row in _live:
		var label: Label = row.label
		if not is_instance_valid(label):
			continue
		row.age = float(row.age) + delta
		var age := float(row.age)
		if age >= HOLD_S + FADE_S:
			_retire(label)
			continue
		if age > HOLD_S:
			label.modulate.a = 1.0 - (age - HOLD_S) / FADE_S
		keep.append(row)
	_live = keep


## Leave the layout the moment a line is retired. queue_free() alone is
## deferred, so a retired caption would still occupy a row for the rest of
## the frame and the readable-line cap would be a line late.
func _retire(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _setting_enabled() -> bool:
	return bool(GameBoot.settings.get(SETTING_KEY, false))
