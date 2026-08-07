class_name InspectableZone
extends StaticBody3D
## A thing worth a second look. Stands in front of batched geometry the
## way the lobby bench does and owns the verb: examine. The observation
## arrives as a lower-third line that holds long enough to read and then
## gets out of the way — the building's own captioning voice, not a modal.
##
## Multiple lines cycle in order across interactions, so a picture can
## have a second reading for whoever comes back to it.

var title := ""
var lines: Array = []
var _next := 0
var _label: Label
var _fade: Tween


func setup(zone_title: String, zone_lines: Array,
		size := Vector3(0.8, 0.8, 0.4)) -> void:
	title = zone_title
	lines = zone_lines
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func interact_prompt() -> String:
	return "[E]  Look at %s" % title


func interact(_player: Node) -> void:
	if lines.is_empty():
		return
	var line := str(lines[_next % lines.size()])
	_next += 1
	_show_line(line)


func _show_line(text: String) -> void:
	if _label == null:
		var layer := CanvasLayer.new()
		layer.layer = 8
		add_child(layer)
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_label.offset_top = -150
		_label.offset_bottom = -96
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_label.add_theme_font_size_override("font_size", 15)
		_label.modulate = Color(0.88, 0.90, 0.86, 0.0)
		layer.add_child(_label)
	_label.text = text
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_label, "modulate:a", 0.95, 0.25)
	_fade.tween_interval(0.9 + text.length() * 0.055)
	_fade.tween_property(_label, "modulate:a", 0.0, 0.8)
