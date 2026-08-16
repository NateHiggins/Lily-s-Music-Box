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
	_panel.custom_minimum_size = Vector2(360, 0)
	_panel.add_theme_stylebox_override("panel", TelegramStyle.paper_panel(0.94))
	add_child(_panel)
	var stack := VBoxContainer.new()
	_panel.add_child(stack)
	_title = Label.new()
	TelegramStyle.apply(_title, 13, true, TelegramStyle.SERVICE_TEAL)
	stack.add_child(_title)
	_objective = Label.new()
	TelegramStyle.apply(_objective, 13, false, TelegramStyle.CARBON)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_objective)
	clear()


## The tracker presents the title its owner authored; it never relabels it.
## Every production caller supplies a complete, self-labelling heading
## ("WORK ORDER 001 — THE CHIRP", "CASE CLOSED — MINA VALE"), so a fixed
## "WORK ORDER /" prefix here both stuttered and mis-titled non-work-order
## headings. Casing stays a presentation choice, as in TelegramHud.
func show_objective(title_text: String, objective_text: String) -> void:
	_title.text = title_text.to_upper()
	_objective.text = objective_text
	_panel.visible = true


func clear() -> void:
	if _panel:
		_panel.visible = false
