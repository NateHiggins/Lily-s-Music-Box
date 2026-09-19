extends SceneTree

func _initialize() -> void:
	var holder:=Node3D.new(); root.add_child(holder)
	var hero=load("res://scripts/dream/dream_surface_hero_presenter.gd").new(); holder.add_child(hero); hero.setup(2,null)
	_probe(hero)
	holder.queue_free()
	quit()

func _probe(node:Node) -> void:
	if node is MeshInstance3D: print("[S2J GODOT ROLE] ",node.name," -> ",node.material_override.resource_path)
	for child in node.get_children(): _probe(child)
