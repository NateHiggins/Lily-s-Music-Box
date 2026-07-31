class_name ObjectiveTracker
extends CanvasLayer
## Compact diegetic work-order readout shared by playable reality cases.

var _panel: PanelContainer
var _title: Label
var _objective: Label


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.position = Vector2(22, 22)
	_panel.custom_minimum_size = Vector2(330, 0)
	add_child(_panel)
	var stack := VBoxContainer.new()
	_panel.add_child(stack)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.modulate = Color(0.66, 0.88, 0.78)
	stack.add_child(_title)
	_objective = Label.new()
	_objective.add_theme_font_size_override("font_size", 12)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.modulate = Color(0.88, 0.88, 0.82)
	stack.add_child(_objective)
	clear()


func show_objective(title_text: String, objective_text: String) -> void:
	_title.text = title_text
	_objective.text = objective_text
	_panel.visible = true


func clear() -> void:
	if _panel:
		_panel.visible = false
