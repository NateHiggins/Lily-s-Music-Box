extends Node
## Claims to prove player meddle behavior but drives the internal
## consequence method directly.


func _ready() -> void:
	var eco := load_ecosystem()
	eco.meddle_wrong_valve("neighbor")
	assert(eco.situation.state().resolution_kind == "")
