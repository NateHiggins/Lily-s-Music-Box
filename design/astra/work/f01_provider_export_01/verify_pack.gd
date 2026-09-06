extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var failures: Array[String] = []
	var registry: Resource = load("res://data/floor01_provider_registry.tres")
	if registry == null:
		print("PACK_VERIFY_FAILED: missing registry")
		quit(1)
		return
	var data: Dictionary = registry.get("definition")
	var mesh_count := 0
	var material_count := 0
	var texture_paths := {}
	var verified_targets := 0
	var cells: Array = data.get("cells", [])
	if cells.size() != 17:
		failures.append("expected 17 cells")
	for row: Dictionary in cells:
		var scene: PackedScene = row.get("scene")
		if scene == null:
			failures.append("missing scene " + str(row.id))
			continue
		var instance := scene.instantiate()
		if not instance is Node3D:
			failures.append("invalid root " + str(row.id))
		var pending: Array[Node] = [instance]
		var cell_meshes := 0
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			pending.append_array(node.get_children())
			if node is MeshInstance3D:
				if node.mesh == null:
					failures.append("missing mesh " + str(node.name))
					continue
				cell_meshes += 1
				for surface in node.mesh.get_surface_count():
					var material: Material = node.get_active_material(surface)
					if material == null:
						failures.append("missing material " + str(node.name))
						continue
					material_count += 1
					if material is BaseMaterial3D and material.albedo_texture != null:
						var texture: Texture2D = material.albedo_texture
						texture_paths[texture.resource_path] = true
						if texture.get_width() <= 0 or texture.get_height() <= 0:
							failures.append("empty texture " + texture.resource_path)
		if cell_meshes == 0:
			failures.append("empty cell " + str(row.id))
		mesh_count += cell_meshes
		for key: String in data.targets:
			var target: Dictionary = data.targets[key]
			if target.cell_id != row.id:
				continue
			var matches := 0
			for node: Node in instance.find_children("*", "Node3D", true, false):
				var collision_only: bool = target.collision_class == "COLLISION_ONLY_TRIMESH"
				if node.owner == instance and str(node.name) in target.import_name_candidates:
					if (collision_only and node is StaticBody3D) or (not collision_only and node is MeshInstance3D):
						matches += 1
			if matches != 1:
				failures.append("missing or ambiguous imported target " + key)
			else:
				verified_targets += 1
		print("PACK_CELL ", row.id, " meshes=", cell_meshes)
		instance.free()
	if mesh_count != 597 or verified_targets != 609:
		failures.append("expected 597 meshes and 12 collision-only targets")
	if texture_paths.is_empty():
		failures.append("no imported textures")
	print("PACK_RESULT ", JSON.stringify({"cells": cells.size(), "meshes": mesh_count,
		"targets": verified_targets, "materials": material_count, "albedo_textures": texture_paths.size(), "failures": failures}))
	quit(failures.size())
