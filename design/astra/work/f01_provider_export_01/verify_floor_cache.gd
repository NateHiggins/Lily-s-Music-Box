extends SceneTree

func _initialize() -> void:
	var failures := 0
	for path in ["res://assets/building/floor_01.gltf", "res://assets/building/floor_04.gltf"]:
		var packed := load(path) as PackedScene
		if packed == null or packed.get_state().get_node_count() == 0:
			failures += 1
		else:
			print("FLOOR_CACHE_LOADED ", path, " nodes=", packed.get_state().get_node_count())
	quit(failures)
