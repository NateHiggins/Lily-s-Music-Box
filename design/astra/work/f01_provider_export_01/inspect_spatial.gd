extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect")

func _inspect() -> void:
	var registry: Resource = load("res://data/floor01_provider_registry.tres")
	var data: Dictionary = registry.get("definition")
	var result := {}
	for row: Dictionary in data.cells:
		var scene: PackedScene = row.scene
		var instance: Node3D = scene.instantiate()
		root.add_child(instance)
		var targets := {}
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			targets[str(mesh.name)] = {"min": [bounds.position.x, bounds.position.y, bounds.position.z],
				"max": [bounds.end.x, bounds.end.y, bounds.end.z]}
		result[str(row.id)] = targets
		instance.free()
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Spatial inspection output directory unavailable")
		quit(1)
		return
	var file := FileAccess.open(output.path_join("imported_bounds.json"), FileAccess.WRITE)
	if file == null:
		push_error("Spatial inspection output file unavailable")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("SPATIAL_INSPECTION cells=", result.size())
	quit(0)
