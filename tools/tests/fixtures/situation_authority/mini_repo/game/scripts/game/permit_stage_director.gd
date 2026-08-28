extends Node
## Single-path stage machine: the only exit is player compliance.


func advance(stage: String) -> void:
	match stage:
		"issued":
			pass
		"acknowledged":
			pass
	if stage == "closed":
		unlock_everything()
