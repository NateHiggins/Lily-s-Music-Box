extends Node
## Mechanism authority: owns its own physical facts, and shows a
## diegetic work paper (ordinary language, not an objective HUD).

var heat_level := 1.0


func apply_condition(kind: String) -> void:
	heat_level = 0.2 if kind == "porter_temporary_shutoff" else heat_level


func work_paper_text() -> String:
	return "Work order: radiator hammering in 2B, resident expects heat"
