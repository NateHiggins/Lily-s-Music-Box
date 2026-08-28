extends Node


func control_prompt(control_id: String) -> String:
	return "Work the %s" % control_id


func interact_control(_control_id: String, _player: Node) -> Dictionary:
	return {}
