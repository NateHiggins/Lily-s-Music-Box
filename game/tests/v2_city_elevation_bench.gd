extends Node
func _ready() -> void:
	for path: String in ["res://tests/v2_city_horizon_review.gd","res://tests/v2_city_elevation_review.gd","res://tests/orison_v2_surface_inventory.gd","res://tests/orison_v2_city_closure_test.gd","res://tests/orison_v2_city_composition_test.gd"]:
		var source := load(path) as Script
		if source==null or not source.can_instantiate():
			push_error("CITY SOURCE BENCH: "+path);get_tree().quit(1);return
	var apron := (load("res://assets/props/city_ground_apron.glb") as PackedScene).instantiate() as Node3D
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var parts := 0
	for draw: MeshInstance3D in apron.find_children("*", "MeshInstance3D", true, false):
		metrics._check_cap_mapping(draw.mesh, true)
		parts += 1
	if parts != 4:
		metrics.failures.append("Distant ground must contain four disjoint closed stocks")
	var failed := not metrics.failures.is_empty()
	metrics.free()
	apron.free()
	if failed:
		get_tree().quit(1)
		return
	print("CITY SOURCE BENCH: PASS")
	get_tree().quit()
