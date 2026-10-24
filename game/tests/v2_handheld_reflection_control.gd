extends "res://tests/v2_handheld_profile.gd"
## INERT intervention only. Never a production runtime contract.
func configure_treatment() -> void:
	treatment="reflections_disabled"
	reflections.set_reflections_enabled(false)
