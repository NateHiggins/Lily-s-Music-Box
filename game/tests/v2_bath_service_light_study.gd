extends "res://tests/v2_bath_render_cost.gd"
func phase_labels() -> Array[String]:
	return ["normal_static","service_shadows_off","service_lights_off","service_same_floor","unmanaged_shadows_off","normal_static_restored","normal_move","service_shadows_off_move","service_same_floor_move","normal_restored_move"]

func treatment(label: String) -> void:
	for row: Dictionary in lights:
		var service: bool=str(row.node.name)=="WarmServiceLight"
		if label.begins_with("service_shadows_off") and service:row.node.shadow_enabled=false
		elif label=="service_lights_off" and service:row.node.visible=false
		elif label.begins_with("service_same_floor") and service:
			row.node.visible=world.light_rig._floor_at_height(row.node.global_position.y-2.2)==world.light_rig.active_floor
		elif label=="unmanaged_shadows_off" and not row.controlled:row.node.shadow_enabled=false
