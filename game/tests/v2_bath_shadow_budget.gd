extends "res://tests/v2_bath_render_cost.gd"
## Diagnostic budget sweep; preserve all active light energy and main quality.
func phase_labels() -> Array[String]:
	return ["normal_static","shadow16_static","shadow8_static","shadow4_static","shadow2_static","mirror_shadow_off","celestial_shadow_off","normal_static_restored","normal_move","shadow8_move","shadow4_move","normal_restored_move"]

func restore() -> void:
	super.restore()
	world.light_rig.set_budgets(original.active_budget,original.shadow_budget)
	mirror._view.positional_shadow_atlas_size=original.mirror_atlas

func treatment(label: String) -> void:
	if label.begins_with("shadow"):
		var budget: int=int(label.trim_prefix("shadow").get_slice("_",0))
		world.light_rig.set_budgets(original.active_budget,budget)
	elif label=="mirror_shadow_off":mirror._view.positional_shadow_atlas_size=0
	elif label=="celestial_shadow_off":
		for row: Dictionary in lights:
			if row.node is DirectionalLight3D:row.node.shadow_enabled=false
