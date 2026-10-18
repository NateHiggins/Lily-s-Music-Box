extends Node
func _ready() -> void:
	for path: String in ["res://tests/v2_city_elevation_review.gd","res://tests/orison_v2_surface_inventory.gd","res://tests/orison_v2_city_closure_test.gd","res://tests/orison_v2_city_composition_test.gd"]:
		var source := load(path) as Script
		if source==null or not source.can_instantiate():
			push_error("CITY SOURCE BENCH: "+path);get_tree().quit(1);return
	print("CITY SOURCE BENCH: PASS")
	get_tree().quit()
