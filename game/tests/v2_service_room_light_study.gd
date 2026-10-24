extends "res://tests/v2_bath_render_cost.gd"
var visibility: Node
func phase_labels() -> Array[String]:
	return ["normal_static","connected_static","normal_static_restored","normal_move","connected_move","normal_restored_move"]
func restore() -> void:
	if visibility!=null:visibility.set_enabled(false)
	super.restore()
func treatment(label: String) -> void:
	if visibility==null:
		visibility=preload("res://scripts/building/orison_v2_service_light_visibility.gd").new();world.add_child(visibility)
		if not visibility.setup(world):failures.append("service light visibility resolves original owners")
	visibility.set_enabled(label.begins_with("connected"))
func _process(delta: float) -> void:
	super._process(delta)
	if visibility!=null:
		samples[-1].context_room=visibility.context_room
		samples[-1].service_sources=visibility.visible_sources.duplicate()
		samples[-1].conservative=visibility.conservative
