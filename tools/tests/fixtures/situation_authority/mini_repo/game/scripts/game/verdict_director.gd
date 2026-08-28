extends Node
## Coordinator writing an abstract moral verdict into durable state.


func judge_player() -> void:
	situation.record_fact("morality", "bad")
