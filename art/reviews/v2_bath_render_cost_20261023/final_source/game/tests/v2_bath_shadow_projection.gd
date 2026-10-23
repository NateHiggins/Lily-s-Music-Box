extends "res://tests/v2_bath_render_cost.gd"
## Diagnostic full-illumination alternative, preserving all shadow casters.
func phase_labels() -> Array[String]:
	return ["normal_static","service_dual_static","all_dual_static","normal_static_restored","normal_move","service_dual_move","all_dual_move","normal_restored_move"]
func treatment(label: String) -> void:
	if not label.begins_with("service_dual") and not label.begins_with("all_dual"):return
	for row: Dictionary in lights:
		if not row.node is OmniLight3D:continue
		if label.begins_with("service_dual") and str(row.node.name)!="WarmServiceLight":continue
		row.node.omni_shadow_mode=OmniLight3D.SHADOW_DUAL_PARABOLOID
