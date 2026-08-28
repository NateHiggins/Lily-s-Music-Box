extends Node
## Stage machine with a compensator: the porter resolves neglect, and an
## elapsed timeout produces continued world state.


func advance(stage: String, elapsed: float) -> void:
	match stage:
		"issued":
			pass
	if stage == "closed":
		unlock_everything()
	if elapsed > 20.0:
		dispatch_compensator("porter")
