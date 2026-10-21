extends Control
## Presentation only. The hand supplies the selected part and constraint feedback.
var state := "idle"
var inspectable := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func present(next_state: String, can_inspect: bool, at: Vector2) -> void:
	position = at
	visible = next_state != "hidden"
	if state == next_state and inspectable == can_inspect: return
	state = next_state
	inspectable = can_inspect
	queue_redraw()

func _draw() -> void:
	var ink := Color(.94,.93,.85,.88)
	if state == "idle": ink.a = .38
	if state in ["grabbed","limit"]: ink = Color(1,.84,.55,.94)
	if state == "blocked": ink = Color(.95,.65,.43,.94)
	# A dark keyline remains legible against both lit porcelain and dark timber.
	draw_circle(Vector2.ZERO, 2.3, Color(0,0,0,.65))
	draw_circle(Vector2.ZERO, 1.1, ink)
	if state == "idle": return
	var radius := 5.5 if state in ["grabbed","limit"] else 4.0
	for color_width in [[Color(0,0,0,.65),3.0],[ink,1.0]]:
		if state == "blocked":
			draw_line(Vector2(-4,-4),Vector2(4,4),color_width[0],color_width[1],true)
			draw_line(Vector2(-4,4),Vector2(4,-4),color_width[0],color_width[1],true)
		else:
			draw_arc(Vector2.ZERO,radius,0,TAU,24,color_width[0],color_width[1],true)
		if state == "limit":
			draw_line(Vector2(-4,-8),Vector2(4,-8),color_width[0],color_width[1],true)
			draw_line(Vector2(-4,8),Vector2(4,8),color_width[0],color_width[1],true)
		if inspectable:
			draw_arc(Vector2.ZERO,9,-PI*.65,-PI*.35,8,color_width[0],color_width[1],true)
