extends CanvasLayer
## Plain player-facing persistence failures. RealityState owns the truth and
## safety latch; this layer only presents its structured notice.

var panel: PanelContainer
var title_label: Label
var message_label: Label
var dismiss_button: Button


func _ready() -> void:
	layer = 240
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	RealityState.player_notice_changed.connect(_present)
	_present(RealityState.player_notice())


func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "SaveStatusPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-260.0, 32.0)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	title_label = Label.new()
	title_label.name = "NoticeTitle"
	title_label.add_theme_font_size_override("font_size", 20)
	column.add_child(title_label)
	message_label = Label.new()
	message_label.name = "NoticeMessage"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 16)
	column.add_child(message_label)
	dismiss_button = Button.new()
	dismiss_button.name = "DismissNotice"
	dismiss_button.text = "DISMISS"
	dismiss_button.pressed.connect(_dismiss)
	column.add_child(dismiss_button)
	panel.hide()


func _present(notice: Dictionary) -> void:
	if notice.is_empty():
		panel.hide()
		return
	title_label.text = str(notice.get("title", "SAVE NOTICE"))
	message_label.text = str(notice.get("message", ""))
	panel.show()


func _dismiss() -> void:
	panel.hide()
