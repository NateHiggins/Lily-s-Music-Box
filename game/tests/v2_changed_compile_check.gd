extends Node
func _ready() -> void:
	var failed := false
	var electrical := load("res://scripts/building/orison_v2_native_electrical_service.gd") as Script
	if electrical == null or not electrical.can_instantiate(): failed = true
	for path: String in ["res://tests/orison_v2_surface_inventory.gd","res://tests/v2_fire_service_review.gd","res://tests/v2_electrical_service_review.gd","res://tests/v2_electrical_connections_review.gd","res://scripts/building/orison_v2_native_electrical_connections.gd","res://scripts/building/v2_embedded_surface_stock.gd","res://scripts/building/orison_v2_native_fire_service.gd"]:
		var script := load(path) as Script
		if script == null or not script.can_instantiate(): failed = true
	if OS.get_environment("ORISON_CHECK_LAMP_HELPER_LIFECYCLE")=="1":
		var helper: Node=load("res://tests/orison_v2_street_lamps_shot.gd").new()
		helper.externally_managed=true
		add_child(helper)
		await get_tree().process_frame
		await get_tree().process_frame
		if helper.world!=null:failed=true
		print("LAMP HELPER LIFECYCLE: ","PASS" if helper.world==null else "FAIL")
		helper.free()
	get_tree().quit(1 if failed else 0)
