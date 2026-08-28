extends Node


func interact_prompt() -> String:
	if winding:
		return "Hold E — winding…"
	if escape_hint:
		return "Press Escape to step away"
	return "Press E"
