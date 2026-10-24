extends "res://tests/v2_bathroom_paper_review.gd"
## Static installed contact/material diagnostic; no input or timing claim.
func _init() -> void:route_label="V2 PAPER INSTALLATION"
func _route() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	await _paper_review()
