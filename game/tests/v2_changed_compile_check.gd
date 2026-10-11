extends Node
func _ready() -> void:
	var failed := false
	for path: String in ["res://tests/orison_v2_surface_inventory.gd","res://tests/v2_fire_service_review.gd","res://scripts/building/v2_embedded_surface_stock.gd","res://scripts/building/orison_v2_native_fire_service.gd"]:
		var script := load(path) as Script
		if script == null or not script.can_instantiate(): failed = true
	get_tree().quit(1 if failed else 0)
