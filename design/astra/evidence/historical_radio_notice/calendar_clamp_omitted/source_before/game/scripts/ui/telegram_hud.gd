class_name TelegramHud
extends CanvasLayer
## Shared, non-modal service-wire presenter. It owns no prop state, work order,
## interaction or pause. A new field copy simply replaces the previous one.

signal card_presented(serial: int, card: Dictionary)

const MAX_WIDTH := 520.0
const CARD_HEIGHT := 250.0

var reduced_typewriter := false
var last_card: Dictionary = {}
var serial := 0

var _paper: PanelContainer
var _title: Label
var _body: Label
var _condition: Label
var _stamp: Label
var _footer: Label
var _life: Tween
var _home := Vector2.ZERO


func _ready() -> void:
	layer = 9
	reduced_typewriter = OS.get_environment(
			"TELEGRAM_REDUCED_TYPEWRITER") == "1"
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func present(card: Dictionary) -> bool:
	var body := str(card.get("body", "")).strip_edges()
	if body == "":
		return false
	serial += 1
	last_card = card.duplicate(true)
	last_card["serial"] = serial
	_title.text = str(card.get("title", "FIELD OBSERVATION")).to_upper()
	_body.text = body
	_condition.text = str(card.get("condition", "")).to_upper()
	_condition.visible = _condition.text != ""
	_stamp.text = str(card.get("stamp", "FIELD COPY")).to_upper()
	_footer.text = "VANTRY SERVICE WIRE  /  SLIP %04d" % serial
	if _life:
		_life.kill()
	_paper.visible = true
	_paper.modulate = Color(1, 1, 1, 0)
	_paper.position = _home + Vector2(0, 24)
	_body.visible_characters = -1 if reduced_typewriter else 0
	_life = create_tween()
	_life.set_parallel(true)
	_life.tween_property(_paper, "modulate:a", 1.0, 0.16)
	_life.tween_property(_paper, "position", _home, 0.22).set_trans(
			Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not reduced_typewriter:
		_life.tween_property(_body, "visible_characters", body.length(),
				clampf(body.length() * 0.012, 0.22, 1.15))
	_life.chain().tween_interval(clampf(2.8 + body.length() * 0.036,
			4.0, 8.0))
	_life.chain().tween_property(_paper, "modulate:a", 0.0, 0.42)
	_life.chain().tween_callback(func(): _paper.visible = false)
	card_presented.emit(serial, last_card)
	return true


func dismiss() -> void:
	if _life:
		_life.kill()
	if _paper:
		_paper.visible = false


static func card_from_interaction(owner: Node, result: Variant) -> Dictionary:
	if result is Dictionary \
			and str((result as Dictionary).get("body", "")).strip_edges() != "":
		return (result as Dictionary).duplicate(true)
	if is_instance_valid(owner) and owner.has_method("service_wire_card"):
		var supplied: Variant = owner.call("service_wire_card")
		if supplied is Dictionary:
			return (supplied as Dictionary).duplicate(true)
	return {}


func _build() -> void:
	_paper = PanelContainer.new()
	_paper.name = "ServiceWireTelegram"
	_paper.add_theme_stylebox_override("panel", TelegramStyle.paper_panel())
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.visible = false
	add_child(_paper)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(stack)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)
	_stamp = Label.new()
	_stamp.add_theme_stylebox_override("normal", TelegramStyle.stamp_tag())
	TelegramStyle.apply(_stamp, 12, true, TelegramStyle.SERVICE_TEAL)
	header.add_child(_stamp)
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spring)
	_footer = Label.new()
	TelegramStyle.apply(_footer, 11, false, TelegramStyle.CARBON_SOFT)
	header.add_child(_footer)

	_title = Label.new()
	TelegramStyle.apply(_title, 20, true)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(_title)

	var rule := HSeparator.new()
	var rule_style := StyleBoxLine.new()
	rule_style.color = Color(TelegramStyle.SERVICE_TEAL, 0.58)
	rule_style.thickness = 1
	rule.add_theme_stylebox_override("separator", rule_style)
	stack.add_child(rule)

	# A fixed reading measure breaks Godot Label's zero-width/autowrap minimum
	# cycle (which otherwise asks the VBox for one line per character).
	var body_clip := Control.new()
	body_clip.custom_minimum_size = Vector2(0, 74)
	body_clip.clip_contents = true
	body_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(body_clip)
	_body = Label.new()
	TelegramStyle.apply(_body, 16, false)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_clip.add_child(_body)

	_condition = Label.new()
	TelegramStyle.apply(_condition, 12, true, TelegramStyle.OLD_RED)
	_condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_condition)


func _layout() -> void:
	if _paper == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(MAX_WIDTH, maxf(300.0, viewport_size.x - 32.0))
	var height := minf(CARD_HEIGHT, maxf(156.0, viewport_size.y * 0.34))
	_home = Vector2(viewport_size.x - width - 24.0,
			viewport_size.y - height - 24.0)
	_paper.position = _home
	_paper.size = Vector2(width, height)
