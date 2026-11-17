extends "res://tests/harukiya_physical_contact_writer.gd"
## Isolated test modifier; original helpers unchanged.
func _process_modification() -> void:
	if not enabled:return
	writers.clear()
	if not _stand.apply(skeleton,"__bass_candidate",false,0.0,0.0):
		faults.append("current Lily source stand failed");return
	contact_math.solve_bass(self)
