extends "res://tests/v2_bath_contact_installed.gd"
## Interleaved exact original controls, final stock, restored controls, then
## ordinary installed sink interactions after diagnostic shapes are removed.
func _ready() -> void:
	installed_only=false
	set_process(false);run.call_deferred()
