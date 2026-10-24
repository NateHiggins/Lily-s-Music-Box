extends "res://tests/v2_handheld_profile.gd"
## INERT causal intervention, never production appearance qualification.
func configure_treatment() -> void:
	treatment="probe_shadows_disabled"
	reflections.child_entered_tree.connect(_probe_entered)
	for probe: Node in reflections.get_children():_probe_entered(probe)

func _probe_entered(node: Node) -> void:
	if node is ReflectionProbe:node.enable_shadows=false
